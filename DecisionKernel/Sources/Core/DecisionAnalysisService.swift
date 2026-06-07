import DecisionModels
import Foundation

public struct DecisionAnalysisService: Sendable {
  private let bundle: Bundle
  private let modelResourceName: String
  private let assetResourceName: String
  private let clusterMethod: DecisionClusterMethod?
  private let topK: Int

  /// Creates an analysis service backed by one of the known bundled cluster-method assets.
  public init(
    bundle: Bundle = DecisionKernelResourceBundle.bundle,
    modelResourceName: String = "paraphrase-multilingual-MiniLM-L12-v2",
    clusterMethod: DecisionClusterMethod = .bhatiaWardReddit,
    topK: Int = 8
  ) {
    self.bundle = bundle
    self.modelResourceName = modelResourceName
    self.assetResourceName = clusterMethod.assetResourceName
    self.clusterMethod = clusterMethod
    self.topK = topK
  }

  /// Creates an analysis service backed by an explicit SQLite asset resource name.
  public init(
    bundle: Bundle = DecisionKernelResourceBundle.bundle,
    modelResourceName: String = "paraphrase-multilingual-MiniLM-L12-v2",
    assetResourceName: String,
    topK: Int = 8
  ) {
    self.bundle = bundle
    self.modelResourceName = modelResourceName
    self.assetResourceName = assetResourceName
    self.clusterMethod = DecisionClusterMethod(assetResourceName: assetResourceName)
    self.topK = topK
  }

  /// Runs validation, local embedding, attribute scoring, clustering, and conflict extraction for one draft.
  public func analyze(_ draft: DecisionDraft) async throws -> DecisionAnalysis {
    let validatedDraft = try draft.validated()
    var metrics = AnalysisMetrics()
    let memoryBefore = MemorySnapshot.currentResidentMegabytes()

    let store = try AssetRepository(
      bundle: bundle,
      resourceName: assetResourceName
    ).load()
    let runtime = LocalEmbeddingRuntime(bundle: bundle, modelResourceName: modelResourceName)

    let loadStart = ContinuousClock.now
    let model = try await runtime.loadModel()
    metrics.modelLoadMilliseconds = elapsedMilliseconds(since: loadStart)

    let sortedOptions = validatedDraft.options.sorted { $0.index < $1.index }
    let reasons = validatedDraft.reasonInputs
    let embeddingTexts = [validatedDraft.rawText]
      + sortedOptions.map(\.title)
      + reasons.map(\.text)
    let embeddingStart = ContinuousClock.now
    let embeddings = try await model.embed(texts: embeddingTexts)
    metrics.embeddingMilliseconds = elapsedMilliseconds(since: embeddingStart)
    let optionEmbeddingStart = 1
    let reasonEmbeddingStart = optionEmbeddingStart + sortedOptions.count
    let dilemmaEmbedding = embeddings[0]
    let optionEmbeddings = Array(embeddings[optionEmbeddingStart..<reasonEmbeddingStart])
    let reasonEmbeddings = Array(embeddings[reasonEmbeddingStart...])

    let scoringStart = ContinuousClock.now
    let mapper = AttributeMapper(store: store, topK: topK)
    let reasonResults = zip(reasons, reasonEmbeddings).map { reason, embedding in
      mapper.map(reason: reason, embedding: embedding)
    }
    let optionProfiles = AttributeScoring.optionAttributeProfiles(
      from: reasonResults,
      store: store
    )
    let clusterAggregator = ClusterAggregator(store: store)
    let clusterProfiles = clusterAggregator.profiles(optionProfiles: optionProfiles)
    metrics.scoringMilliseconds = elapsedMilliseconds(since: scoringStart)

    let memoryAfter = MemorySnapshot.currentResidentMegabytes()
    metrics.approximateMemoryMegabytes = max(0, memoryAfter - memoryBefore)

    let modelMetadata = AnalysisModelMetadata(
      id: store.metadata.model.id,
      name: store.metadata.model.shortName,
      embeddingDimension: store.dimension
    )
    let embeddingModelID = store.metadata.model.id
    let embeddingModelName = store.metadata.model.shortName
    let clusterMethodID = clusterMethod?.rawValue
      ?? store.assetMetadata["cluster_method"]
      ?? assetResourceName
    let clusterMethodLabel = clusterMethod?.label
      ?? store.assetMetadata["cluster_method"]
      ?? assetResourceName

    return DecisionAnalysis(
      id: UUID(),
      entryID: validatedDraft.id,
      createdAt: Date(),
      model: modelMetadata,
      asset: AnalysisAssetMetadata(
        version: store.assetVersion,
        resourceName: assetResourceName,
        sourceDOI: store.sourceDOI
      ),
      clusterMethod: AnalysisClusterMethodMetadata(
        id: clusterMethodID,
        label: clusterMethodLabel
      ),
      embeddings: DecisionAnalysisEmbeddings(
        rawText: validatedDraft.rawText,
        dilemmaText: EmbeddingVector(
          modelID: embeddingModelID,
          modelName: embeddingModelName,
          dimension: dilemmaEmbedding.count,
          values: dilemmaEmbedding
        ),
        options: zip(sortedOptions, optionEmbeddings).map { option, embedding in
          OptionEmbedding(
            optionIndex: option.index,
            title: option.title,
            embedding: EmbeddingVector(
              modelID: embeddingModelID,
              modelName: embeddingModelName,
              dimension: embedding.count,
              values: embedding
            )
          )
        },
        reasons: zip(reasons, reasonEmbeddings).map { reason, embedding in
          ReasonEmbedding(
            reasonID: reason.id,
            optionIndex: reason.optionIndex,
            polarity: reason.polarity,
            text: reason.text,
            embedding: EmbeddingVector(
              modelID: embeddingModelID,
              modelName: embeddingModelName,
              dimension: embedding.count,
              values: embedding
            )
          )
        }
      ),
      reasonMatches: reasonResults,
      optionAttributeProfiles: optionProfiles
        .sorted { $0.key < $1.key }
        .map { optionIndex, profile in
          OptionAttributeProfile(
            optionIndex: optionIndex,
            scores: profile.enumerated().compactMap { offset, score in
              guard offset < store.attributeDefinitions.count else { return nil }
              return AttributeProfileScore(
                attribute: store.attributeDefinitions[offset],
                score: score
              )
            }
          )
        },
      optionClusterProfiles: clusterProfiles
        .sorted { $0.key < $1.key }
        .map { optionIndex, scores in
          OptionClusterProfile(optionIndex: optionIndex, scores: scores)
        },
      metrics: metrics,
      warnings: store.clusters.isEmpty ? ["Cluster metadata is not available in the loaded asset."] : []
    )
  }

