import Foundation

public enum ReasonPolarity: String, Codable, Sendable {
  case benefit
  case cost

  var targetDirection: AttributeDirection {
    switch self {
    case .benefit: .pro
    case .cost: .con
    }
  }
}

public enum AttributeDirection: String, Codable, Sendable {
  case pro
  case con
}

public struct ReasonInput: Identifiable, Sendable {
  public let id = UUID()
  public let text: String
  public let optionIndex: Int
  public let polarity: ReasonPolarity

  public init(text: String, optionIndex: Int, polarity: ReasonPolarity) {
    self.text = text
    self.optionIndex = optionIndex
    self.polarity = polarity
  }
}

public struct AttributeMetadata: Codable, Identifiable, Sendable {
  public let rowIndex: Int
  public let name: String
  public let source: String
  public let direction: AttributeDirection
  public let vectorOffset: Int

  public var id: String { "\(rowIndex)-\(direction.rawValue)" }
}

struct AttributeAssetModel: Codable, Sendable {
  let id: String
  let shortName: String
  let embeddingDimension: Int
}

struct AttributeVectorFile: Codable, Sendable {
  let file: String
  let dtype: String
  let layout: String
  let normalized: Bool
}

struct AttributeAssetMetadata: Codable, Sendable {
  let assetVersion: Int
  let sourceDoi: String
  let model: AttributeAssetModel
  let vectors: AttributeVectorFile
  let attributes: [AttributeMetadata]
}

public struct AttributeScore: Identifiable, Sendable {
  public let id = UUID()
  public let attribute: AttributeMetadata
  public let score: Float
}

public struct ReasonMatchResult: Identifiable, Sendable {
  public let id = UUID()
  public let reason: ReasonInput
  public let rawScores: [Float]
  public let centeredScores: [Float]
  public let topMatches: [AttributeScore]
}

public struct ConflictDimension: Identifiable, Sendable {
  public let id = UUID()
  public let attributeName: String
  public let option1Score: Float
  public let option2Score: Float
  public let difference: Float
}

public struct AnalysisMetrics: Sendable {
  public var modelLoadMilliseconds: Double = 0
  public var embeddingMilliseconds: Double = 0
  public var scoringMilliseconds: Double = 0
  public var approximateMemoryMegabytes: Double = 0
}

public struct DecisionAnalysisResult: Sendable {
  public let modelName: String
  public let metrics: AnalysisMetrics
  public let reasonResults: [ReasonMatchResult]
  public let optionProfiles: [Int: [Float]]
  public let conflictDimensions: [ConflictDimension]
  public let warnings: [String]
}
