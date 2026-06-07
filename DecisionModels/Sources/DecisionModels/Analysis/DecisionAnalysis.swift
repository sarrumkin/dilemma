import Foundation

/// Complete persisted result of running decision analysis.
///
/// `DecisionAnalysis` is the canonical application-level analysis contract. The kernel returns this
/// model, use cases map it to vault-specific storage models, and UI/statistics features read from it
/// instead of depending on kernel or database internals.
public struct DecisionAnalysis: Identifiable, Codable, Equatable, Sendable {
  /// Stable identifier of this particular analysis run.
  ///
  /// The id is preserved during migration/backfill so existing feedback and UI references can keep
  /// pointing to the same analysis even when the full payload is regenerated.
  public let id: UUID

  /// Diary entry that was analyzed.
  ///
  /// This links the analysis payload back to the user's saved decision entry while keeping the
  /// analysis itself exportable and decodable as a standalone object.
  public let entryID: UUID

  /// Timestamp when this analysis payload was produced.
  ///
  /// Screens and migrations use it to order analyses and to distinguish historical results from
  /// newly regenerated ones.
  public var createdAt: Date

  /// Version of the `DecisionAnalysis` payload schema.
  ///
  /// It allows future schema changes to be handled by migration code without guessing from optional
  /// fields or payload shape.
  public var schemaVersion: Int

  /// Metadata for the embedding model used by the analysis.
  ///
  /// It records stable model identity, display name, and vector dimension so saved embeddings remain
  /// interpretable after the app updates to another model.
  public var model: AnalysisModelMetadata

  /// Metadata for the attribute/cluster asset used during scoring.
  ///
  /// This captures the local resource version and provenance used to convert embeddings into
  /// attribute and cluster projections.
  public var asset: AnalysisAssetMetadata

  /// Metadata for the cluster aggregation strategy used in this run.
  ///
  /// Keeping the method separate from raw scores lets the app compare results from different cluster
  /// algorithms without changing the score payload shape.
  public var clusterMethod: AnalysisClusterMethodMetadata

  /// Embeddings generated for the question, every option title, and every pro/con reason.
  ///
  /// These vectors make the saved analysis complete: downstream features can audit or reuse model
  /// representations without asking the kernel to embed the original text again.
  public var embeddings: DecisionAnalysisEmbeddings

  /// Attribute matches calculated for individual pros and cons.
  ///
  /// This is the detailed reason-level scoring output that explains why each user reason contributed
  /// to particular psychological attributes.
  public var reasonMatches: [ReasonMatchResult]

  /// Attribute score profile for each analyzed option.
  ///
  /// The profile stores the full vector of option-level attribute scores, not only the top UI
  /// highlights, so statistics and future screens can use the complete analysis.
  public var optionAttributeProfiles: [OptionAttributeProfile]

  /// Cluster score profile for each analyzed option.
  ///
  /// These scores summarize attributes into higher-level clusters while preserving the option index
  /// they belong to.
  public var optionClusterProfiles: [OptionClusterProfile]

  /// Runtime and resource metrics captured during analysis.
  ///
  /// Metrics are stored for diagnostics, regression tests, and later performance monitoring of model
  /// loading, embedding, scoring, and memory usage.
  public var metrics: AnalysisMetrics

  /// Non-fatal issues observed while producing the analysis.
  ///
  /// Warnings let the kernel or migration code surface degraded-but-usable results without throwing
  /// away the whole analysis payload.
  public var warnings: [String]

