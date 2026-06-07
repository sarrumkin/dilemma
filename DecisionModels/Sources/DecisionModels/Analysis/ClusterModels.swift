import Foundation

/// Metadata for one cluster in the analysis asset.
/// It gives cluster scores stable identity, label, representative attribute, and display ordering.
public struct ClusterMetadata: Codable, Identifiable, Equatable, Sendable {
  public let clusterID: Int
  public let label: String
  public let representativeAttributeName: String
  public let sortOrder: Int

  public var id: Int { clusterID }

  public init(
    clusterID: Int,
    label: String,
    representativeAttributeName: String,
    sortOrder: Int
  ) {
    self.clusterID = clusterID
    self.label = label
    self.representativeAttributeName = representativeAttributeName
    self.sortOrder = sortOrder
  }
}

/// Supported local cluster aggregation methods.
/// It lets the analysis record which asset family and algorithm produced cluster profiles.
public enum DecisionClusterMethod: String, Codable, CaseIterable, Sendable {
  case bhatiaWardReddit
  case kMeansAttributeEmbeddings

  public var assetResourceName: String {
    switch self {
    case .bhatiaWardReddit:
      "DilemmaAssets"
    case .kMeansAttributeEmbeddings:
      "DilemmaAssetsKMeans"
    }
  }

  public var metadataValue: String {
    switch self {
    case .bhatiaWardReddit:
      "bhatia_hierarchical_ward_reddit_option_profiles"
    case .kMeansAttributeEmbeddings:
      "kmeans_on_mean_pro_con_attribute_embeddings"
    }
  }

  public var label: String {
    switch self {
    case .bhatiaWardReddit:
      "Bhatia Ward Reddit clusters"
    case .kMeansAttributeEmbeddings:
      "KMeans attribute embedding clusters"
    }
  }

  public init?(assetResourceName: String) {
    guard let method = Self.allCases.first(where: { $0.assetResourceName == assetResourceName }) else {
      return nil
    }
    self = method
  }
}

/// Score of one option or profile against one cluster.
/// It is the full-analysis cluster score before any UI projection or statistics filtering.
public struct ClusterScore: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let cluster: ClusterMetadata
  public let score: Double

  public init(id: UUID = UUID(), cluster: ClusterMetadata, score: Double) {
    self.id = id
    self.cluster = cluster
    self.score = score
  }
}

/// Full-analysis representation of a cluster conflict between options.
/// It records ranked cluster differences using kernel score precision.
public struct ClusterConflictDimension: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let cluster: ClusterMetadata
  public let option1Score: Float
  public let option2Score: Float
  public let difference: Float
  public let rank: Int

  public init(
    id: UUID = UUID(),
    cluster: ClusterMetadata,
    option1Score: Float,
    option2Score: Float,
    difference: Float,
    rank: Int = 0
  ) {
    self.id = id
    self.cluster = cluster
    self.option1Score = option1Score
    self.option2Score = option2Score
    self.difference = difference
    self.rank = rank
  }
}

/// Cluster profile for one option.
/// It groups cluster scores by option for comparison, export, and projection into `ClusterProfile`.
public struct OptionClusterProfile: Codable, Equatable, Sendable {
  public var optionIndex: Int
  public var scores: [ClusterScore]

  public init(optionIndex: Int, scores: [ClusterScore]) {
    self.optionIndex = optionIndex
    self.scores = scores
  }
}
