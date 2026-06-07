import Foundation

/// Legacy derived attribute conflict row used by current vault statistics and exports.
public struct StoredAttributeConflict: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var attributeName: String
  public var option1Score: Double
  public var option2Score: Double
  public var difference: Double
  public var rank: Int

  public init(
    id: UUID = UUID(),
    attributeName: String,
    option1Score: Double,
    option2Score: Double,
    difference: Double,
    rank: Int
  ) {
    self.id = id
    self.attributeName = attributeName
    self.option1Score = option1Score
    self.option2Score = option2Score
    self.difference = difference
    self.rank = rank
  }
}

/// Legacy derived cluster profile row used by current vault statistics.
public struct StoredClusterProfile: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var optionIndex: Int
  public var clusterID: Int
  public var label: String
  public var score: Double

  public init(
    id: UUID = UUID(),
    optionIndex: Int,
    clusterID: Int,
    label: String,
    score: Double
  ) {
    self.id = id
    self.optionIndex = optionIndex
    self.clusterID = clusterID
    self.label = label
    self.score = score
  }
}