  /// Creates the canonical full analysis payload.
  ///
  /// Use this initializer for fresh kernel results and for migrated analyses where embeddings,
  /// reason matches, profiles, metrics, and warnings are known. The analyzed raw text now lives in
  /// `embeddings.rawText`, because the canonical analysis is bound to `entryID` instead of storing a
  /// second copy of the full diary input tree.
  ///
  /// - Parameters:
  ///   - id: Stable analysis id. Defaults to a new UUID for fresh runs.
  ///   - entryID: Diary entry id this analysis belongs to.
  ///   - createdAt: Creation timestamp for this payload. Defaults to the current date.
  ///   - schemaVersion: Version of the encoded `DecisionAnalysis` schema.
  ///   - model: Embedding model metadata used to produce all stored vectors.
  ///   - asset: Attribute and cluster asset metadata used during scoring.
  ///   - clusterMethod: Cluster aggregation metadata used to produce cluster profiles.
  ///   - embeddings: Stored vectors for the question, options, and reasons.
  ///   - reasonMatches: Detailed reason-level attribute match results.
  ///   - optionAttributeProfiles: Full option-level attribute score profiles.
  ///   - optionClusterProfiles: Full option-level cluster score profiles.
  ///   - metrics: Runtime and resource measurements for this run.
  ///   - warnings: Non-fatal analysis warnings.
  public init(
    id: UUID = UUID(),
    entryID: UUID,
    createdAt: Date = Date(),
    schemaVersion: Int = 1,
    model: AnalysisModelMetadata,
    asset: AnalysisAssetMetadata,
    clusterMethod: AnalysisClusterMethodMetadata,
    embeddings: DecisionAnalysisEmbeddings,
    reasonMatches: [ReasonMatchResult],
    optionAttributeProfiles: [OptionAttributeProfile],
    optionClusterProfiles: [OptionClusterProfile],
    metrics: AnalysisMetrics,
    warnings: [String]
  ) {
    self.id = id
    self.entryID = entryID
    self.createdAt = createdAt
    self.schemaVersion = schemaVersion
    self.model = model
    self.asset = asset
    self.clusterMethod = clusterMethod
    self.embeddings = embeddings
    self.reasonMatches = reasonMatches
    self.optionAttributeProfiles = optionAttributeProfiles
    self.optionClusterProfiles = optionClusterProfiles
    self.metrics = metrics
    self.warnings = warnings
  }

  /// Creates a minimal analysis from the old compact analysis shape.
  ///
  /// This initializer exists only as a compatibility bridge for legacy call sites and tests that
  /// still provide asset/model identifiers plus precomputed compact projections. It fills the new
  /// full-analysis fields with empty snapshots so the rest of the app can keep depending on
  /// `DecisionAnalysis` while older inputs are being migrated or rewritten.
  ///
  /// - Parameters:
  ///   - id: Analysis id to preserve. Defaults to a new UUID.
  ///   - entryID: Diary entry id this legacy analysis belongs to.
  ///   - createdAt: Creation timestamp for the legacy payload.
  ///   - assetVersion: Version of the old scoring asset.
  ///   - modelID: Stable embedding model identifier from the legacy payload.
  ///   - sourceDOI: Source DOI attached to the old asset.
  ///   - attributeConflicts: Existing compact attribute conflict projection.
  ///   - clusterProfiles: Existing compact cluster score projection.
  public init(
    id: UUID = UUID(),
    entryID: UUID,
    createdAt: Date = Date(),
    assetVersion: Int,
    modelID: String,
    sourceDOI: String,
    attributeConflicts: [AttributeConflict],
    clusterProfiles: [ClusterProfile]
  ) {
    self.init(
      id: id,
      entryID: entryID,
      createdAt: createdAt,
      model: AnalysisModelMetadata(id: modelID, name: modelID, embeddingDimension: 0),
      asset: AnalysisAssetMetadata(version: assetVersion, resourceName: "", sourceDOI: sourceDOI),
      clusterMethod: AnalysisClusterMethodMetadata(id: "", label: ""),
      embeddings: DecisionAnalysisEmbeddings(
        rawText: "",
        dilemmaText: EmbeddingVector(modelID: modelID, modelName: modelID, dimension: 0, values: []),
        options: [],
        reasons: []
      ),
      reasonMatches: [],
      optionAttributeProfiles: attributeConflicts.groupedAsOptionAttributeProfiles,
      optionClusterProfiles: clusterProfiles.groupedAsOptionClusterProfiles,
      metrics: AnalysisMetrics(),
      warnings: []
    )
  }

  /// Legacy convenience accessor for the stable embedding model identifier.
  ///
  /// Older app and kernel code reads `modelID` directly; keeping this projection prevents those
  /// callers from reaching into `model.id` while the canonical metadata remains grouped in `model`.
  public var modelID: String { model.id }