  /// Converts an elapsed continuous-clock duration to milliseconds for analysis metrics.
  private func elapsedMilliseconds(since start: ContinuousClock.Instant) -> Double {
    let elapsed = ContinuousClock.now - start
    return Double(elapsed.components.seconds) * 1_000
      + Double(elapsed.components.attoseconds) / 1e15
  }
}

struct AssetRepository: Sendable {
  let bundle: Bundle
  let resourceName: String

  /// Loads the configured SQLite attribute asset from the given bundle.
  func load() throws -> AttributeEmbeddingStore {
    try AttributeEmbeddingStore.loadSQLite(resourceName: resourceName, bundle: bundle)
  }
}

struct AttributeMapper: Sendable {
  let store: AttributeEmbeddingStore
  let topK: Int

  /// Scores a reason embedding against the direction-appropriate attribute vectors.
  func map(reason: ReasonInput, embedding: [Float]) -> ReasonMatchResult {
    let scored = AttributeScoring.topMatches(
      reasonVector: embedding,
      reasonPolarity: reason.polarity,
      store: store,
      topK: topK
    )
    return ReasonMatchResult(
      reason: reason,
      rawScores: scored.scores,
      centeredScores: AttributeScoring.rowCenter(scored.scores),
      topMatches: scored.top
    )
  }
}

struct ClusterAggregator: Sendable {
  let store: AttributeEmbeddingStore

  /// Aggregates option attribute profiles into ranked cluster score profiles.
  func profiles(optionProfiles: [Int: [Float]]) -> [Int: [ClusterScore]] {
    optionProfiles.mapValues { profile in
      clusterScores(for: profile)
    }
  }

  /// Aggregates an attribute profile into a fixed-order cluster vector.
  func vector(fromAttributeProfile profile: [Float]) -> [Float] {
    let scores = clusterScores(for: profile)
    let scoreByClusterID = Dictionary(uniqueKeysWithValues: scores.map {
      ($0.cluster.clusterID, $0.score)
    })
    return store.clusters.map { Float(scoreByClusterID[$0.clusterID] ?? 0) }
  }

  /// Computes ranked cluster-level differences between option 1 and option 2 profiles.
  func conflicts(optionProfiles: [Int: [Float]], topK: Int) -> [ClusterConflictDimension] {
    guard
      let option1 = optionProfiles[1],
      let option2 = optionProfiles[2],
      option1.count == option2.count
    else {
      return []
    }

    let option1Clusters = Dictionary(uniqueKeysWithValues: clusterScores(for: option1).map {
      ($0.cluster.clusterID, $0.score)
    })
    let option2Clusters = Dictionary(uniqueKeysWithValues: clusterScores(for: option2).map {
      ($0.cluster.clusterID, $0.score)
    })

    return store.clusters.compactMap { cluster in
      guard let score1 = option1Clusters[cluster.clusterID],
            let score2 = option2Clusters[cluster.clusterID] else {
        return nil
      }
      return ClusterConflictDimension(
        cluster: cluster,
        option1Score: Float(score1),
        option2Score: Float(score2),
        difference: Float(score1 - score2)
      )
    }
    .sorted { abs($0.difference) > abs($1.difference) }
    .prefix(topK)
    .map { $0 }
  }

  /// Computes average profile score per cluster and sorts by absolute magnitude.
  private func clusterScores(for profile: [Float]) -> [ClusterScore] {
    var totals: [Int: Float] = [:]
    var counts: [Int: Float] = [:]

    for index in 0..<Swift.min(profile.count, store.attributeDefinitions.count) {
      guard let clusterID = store.attributeDefinitions[index].clusterID else {
        continue
      }
      totals[clusterID, default: 0] += profile[index]
      counts[clusterID, default: 0] += 1
    }

    return store.clusters.compactMap { cluster in
      guard let total = totals[cluster.clusterID],
            let count = counts[cluster.clusterID],
            count > 0 else {
        return nil
      }
      return ClusterScore(cluster: cluster, score: Double(total / count))
    }
    .sorted { abs($0.score) > abs($1.score) }
  }
}
