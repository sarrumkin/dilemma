import Foundation

public struct DecisionAnalysisRunner: Sendable {
  private let bundle: Bundle
  private let modelResourceName: String
  private let attributesResourceName: String

  public init(
    bundle: Bundle = DecisionKernelResources.bundle,
    modelResourceName: String = "all-MiniLM-L12-v2",
    attributesResourceName: String = "attributes_l12"
  ) {
    self.bundle = bundle
    self.modelResourceName = modelResourceName
    self.attributesResourceName = attributesResourceName
  }

  public func run() async throws -> DecisionAnalysisResult {
    var metrics = AnalysisMetrics()
    let memoryBefore = MemorySnapshot.currentResidentMegabytes()

    let store = try AttributeEmbeddingStore.load(resourceName: attributesResourceName, bundle: bundle)
    let runtime = LocalEmbeddingRuntime(bundle: bundle, modelResourceName: modelResourceName)

    let loadStart = ContinuousClock.now
    let model = try await runtime.loadModel()
    metrics.modelLoadMilliseconds = elapsedMilliseconds(since: loadStart)

    let reasons = Self.defaultReasons
    let embeddingStart = ContinuousClock.now
    let embeddings = try await model.embed(texts: reasons.map(\.text))
    metrics.embeddingMilliseconds = elapsedMilliseconds(since: embeddingStart)

    let scoringStart = ContinuousClock.now
    let reasonResults = zip(reasons, embeddings).map { reason, embedding in
      let scored = AttributeScoring.topMatches(
        reasonVector: embedding,
        reasonPolarity: reason.polarity,
        store: store,
        topK: 5
      )
      // Reference-compatible profiles aggregate row-centered reason scores,
      // not raw cosine scores, so each reason contributes relative salience.
      let centered = AttributeScoring.rowCenter(scored.scores)
      return ReasonMatchResult(
        reason: reason,
        rawScores: scored.scores,
        centeredScores: centered,
        topMatches: scored.top
      )
    }
    let optionProfiles = AttributeScoring.optionProfiles(
      from: reasonResults,
      attributeCount: store.metadata.attributes.count
    )
    let conflicts = AttributeScoring.conflictDimensions(
      optionProfiles: optionProfiles,
      attributes: store.metadata.attributes,
      topK: 8
    )
    metrics.scoringMilliseconds = elapsedMilliseconds(since: scoringStart)

    let memoryAfter = MemorySnapshot.currentResidentMegabytes()
    metrics.approximateMemoryMegabytes = max(0, memoryAfter - memoryBefore)

    return DecisionAnalysisResult(
      modelName: store.metadata.model.id,
      metrics: metrics,
      reasonResults: reasonResults,
      optionProfiles: optionProfiles,
      conflictDimensions: conflicts,
      warnings: []
    )
  }

  private func elapsedMilliseconds(since start: ContinuousClock.Instant) -> Double {
    let elapsed = ContinuousClock.now - start
    return Double(elapsed.components.seconds) * 1_000
      + Double(elapsed.components.attoseconds) / 1e15
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