  /// Legacy convenience accessor for the historical "model name" field.
  ///
  /// The previous API treated the model identifier as the displayable model name. This projection
  /// intentionally preserves that behavior for older call sites; new code that needs the human
  /// readable name should read `model.name`.
  public var modelName: String { model.id }

  /// Legacy convenience accessor for the scoring asset version.
  ///
  /// Current code stores asset metadata as a grouped object, but existing tests and screens still
  /// use this direct property name.
  public var assetVersion: Int { asset.version }

  /// Legacy convenience accessor for the asset source DOI.
  ///
  /// It keeps provenance available through the old flat API while the canonical value lives in
  /// `asset.sourceDOI`.
  public var sourceDOI: String { asset.sourceDOI }

  /// Resource name of the attribute/cluster asset used for this analysis.
  ///
  /// Detail screens and tests use this to show or verify which bundled scoring database produced the
  /// saved profiles.
  public var assetResourceName: String { asset.resourceName }

  /// Stable identifier of the cluster aggregation method.
  ///
  /// This gives callers a compact way to compare analyses produced by different cluster strategies.
  public var clusterMethodID: String { clusterMethod.id }

  /// Display label of the cluster aggregation method.
  ///
  /// UI code can use this label without depending on kernel enums or asset metadata parsing.
  public var clusterMethodLabel: String { clusterMethod.label }

  /// Compatibility alias for the diary entry id.
  ///
  /// Earlier result models exposed the analyzed draft id as optional; this keeps that API shape while
  /// the canonical `DecisionAnalysis` always has a concrete `entryID`.
  public var draftID: UUID? { entryID }

  /// Compatibility alias for detailed reason-level match results.
  ///
  /// The canonical payload stores these as `reasonMatches`; older consumers still read
  /// `reasonResults`.
  public var reasonResults: [ReasonMatchResult] { reasonMatches }

  /// Dense option-to-attribute-score projection used by existing scoring tests and UI code.
  ///
  /// The canonical payload stores named `AttributeProfileScore` values. This projection strips those
  /// records down to the raw score vector per option for callers that only need numeric profiles.
  public var optionProfiles: [Int: [Float]] {
    Dictionary(uniqueKeysWithValues: optionAttributeProfiles.map { profile in
      (profile.optionIndex, profile.scores.map(\.score))
    })
  }

  /// Top attribute scores per option, sorted by absolute contribution strength.
  ///
  /// This is a read-only UI projection over the full attribute profiles. It limits each option to the
  /// strongest eight scores so current detail screens can render highlights without duplicating
  /// sorting and truncation logic.
  public var topAttributesByOption: [Int: [AttributeProfileScore]] {
    Dictionary(uniqueKeysWithValues: optionAttributeProfiles.map { profile in
      let top = profile.scores
        .sorted { abs($0.score) > abs($1.score) }
        .prefix(8)
      return (profile.optionIndex, Array(top))
    })
  }

  /// Cluster scores grouped by option index.
  ///
  /// The full payload stores `OptionClusterProfile` records. This projection exposes the same data as
  /// a dictionary because several UI/statistics callers address profiles by option index.
  public var clusterProfilesByOption: [Int: [ClusterScore]] {
    Dictionary(uniqueKeysWithValues: optionClusterProfiles.map { profile in
      (profile.optionIndex, profile.scores)
    })
  }

  /// Legacy attribute conflict projection derived from full option profiles.
  ///
  /// The canonical payload stores full option attribute profiles. This computed property derives the
  /// strongest option differences deterministically so compact conflicts are no longer persisted as a
  /// second source of truth.
  public var attributeConflicts: [AttributeConflict] {
    rankedAttributeConflicts(topK: Self.defaultConflictTopK)
  }

  /// Legacy kernel conflict projection derived from full option attribute profiles.
  ///
  /// `ConflictDimension` is the older kernel/UI shape, so this computed property keeps existing
  /// callers working without storing duplicate conflict arrays.
  public var conflictDimensions: [ConflictDimension] {
    rankedConflictDimensions(topK: Self.defaultConflictTopK)
  }

