import Foundation

/// Runtime measurements captured for one analysis.
/// They make model loading, embedding, scoring, and memory costs inspectable in saved results.
public struct AnalysisMetrics: Codable, Equatable, Sendable {
  public var modelLoadMilliseconds: Double
  public var embeddingMilliseconds: Double
  public var scoringMilliseconds: Double
  public var approximateMemoryMegabytes: Double

  public init(
    modelLoadMilliseconds: Double = 0,
    embeddingMilliseconds: Double = 0,
    scoringMilliseconds: Double = 0,
    approximateMemoryMegabytes: Double = 0
  ) {
    self.modelLoadMilliseconds = modelLoadMilliseconds
    self.embeddingMilliseconds = embeddingMilliseconds
    self.scoringMilliseconds = scoringMilliseconds
    self.approximateMemoryMegabytes = approximateMemoryMegabytes
  }
}

/// Metadata for the embedding model used by an analysis.
/// It records both stable identity and display name so stored embeddings remain interpretable later.
public struct AnalysisModelMetadata: Codable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var embeddingDimension: Int

  public init(id: String, name: String, embeddingDimension: Int) {
    self.id = id
    self.name = name
    self.embeddingDimension = embeddingDimension
  }
}

/// Metadata for the local asset bundle used to score attributes and clusters.
/// It lets saved analyses say which asset version and source produced their projections.
public struct AnalysisAssetMetadata: Codable, Equatable, Sendable {
  public var version: Int
  public var resourceName: String
  public var sourceDOI: String

  public init(version: Int, resourceName: String, sourceDOI: String) {
    self.version = version
    self.resourceName = resourceName
    self.sourceDOI = sourceDOI
  }
}

/// Metadata for the cluster aggregation method used by an analysis.
/// It separates the chosen clustering strategy from raw cluster scores and labels.
public struct AnalysisClusterMethodMetadata: Codable, Equatable, Sendable {
  public var id: String
  public var label: String

  public init(id: String, label: String) {
    self.id = id
    self.label = label
  }
}
