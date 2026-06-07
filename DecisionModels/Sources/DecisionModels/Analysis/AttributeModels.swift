import Foundation

/// Direction of an attribute row in the scoring asset.
/// It distinguishes pro and con vectors so benefits and costs are scored against the right side.
public enum AttributeDirection: String, Codable, Equatable, Sendable {
  case pro
  case con
}

/// Metadata for one concrete attribute vector row.
/// It links raw vector offsets back to a human-readable attribute, direction, source, and optional cluster.
public struct AttributeMetadata: Codable, Identifiable, Equatable, Sendable {
  public let attributeID: Int?
  public let rowIndex: Int
  public let name: String
  public let source: String
  public let direction: AttributeDirection
  public let vectorOffset: Int
  public let clusterID: Int?

  public var id: String { "\(rowIndex)-\(direction.rawValue)" }

  public init(
    attributeID: Int? = nil,
    rowIndex: Int,
    name: String,
    source: String,
    direction: AttributeDirection,
    vectorOffset: Int,
    clusterID: Int? = nil
  ) {
    self.attributeID = attributeID
    self.rowIndex = rowIndex
    self.name = name
    self.source = source
    self.direction = direction
    self.vectorOffset = vectorOffset
    self.clusterID = clusterID
  }
}

/// Direction-independent attribute identity used in option profiles.
/// It collapses pro and con rows into a single attribute concept for UI and aggregate scoring.
public struct AttributeDefinition: Codable, Identifiable, Equatable, Sendable {
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

/// Score of one reason against one directed attribute row.
/// It captures the raw top-match evidence produced by embedding similarity.
public struct AttributeScore: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let attribute: AttributeMetadata
  public let score: Float

  public init(id: UUID = UUID(), attribute: AttributeMetadata, score: Float) {
    self.id = id
    self.attribute = attribute
    self.score = score
  }
}

/// Score of one option against one collapsed attribute.
/// It is used for option-level profiles after reason scores have been aggregated.
public struct AttributeProfileScore: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let attribute: AttributeDefinition
  public let score: Float

  public init(id: UUID = UUID(), attribute: AttributeDefinition, score: Float) {
    self.id = id
    self.attribute = attribute
    self.score = score
  }
}

/// Full scoring result for a single reason.
/// It keeps raw scores, centered scores, and top matches for explainability of the analysis.
public struct ReasonMatchResult: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let reason: ReasonInput
  public let rawScores: [Float]
  public let centeredScores: [Float]
  public let topMatches: [AttributeScore]

  public init(
    id: UUID = UUID(),
    reason: ReasonInput,
    rawScores: [Float],
    centeredScores: [Float],
    topMatches: [AttributeScore]
  ) {
    self.id = id
    self.reason = reason
    self.rawScores = rawScores
    self.centeredScores = centeredScores
    self.topMatches = topMatches
  }
}

/// Full-analysis representation of an attribute conflict.
/// It keeps float kernel scores and rank before they are projected into app-facing `AttributeConflict`.
public struct ConflictDimension: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let attributeID: Int?
  public let attributeName: String
  public let option1Score: Float
  public let option2Score: Float
  public let difference: Float
  public let rank: Int

  public init(
    id: UUID = UUID(),
    attributeID: Int? = nil,
    attributeName: String,
    option1Score: Float,
    option2Score: Float,
    difference: Float,
    rank: Int = 0
  ) {
    self.id = id
    self.attributeID = attributeID
    self.attributeName = attributeName
    self.option1Score = option1Score
    self.option2Score = option2Score
    self.difference = difference
    self.rank = rank
  }
}

/// Attribute profile for one option.
/// It groups all collapsed attribute scores by option so UI and statistics can compare option tendencies.
public struct OptionAttributeProfile: Codable, Equatable, Sendable {
  public var optionIndex: Int
  public var scores: [AttributeProfileScore]

  public init(optionIndex: Int, scores: [AttributeProfileScore]) {
    self.optionIndex = optionIndex
    self.scores = scores
  }
}