  /// Returns the strongest attribute differences between option 1 and option 2.
  ///
  /// The ranking is deterministic: absolute difference descending, then original profile order. The
  /// profile order mirrors the attribute asset order used by `AttributeScoring`, which keeps the
  /// derived projection compatible with the previous kernel-produced compact conflict list.
  public func rankedAttributeConflicts(topK: Int = Self.defaultConflictTopK) -> [AttributeConflict] {
    rankedConflictDimensions(topK: topK).map {
      AttributeConflict(
        id: $0.id,
        attributeName: $0.attributeName,
        option1Score: Double($0.option1Score),
        option2Score: Double($0.option2Score),
        difference: Double($0.difference),
        rank: $0.rank
      )
    }
  }

  /// Returns the strongest attribute conflict dimensions between option 1 and option 2.
  ///
  /// This helper exposes the same derived data as `attributeConflicts` while preserving the
  /// kernel-facing `ConflictDimension` shape for older tests and integration code. It expects option
  /// profile vectors to be aligned by index, as they are when produced from one attribute asset.
  public func rankedConflictDimensions(topK: Int = Self.defaultConflictTopK) -> [ConflictDimension] {
    let profiles = Dictionary(uniqueKeysWithValues: optionAttributeProfiles.map { ($0.optionIndex, $0.scores) })
    guard
      let option1 = profiles[1],
      let option2 = profiles[2],
      option1.count == option2.count,
      topK > 0
    else {
      return []
    }

    return option1.indices.map { index in
      let left = option1[index]
      let right = option2[index]
      let difference = left.score - right.score
      return (
        offset: index,
        conflict: ConflictDimension(
          attributeID: left.attribute.attributeID,
          attributeName: left.attribute.name,
          option1Score: left.score,
          option2Score: right.score,
          difference: difference
        )
      )
    }
    .sorted {
      let leftMagnitude = abs($0.conflict.difference)
      let rightMagnitude = abs($1.conflict.difference)
      if leftMagnitude != rightMagnitude {
        return leftMagnitude > rightMagnitude
      }
      return $0.offset < $1.offset
    }
    .prefix(topK)
    .enumerated()
    .map { rankOffset, ranked in
      let conflict = ranked.conflict
      return ConflictDimension(
        id: conflict.id,
        attributeID: conflict.attributeID,
        attributeName: conflict.attributeName,
        option1Score: conflict.option1Score,
        option2Score: conflict.option2Score,
        difference: conflict.difference,
        rank: rankOffset + 1
      )
    }
  }

  /// Derived cluster conflict projection.
  ///
  /// The canonical payload stores option cluster profiles. This computed property derives compact
  /// conflicts from those profiles instead of persisting duplicate cluster conflict rows.
  public var clusterConflicts: [ClusterConflictDimension] {
    rankedClusterConflicts(topK: Self.defaultConflictTopK)
  }

  /// Legacy cluster conflict projection.
  ///
  /// This accessor preserves the old property name for existing code while delegating to the derived
  /// cluster conflict projection.
  public var clusterConflictDimensions: [ClusterConflictDimension] {
    clusterConflicts
  }

