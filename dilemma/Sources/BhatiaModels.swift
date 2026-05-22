import Foundation

enum ReasonPolarity: String, Codable, Sendable {
  case benefit
  case cost

  var targetDirection: AttributeDirection {
    switch self {
    case .benefit: .pro
    case .cost: .con
    }
  }
}

enum AttributeDirection: String, Codable, Sendable {
  case pro
  case con
}

struct ReasonInput: Identifiable, Sendable {
  let id = UUID()
  let text: String
  let optionIndex: Int
  let polarity: ReasonPolarity
}

struct AttributeMetadata: Codable, Identifiable, Sendable {
  let rowIndex: Int
  let name: String
  let source: String
  let direction: AttributeDirection
  let vectorOffset: Int

  var id: String { "\(rowIndex)-\(direction.rawValue)" }
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

struct AttributeScore: Identifiable, Sendable {
  let id = UUID()
  let attribute: AttributeMetadata
  let score: Float
}

struct ReasonMatchResult: Identifiable, Sendable {
  let id = UUID()
  let reason: ReasonInput
  let rawScores: [Float]
  let centeredScores: [Float]
  let topMatches: [AttributeScore]
}

struct ConflictDimension: Identifiable, Sendable {
  let id = UUID()
  let attributeName: String
  let option1Score: Float
  let option2Score: Float
  let difference: Float
}

struct SpikeMetrics: Sendable {
  var modelLoadMilliseconds: Double = 0
  var embeddingMilliseconds: Double = 0
  var scoringMilliseconds: Double = 0
  var approximateMemoryMegabytes: Double = 0
}

struct MappingResult: Sendable {
  let modelName: String
  let metrics: SpikeMetrics
  let reasonResults: [ReasonMatchResult]
  let optionProfiles: [Int: [Float]]
  let conflictDimensions: [ConflictDimension]
  let warnings: [String]
}
