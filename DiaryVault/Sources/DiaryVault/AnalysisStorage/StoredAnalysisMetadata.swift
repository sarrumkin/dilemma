import Foundation

/// Stored metadata for the embedding model used by one analysis.
public struct StoredAnalysisModelMetadata: Codable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var embeddingDimension: Int

  public init(id: String, name: String, embeddingDimension: Int) {
    self.id = id
    self.name = name
    self.embeddingDimension = embeddingDimension
  }
}

/// Stored metadata for the asset bundle that produced attribute and cluster scores.
public struct StoredAnalysisAssetMetadata: Codable, Equatable, Sendable {
  public var version: Int
  public var resourceName: String
  public var sourceDOI: String

  public init(version: Int, resourceName: String, sourceDOI: String) {
    self.version = version
    self.resourceName = resourceName
    self.sourceDOI = sourceDOI
  }
}

/// Stored metadata for the cluster aggregation method used by one analysis.
public struct StoredAnalysisClusterMethodMetadata: Codable, Equatable, Sendable {
  public var id: String
  public var label: String

  public init(id: String, label: String) {
    self.id = id
    self.label = label
  }
}

/// Stored runtime measurements for one analysis run.
public struct StoredAnalysisMetrics: Codable, Equatable, Sendable {
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

