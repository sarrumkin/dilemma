import Foundation

/// Direction of an analyzed attribute row in storage.
public enum StoredAttributeDirection: String, Codable, Equatable, Sendable {
  case pro
  case con
}

/// Stored metadata for one directed attribute match row.
public struct StoredAttributeMetadata: Codable, Identifiable, Equatable, Sendable {
  public let attributeID: Int?
  public let rowIndex: Int
  public let name: String
  public let source: String
  public let direction: StoredAttributeDirection
  public let vectorOffset: Int
  public let clusterID: Int?

  public var id: String { "\(rowIndex)-\(direction.rawValue)" }

  public init(
    attributeID: Int? = nil,
    rowIndex: Int,
    name: String,
    source: String,
    direction: StoredAttributeDirection,
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

/// Stored score of one reason against one directed attribute row.
public struct StoredAttributeScore: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let attribute: StoredAttributeMetadata
  public let score: Float

  public init(id: UUID = UUID(), attribute: StoredAttributeMetadata, score: Float) {
    self.id = id
    self.attribute = attribute
    self.score = score
  }
}

/// Stored reason input captured inside one reason match result.
public struct StoredReasonInput: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let text: String
  public let optionIndex: Int
  public let polarity: StoredDiaryReasonPolarity

  public init(
    id: UUID = UUID(),
    text: String,
    optionIndex: Int,
    polarity: StoredDiaryReasonPolarity
  ) {
    self.id = id
    self.text = text
    self.optionIndex = optionIndex
    self.polarity = polarity
  }
}

/// Stored full scoring result for one analyzed reason.
public struct StoredReasonMatchResult: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let reason: StoredReasonInput
  public let rawScores: [Float]
  public let centeredScores: [Float]
  public let topMatches: [StoredAttributeScore]

  public init(
    id: UUID = UUID(),
    reason: StoredReasonInput,
    rawScores: [Float],
    centeredScores: [Float],
    topMatches: [StoredAttributeScore]
  ) {
    self.id = id
    self.reason = reason
    self.rawScores = rawScores
    self.centeredScores = centeredScores
    self.topMatches = topMatches
  }
}

