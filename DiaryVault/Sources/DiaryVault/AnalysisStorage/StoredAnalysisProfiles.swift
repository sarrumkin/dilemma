import Foundation

/// Stored direction-independent attribute identity used in option profiles.
public struct StoredAttributeDefinition: Codable, Identifiable, Equatable, Sendable {
  public let attributeID: Int
  public let name: String
  public let source: String
  public let clusterID: Int?

  public var id: Int { attributeID }

  public init(attributeID: Int, name: String, source: String, clusterID: Int?) {
    self.attributeID = attributeID
    self.name = name
    self.source = source
    self.clusterID = clusterID
  }
}

/// Stored option-level score for one collapsed attribute.
public struct StoredAttributeProfileScore: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let attribute: StoredAttributeDefinition
  public let score: Float

  public init(id: UUID = UUID(), attribute: StoredAttributeDefinition, score: Float) {
    self.id = id
    self.attribute = attribute
    self.score = score
  }
}

/// Stored attribute score profile for one option.
public struct StoredOptionAttributeProfile: Codable, Equatable, Sendable {
  public var optionIndex: Int
  public var scores: [StoredAttributeProfileScore]

  public init(optionIndex: Int, scores: [StoredAttributeProfileScore]) {
    self.optionIndex = optionIndex
    self.scores = scores
  }
}

/// Stored cluster identity used in option cluster profiles.
public struct StoredClusterMetadata: Codable, Identifiable, Equatable, Sendable {
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

/// Stored option-level score for one cluster.
public struct StoredClusterScore: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let cluster: StoredClusterMetadata
  public let score: Double

  public init(id: UUID = UUID(), cluster: StoredClusterMetadata, score: Double) {
    self.id = id
    self.cluster = cluster
    self.score = score
  }
}

/// Stored cluster score profile for one option.
public struct StoredOptionClusterProfile: Codable, Equatable, Sendable {
  public var optionIndex: Int
  public var scores: [StoredClusterScore]

  public init(optionIndex: Int, scores: [StoredClusterScore]) {
    self.optionIndex = optionIndex
    self.scores = scores
  }
}

