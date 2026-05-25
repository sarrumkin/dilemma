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

public struct DecisionDraft: Identifiable, Sendable {
  public let id: UUID
  public let rawText: String
  public let options: [DecisionOption]

  public init(id: UUID = UUID(), rawText: String, options: [DecisionOption]) {
    self.id = id
    self.rawText = rawText
    self.options = options
  }

  public func validated(requiredReasonsPerPolarity: Int = 3) throws -> DecisionDraft {
    guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw DecisionDraftValidationError.missingDilemmaText
    }
    guard options.count == 2 else {
      throw DecisionDraftValidationError.expectedTwoOptions
    }

    for option in options {
      guard !option.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw DecisionDraftValidationError.missingOptionTitle(optionIndex: option.index)
      }

      for polarity in [ReasonPolarity.benefit, .cost] {
        let count = option.reasons.filter {
          $0.polarity == polarity && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        guard count >= requiredReasonsPerPolarity else {
          throw DecisionDraftValidationError.notEnoughReasons(
            optionIndex: option.index,
            polarity: polarity,
            expected: requiredReasonsPerPolarity,
            actual: count
          )
        }
      }
    }

    return self
  }

  var reasonInputs: [ReasonInput] {
    options
      .sorted { $0.index < $1.index }
      .flatMap { option in
        option.reasons.map {
          ReasonInput(text: $0.text, optionIndex: option.index, polarity: $0.polarity)
        }
      }
  }
}

public struct DecisionOption: Identifiable, Sendable {
  public let id: UUID
  public let index: Int
  public let title: String
  public let reasons: [Reason]

  public init(id: UUID = UUID(), index: Int, title: String, reasons: [Reason]) {
    self.id = id
    self.index = index
    self.title = title
    self.reasons = reasons
  }
}

public struct Reason: Identifiable, Sendable {
  public let id: UUID
  public let text: String
  public let polarity: ReasonPolarity

  public init(id: UUID = UUID(), text: String, polarity: ReasonPolarity) {
    self.id = id
    self.text = text
    self.polarity = polarity
  }
}

public enum DecisionDraftValidationError: LocalizedError, Equatable, Sendable {
  case missingDilemmaText
  case expectedTwoOptions
  case missingOptionTitle(optionIndex: Int)
  case notEnoughReasons(optionIndex: Int, polarity: ReasonPolarity, expected: Int, actual: Int)

  public var errorDescription: String? {
    switch self {
    case .missingDilemmaText:
      "Dilemma text is required."
    case .expectedTwoOptions:
      "Exactly two options are required."
    case .missingOptionTitle(let optionIndex):
      "Option \(optionIndex) title is required."
    case .notEnoughReasons(let optionIndex, let polarity, let expected, let actual):
      "Option \(optionIndex) needs \(expected) \(polarity.rawValue) reasons; got \(actual)."
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

public struct AttributeDefinition: Codable, Identifiable, Sendable {
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

public struct ClusterMetadata: Codable, Identifiable, Sendable {
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

public struct AttributeProfileScore: Identifiable, Sendable {
  public let id = UUID()
  public let attribute: AttributeDefinition
  public let score: Float
}

public struct ClusterScore: Identifiable, Sendable {
  public let id = UUID()
  public let cluster: ClusterMetadata
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

public struct ClusterConflictDimension: Identifiable, Sendable {
  public let id = UUID()
  public let cluster: ClusterMetadata
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
  public let draftID: UUID?
  public let modelName: String
  public let assetVersion: Int
  public let sourceDOI: String
  public let metrics: AnalysisMetrics
  public let reasonResults: [ReasonMatchResult]
  public let optionProfiles: [Int: [Float]]
  public let topAttributesByOption: [Int: [AttributeProfileScore]]
  public let clusterProfiles: [Int: [ClusterScore]]
  public let conflictDimensions: [ConflictDimension]
  public let clusterConflictDimensions: [ClusterConflictDimension]
  public let warnings: [String]
}

public typealias DecisionAnalysis = DecisionAnalysisResult
