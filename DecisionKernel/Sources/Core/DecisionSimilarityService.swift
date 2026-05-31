import Foundation

public enum SimilarityMethod: String, Codable, CaseIterable, Sendable {
  case bhatiaClusters
  case kMeansClusters
  case textEmbedding

  /// Human-readable method name for reports and diagnostics.
  public var label: String {
    switch self {
    case .bhatiaClusters:
      "Bhatia clusters"
    case .kMeansClusters:
      "KMeans clusters"
    case .textEmbedding:
      "Full-text embedding"
    }
  }
}

public struct SimilarityCorpusRecord: Identifiable, Sendable {
  public let id: String
  public let draft: DecisionDraft
  public let label: String?

  /// Creates one searchable corpus record with an optional evaluation label.
  public init(id: String, draft: DecisionDraft, label: String? = nil) {
    self.id = id
    self.draft = draft
    self.label = label
  }
}

public struct SimilarityMatch: Identifiable, Sendable {
  public let id: String
  public let recordID: String
  public let method: SimilarityMethod
  public let score: Float
  public let label: String?

  /// Creates one ranked similarity match for a corpus record.
  public init(recordID: String, method: SimilarityMethod, score: Float, label: String? = nil) {
    self.id = "\(method.rawValue)-\(recordID)"
    self.recordID = recordID
    self.method = method
    self.score = score
    self.label = label
  }
}

public struct SimilaritySearchResult: Sendable {
  public let queryID: String?
  public let method: SimilarityMethod
  public let matches: [SimilarityMatch]

  /// Creates the complete ranked result for one similarity method.
  public init(queryID: String? = nil, method: SimilarityMethod, matches: [SimilarityMatch]) {
    self.queryID = queryID
    self.method = method
    self.matches = matches
  }
}

public struct DecisionSimilarityService: Sendable {
  private let bundle: Bundle
  private let modelResourceName: String
  private let topAttributeMatches: Int

  /// Creates a similarity service that uses bundled assets and a local embedding model.
  public init(
    bundle: Bundle = DecisionKernelResourceBundle.bundle,
    modelResourceName: String = "all-MiniLM-L12-v2",
    topAttributeMatches: Int = 8
  ) {
    self.bundle = bundle
    self.modelResourceName = modelResourceName
    self.topAttributeMatches = topAttributeMatches
  }

  /// Ranks corpus records by comparing normalized conflict vectors aggregated through a cluster method.
  public func similarRecordsByClusters(
    query: DecisionDraft,
    corpus: [SimilarityCorpusRecord],
    clusterMethod: DecisionClusterMethod,
    topK: Int = 3
  ) async throws -> SimilaritySearchResult {
    let method: SimilarityMethod = switch clusterMethod {
    case .bhatiaWardReddit:
      .bhatiaClusters
    case .kMeansAttributeEmbeddings:
      .kMeansClusters
    }

    guard topK > 0, !corpus.isEmpty else {
      return SimilaritySearchResult(method: method, matches: [])
    }

    let store = try AssetRepository(
      bundle: bundle,
      resourceName: clusterMethod.assetResourceName
    ).load()
    let runtime = LocalEmbeddingRuntime(bundle: bundle, modelResourceName: modelResourceName)
    let model = try await runtime.loadModel()
    let vectors = try await clusterVectors(
      for: [query] + corpus.map(\.draft),
      store: store,
      model: model
    )

    guard let queryVector = vectors.first else {
      return SimilaritySearchResult(method: method, matches: [])
    }

    return SimilaritySearchResult(
      method: method,
      matches: rankedMatches(
        queryVector: queryVector,
        corpusVectors: Array(vectors.dropFirst()),
        corpus: corpus,
        method: method,
        topK: topK
      )
    )
  }