  /// Returns the strongest cluster differences between option 1 and option 2.
  ///
  /// The ranking is deterministic: absolute difference descending, then cluster id, then label.
  public func rankedClusterConflicts(topK: Int = Self.defaultConflictTopK) -> [ClusterConflictDimension] {
    let profiles = Dictionary(uniqueKeysWithValues: optionClusterProfiles.map { ($0.optionIndex, $0.scores) })
    guard let option1 = profiles[1], let option2 = profiles[2], topK > 0 else { return [] }

    let option1Scores = Dictionary(uniqueKeysWithValues: option1.map { ($0.cluster.clusterID, $0) })
    let option2Scores = Dictionary(uniqueKeysWithValues: option2.map { ($0.cluster.clusterID, $0) })
    let clusterIDs = Set(option1Scores.keys).union(option2Scores.keys)

    return clusterIDs.compactMap { clusterID -> ClusterConflictDimension? in
      let left = option1Scores[clusterID]
      let right = option2Scores[clusterID]
      guard let cluster = left?.cluster ?? right?.cluster else { return nil }
      let option1Score = Float(left?.score ?? 0)
      let option2Score = Float(right?.score ?? 0)
      let difference = option1Score - option2Score
      guard difference.isFinite, abs(difference) > 0 else { return nil }
      return ClusterConflictDimension(
        cluster: cluster,
        option1Score: option1Score,
        option2Score: option2Score,
        difference: difference
      )
    }
    .sorted {
      let leftMagnitude = abs($0.difference)
      let rightMagnitude = abs($1.difference)
      if leftMagnitude != rightMagnitude {
        return leftMagnitude > rightMagnitude
      }
      if $0.cluster.clusterID != $1.cluster.clusterID {
        return $0.cluster.clusterID < $1.cluster.clusterID
      }
      return $0.cluster.label < $1.cluster.label
    }
    .prefix(topK)
    .enumerated()
    .map { offset, conflict in
      ClusterConflictDimension(
        id: conflict.id,
        cluster: conflict.cluster,
        option1Score: conflict.option1Score,
        option2Score: conflict.option2Score,
        difference: conflict.difference,
        rank: offset + 1
      )
    }
  }

  /// Legacy flat cluster profile projection.
  ///
  /// The canonical payload groups cluster scores by option. This computed property flattens them into
  /// the older `ClusterProfile` records used by vault projections and current statistics code.
  public var clusterProfiles: [ClusterProfile] {
    optionClusterProfiles.flatMap { profile in
      profile.scores.map {
        ClusterProfile(
          optionIndex: profile.optionIndex,
          clusterID: $0.cluster.clusterID,
          label: $0.cluster.label,
          score: $0.score
        )
      }
    }
  }

  /// Default number of compact conflict rows exposed through derived projections.
  ///
  /// This matches the analysis kernel's default `topK` so existing UI and tests keep seeing the same
  /// number of highlighted conflicts without storing those highlights separately.
  public static let defaultConflictTopK = 8
}

private extension Array where Element == AttributeConflict {
  /// Converts old compact attribute conflicts into minimal canonical option profiles.
  ///
  /// This keeps legacy projection-only rows decodable until the normalized analysis storage replaces
  /// the temporary fallback path in later slices.
  var groupedAsOptionAttributeProfiles: [OptionAttributeProfile] {
    guard !isEmpty else { return [] }
    let sortedConflicts = sorted { $0.rank < $1.rank }
    return [
      OptionAttributeProfile(
        optionIndex: 1,
        scores: sortedConflicts.map { $0.profileScore(optionScore: Float($0.option1Score)) }
      ),
      OptionAttributeProfile(
        optionIndex: 2,
        scores: sortedConflicts.map { $0.profileScore(optionScore: Float($0.option2Score)) }
      ),
    ]
  }
}

private extension AttributeConflict {
  func profileScore(optionScore: Float) -> AttributeProfileScore {
    AttributeProfileScore(
      id: id,
      attribute: AttributeDefinition(
        attributeID: rank,
        name: attributeName,
        source: "",
        clusterID: nil
      ),
      score: optionScore
    )
  }
}

private extension Array where Element == ClusterProfile {
  /// Converts old flat cluster profiles into the canonical grouped option profiles.
  ///
  /// The compatibility initializer receives legacy `ClusterProfile` rows. Grouping them here keeps
  /// that initializer small and makes the conversion rule explicit: profiles are grouped by
  /// `optionIndex`, transformed into `ClusterScore` values, and returned in stable option order.
  var groupedAsOptionClusterProfiles: [OptionClusterProfile] {
    Dictionary(grouping: self, by: \.optionIndex)
      .map { optionIndex, profiles in
        OptionClusterProfile(
          optionIndex: optionIndex,
          scores: profiles.map {
            ClusterScore(
              cluster: ClusterMetadata(
                clusterID: $0.clusterID,
                label: $0.label,
                representativeAttributeName: $0.label,
                sortOrder: $0.clusterID
              ),
              score: $0.score
            )
          }
        )
      }
      .sorted { $0.optionIndex < $1.optionIndex }
  }
}
