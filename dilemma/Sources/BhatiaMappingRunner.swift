import CoreML
import Embeddings
import Foundation

@available(iOS 18.0, *)
struct BhatiaMappingRunner {
  let bundle: Bundle
  let modelResourceName: String
  let attributesResourceName: String

  init(
    bundle: Bundle = .main,
    modelResourceName: String = "all-MiniLM-L12-v2",
    attributesResourceName: String = "attributes_l12"
  ) {
    self.bundle = bundle
    self.modelResourceName = modelResourceName
    self.attributesResourceName = attributesResourceName
  }

  func run() async throws -> MappingResult {
    var metrics = SpikeMetrics()
    let memoryBefore = MemorySnapshot.currentResidentMegabytes()

    let store = try AttributeEmbeddingStore.load(resourceName: attributesResourceName, bundle: bundle)
    let modelURL = try bundledModelURL()

    let loadStart = ContinuousClock.now
    let modelBundle = try await Bert.loadModelBundle(from: modelURL)
    metrics.modelLoadMilliseconds = elapsedMilliseconds(since: loadStart)

    let reasons = Self.defaultReasons
    let embeddingStart = ContinuousClock.now
    let embeddings = try await sentenceTransformerEmbeddings(
      texts: reasons.map(\.text),
      modelBundle: modelBundle
    )
    metrics.embeddingMilliseconds = elapsedMilliseconds(since: embeddingStart)

    let scoringStart = ContinuousClock.now
    let reasonResults = zip(reasons, embeddings).map { reason, embedding in
      let scored = BhatiaScoring.topMatches(
        reasonVector: embedding,
        reasonPolarity: reason.polarity,
        store: store,
        topK: 5
      )
      // Bhatia-style profiles aggregate row-centered reason scores, not
      // raw cosine scores, so each reason contributes relative salience.
      let centered = BhatiaScoring.rowCenter(scored.scores)
      return ReasonMatchResult(
        reason: reason,
        rawScores: scored.scores,
        centeredScores: centered,
        topMatches: scored.top
      )
    }
    let optionProfiles = BhatiaScoring.optionProfiles(
      from: reasonResults,
      attributeCount: store.metadata.attributes.count
    )
    let conflicts = BhatiaScoring.conflictDimensions(
      optionProfiles: optionProfiles,
      attributes: store.metadata.attributes,
      topK: 8
    )
    metrics.scoringMilliseconds = elapsedMilliseconds(since: scoringStart)

    let memoryAfter = MemorySnapshot.currentResidentMegabytes()
    metrics.approximateMemoryMegabytes = max(0, memoryAfter - memoryBefore)

    return MappingResult(
      modelName: store.metadata.model.id,
      metrics: metrics,
      reasonResults: reasonResults,
      optionProfiles: optionProfiles,
      conflictDimensions: conflicts,
      warnings: []
    )
  }

  private func bundledModelURL() throws -> URL {
    // Runtime is deliberately bundled-only: no hubRepoId fallback, no
    // network fetch, and no API call from the app path.
    guard let url = bundle.url(
      forResource: modelResourceName,
      withExtension: nil,
      subdirectory: "Models"
    ) else {
      throw RunnerError.missingBundledModel(modelResourceName)
    }
    return url
  }

  private func sentenceTransformerEmbeddings(
    texts: [String],
    modelBundle: Bert.ModelBundle
  ) async throws -> [[Float]] {
    let tokenized = try modelBundle.tokenizer.tokenizeTextsPaddingToLongest(
      texts,
      padTokenId: 0,
      maxLength: 512
    )
    let inputIds = MLTensor(shape: tokenized.shape, scalars: tokenized.tokens)
    let attentionMask = MLTensor(shape: tokenized.shape, scalars: tokenized.attentionMask)
    let output = modelBundle.model(inputIds: inputIds, attentionMask: attentionMask)

    // SentenceTransformers MiniLM uses masked mean pooling over token
    // embeddings. swift-embeddings' convenience encode currently returns
    // CLS, so the prototype pools explicitly for parity with Python assets.
    let expandedMask = attentionMask.expandingShape(at: 2)
    let masked = output.sequenceOutput * expandedMask
    let sums = masked.sum(alongAxes: 1, keepRank: false)
    let counts = attentionMask.sum(alongAxes: 1, keepRank: true)
    let pooled = sums / counts
    let flat = await pooled.cast(to: Float.self).shapedArray(of: Float.self).scalars

    guard !texts.isEmpty else { return [] }
    let dimension = flat.count / texts.count
    return stride(from: 0, to: flat.count, by: dimension).map { start in
      BhatiaScoring.normalize(Array(flat[start..<start + dimension]))
    }
  }

  private func elapsedMilliseconds(since start: ContinuousClock.Instant) -> Double {
    let elapsed = ContinuousClock.now - start
    return Double(elapsed.components.seconds) * 1_000
      + Double(elapsed.components.attoseconds) / 1e15
  }

  enum RunnerError: LocalizedError {
    case missingBundledModel(String)

    var errorDescription: String? {
      switch self {
      case .missingBundledModel(let name):
        "Missing bundled model folder: \(name)"
      }
    }
  }

  static let defaultReasons: [ReasonInput] = [
    ReasonInput(text: "This option would save me money.", optionIndex: 1, polarity: .benefit),
    ReasonInput(text: "It could improve my career prospects.", optionIndex: 1, polarity: .benefit),
    ReasonInput(text: "It would give me more time with my family.", optionIndex: 1, polarity: .benefit),
    ReasonInput(text: "There is a chance I could lose stability.", optionIndex: 1, polarity: .cost),
    ReasonInput(text: "It may hurt my mental health.", optionIndex: 1, polarity: .cost),
    ReasonInput(text: "It requires a lot of time and work.", optionIndex: 1, polarity: .cost),
    ReasonInput(text: "It could strengthen the relationship.", optionIndex: 2, polarity: .benefit),
    ReasonInput(text: "I would have more independence.", optionIndex: 2, polarity: .benefit),
    ReasonInput(text: "I would learn useful new skills.", optionIndex: 2, polarity: .benefit),
    ReasonInput(text: "It may damage my reputation.", optionIndex: 2, polarity: .cost),
    ReasonInput(text: "It sounds enjoyable and exciting.", optionIndex: 2, polarity: .cost),
    ReasonInput(text: "It gives me a safer long-term path.", optionIndex: 2, polarity: .cost),
  ]
}

enum MemorySnapshot {
  static func currentResidentMegabytes() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return 0 }
    return Double(info.resident_size) / 1_048_576
  }
}