  /// Ranks corpus records by comparing canonical structured text embeddings directly.
  public func similarRecordsByTextEmbedding(
    query: DecisionDraft,
    corpus: [SimilarityCorpusRecord],
    topK: Int = 3
  ) async throws -> SimilaritySearchResult {
    guard topK > 0, !corpus.isEmpty else {
      return SimilaritySearchResult(method: .textEmbedding, matches: [])
    }

    _ = try query.validated()
    _ = try corpus.map { try $0.draft.validated() }

    let runtime = LocalEmbeddingRuntime(bundle: bundle, modelResourceName: modelResourceName)
    let model = try await runtime.loadModel()
    let texts = [Self.canonicalText(for: query)] + corpus.map { Self.canonicalText(for: $0.draft) }
    let vectors = try await model.embed(texts: texts)

    guard let queryVector = vectors.first else {
      return SimilaritySearchResult(method: .textEmbedding, matches: [])
    }

    return SimilaritySearchResult(
      method: .textEmbedding,
      matches: rankedMatches(
        queryVector: queryVector,
        corpusVectors: Array(vectors.dropFirst()),
        corpus: corpus,
        method: .textEmbedding,
        topK: topK
      )
    )
  }

  /// Converts a structured draft into deterministic text for full-text embedding comparison.
  public static func canonicalText(for draft: DecisionDraft) -> String {
    var lines = ["Dilemma: \(draft.rawText)"]

    for option in draft.options.sorted(by: { $0.index < $1.index }) {
      let benefits = option.reasons
        .filter { $0.polarity == .benefit }
        .map(\.text)
        .joined(separator: "; ")
      let costs = option.reasons
        .filter { $0.polarity == .cost }
        .map(\.text)
        .joined(separator: "; ")

      lines.append("Option \(option.index): \(option.title)")
      lines.append("Option \(option.index) benefits: \(benefits)")
      lines.append("Option \(option.index) costs: \(costs)")
    }

    return lines.joined(separator: "\n")
  }

  /// Embeds and maps drafts into normalized cluster vectors for cluster-based retrieval.
  private func clusterVectors(
    for drafts: [DecisionDraft],
    store: AttributeEmbeddingStore,
    model: LoadedEmbeddingModel
  ) async throws -> [[Float]] {
    let validatedDrafts = try drafts.map { try $0.validated() }
    let reasonInputsByDraft = validatedDrafts.map(\.reasonInputs)
    let reasonTexts = reasonInputsByDraft.flatMap { $0.map(\.text) }
    let embeddings = try await model.embed(texts: reasonTexts)
    let mapper = AttributeMapper(store: store, topK: topAttributeMatches)
    let clusterAggregator = ClusterAggregator(store: store)

    var offset = 0
    return reasonInputsByDraft.map { reasons in
      let draftEmbeddings = Array(embeddings[offset..<offset + reasons.count])
      offset += reasons.count

      let reasonResults = zip(reasons, draftEmbeddings).map { reason, embedding in
        mapper.map(reason: reason, embedding: embedding)
      }
      let optionProfiles = AttributeScoring.optionAttributeProfiles(
        from: reasonResults,
        store: store
      )
      let conflictVector = AttributeScoring.conflictVector(optionProfiles: optionProfiles)
      return AttributeScoring.normalize(
        clusterAggregator.vector(fromAttributeProfile: conflictVector)
      )
    }
  }

  /// Scores corpus vectors against the query vector and returns the deterministic top matches.
  private func rankedMatches(
    queryVector: [Float],
    corpusVectors: [[Float]],
    corpus: [SimilarityCorpusRecord],
    method: SimilarityMethod,
    topK: Int
  ) -> [SimilarityMatch] {
    zip(corpus, corpusVectors)
      .map { pair in
        let record = pair.0
        let vector = pair.1
        return SimilarityMatch(
          recordID: record.id,
          method: method,
          score: AttributeScoring.dot(queryVector, vector),
          label: record.label
        )
      }
      .filter { $0.score.isFinite }
      .sorted {
        if $0.score == $1.score {
          return $0.recordID < $1.recordID
        }
        return $0.score > $1.score
      }
      .prefix(topK)
      .map { $0 }
  }
}
