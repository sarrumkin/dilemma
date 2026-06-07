import Foundation

/// Root storage object for one saved decision analysis.
///
/// `DiaryVault` owns this DB-facing graph and keeps it independent from `DecisionModels`; use cases
/// are responsible for mapping it to the canonical app model.
public struct StoredDecisionAnalysis: Codable, Identifiable, Equatable, Sendable {
  public static let currentSchemaVersion = 1

  public let id: UUID
  public var entryID: UUID
  public var createdAt: Date
  public var schemaVersion: Int
  public var model: StoredAnalysisModelMetadata
  public var asset: StoredAnalysisAssetMetadata
  public var clusterMethod: StoredAnalysisClusterMethodMetadata
  public var embeddings: StoredDecisionAnalysisEmbeddings
  public var reasonMatches: [StoredReasonMatchResult]
  public var optionAttributeProfiles: [StoredOptionAttributeProfile]
  public var optionClusterProfiles: [StoredOptionClusterProfile]
  public var metrics: StoredAnalysisMetrics
  public var warnings: [String]
  public var attributeConflicts: [StoredAttributeConflict]
  public var clusterProfiles: [StoredClusterProfile]

  public init(
    id: UUID = UUID(),
    entryID: UUID,
    createdAt: Date = Date(),
    schemaVersion: Int = 1,
    assetVersion: Int,
    modelID: String,
    modelName: String? = nil,
    embeddingDimension: Int = 0,
    assetResourceName: String = "",
    sourceDOI: String,
    clusterMethodID: String = "",
    clusterMethodLabel: String = "",
    embeddings: StoredDecisionAnalysisEmbeddings? = nil,
    reasonMatches: [StoredReasonMatchResult] = [],
    optionAttributeProfiles: [StoredOptionAttributeProfile] = [],
    optionClusterProfiles: [StoredOptionClusterProfile] = [],
    metrics: StoredAnalysisMetrics = StoredAnalysisMetrics(),
    warnings: [String] = [],
    attributeConflicts: [StoredAttributeConflict],
    clusterProfiles: [StoredClusterProfile]
  ) {
    let resolvedModelName = modelName ?? modelID
    self.id = id
    self.entryID = entryID
    self.createdAt = createdAt
    self.schemaVersion = schemaVersion
    self.model = StoredAnalysisModelMetadata(
      id: modelID,
      name: resolvedModelName,
      embeddingDimension: embeddingDimension
    )
    self.asset = StoredAnalysisAssetMetadata(
      version: assetVersion,
      resourceName: assetResourceName,
      sourceDOI: sourceDOI
    )
    self.clusterMethod = StoredAnalysisClusterMethodMetadata(
      id: clusterMethodID,
      label: clusterMethodLabel
    )
    self.embeddings = embeddings ?? StoredDecisionAnalysisEmbeddings.empty(
      modelID: modelID,
      modelName: resolvedModelName
    )
    self.reasonMatches = reasonMatches
    self.optionAttributeProfiles = optionAttributeProfiles
    self.optionClusterProfiles = optionClusterProfiles
    self.metrics = metrics
    self.warnings = warnings
    self.attributeConflicts = attributeConflicts
    self.clusterProfiles = clusterProfiles
  }

  public init(
    id: UUID = UUID(),
    entryID: UUID,
    createdAt: Date = Date(),
    schemaVersion: Int = 1,
    model: StoredAnalysisModelMetadata,
    asset: StoredAnalysisAssetMetadata,
    clusterMethod: StoredAnalysisClusterMethodMetadata,
    embeddings: StoredDecisionAnalysisEmbeddings,
    reasonMatches: [StoredReasonMatchResult],
    optionAttributeProfiles: [StoredOptionAttributeProfile],
    optionClusterProfiles: [StoredOptionClusterProfile],
    metrics: StoredAnalysisMetrics,
    warnings: [String],
    attributeConflicts: [StoredAttributeConflict],
    clusterProfiles: [StoredClusterProfile]
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
    self.attributeConflicts = attributeConflicts
    self.clusterProfiles = clusterProfiles
  }

  /// Legacy flat asset version accessor retained for current statistics/tests.
  public var assetVersion: Int { asset.version }

  /// Legacy flat model identifier accessor retained for current statistics/tests.
  public var modelID: String { model.id }

  /// Legacy flat source DOI accessor retained for current statistics/tests.
  public var sourceDOI: String { asset.sourceDOI }

  /// Whether this row has enough normalized data to reconstruct a full canonical analysis.
  public var hasFullAnalysisPayload: Bool {
    embeddings.hasStoredVectors
      && !optionAttributeProfiles.isEmpty
      && !optionClusterProfiles.isEmpty
  }
}
