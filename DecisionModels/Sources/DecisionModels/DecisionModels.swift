import Foundation

public struct EntryDraftCommand: Equatable, Sendable {
  public var rawText: String
  public var option1Title: String
  public var option2Title: String
  public var option1Benefits: [String]
  public var option1Costs: [String]
  public var option2Benefits: [String]
  public var option2Costs: [String]

  public init(
    rawText: String = "",
    option1Title: String = "",
    option2Title: String = "",
    option1Benefits: [String] = Array(repeating: "", count: 3),
    option1Costs: [String] = Array(repeating: "", count: 3),
    option2Benefits: [String] = Array(repeating: "", count: 3),
    option2Costs: [String] = Array(repeating: "", count: 3)
  ) {
    self.rawText = rawText
    self.option1Title = option1Title
    self.option2Title = option2Title
    self.option1Benefits = option1Benefits
    self.option1Costs = option1Costs
    self.option2Benefits = option2Benefits
    self.option2Costs = option2Costs
  }

  public var isValid: Bool {
    !rawText.trimmed.isEmpty
      && !option1Title.trimmed.isEmpty
      && !option2Title.trimmed.isEmpty
      && option1Benefits.count == 3
      && option1Costs.count == 3
      && option2Benefits.count == 3
      && option2Costs.count == 3
      && option1Benefits.allSatisfy { !$0.trimmed.isEmpty }
      && option1Costs.allSatisfy { !$0.trimmed.isEmpty }
      && option2Benefits.allSatisfy { !$0.trimmed.isEmpty }
      && option2Costs.allSatisfy { !$0.trimmed.isEmpty }
  }
}

public struct FeedbackCommand: Equatable, Sendable {
  public var entryID: UUID
  public var analysisID: UUID?
  public var conflictWasUseful: Bool
  public var correctedClusterID: Int?
  public var correctedAttributeName: String?
  public var chosenOptionIndex: Int?
  public var note: String

  public init(
    entryID: UUID,
    analysisID: UUID?,
    conflictWasUseful: Bool,
    correctedClusterID: Int? = nil,
    correctedAttributeName: String? = nil,
    chosenOptionIndex: Int? = nil,
    note: String = ""
  ) {
    self.entryID = entryID
    self.analysisID = analysisID
    self.conflictWasUseful = conflictWasUseful
    self.correctedClusterID = correctedClusterID
    self.correctedAttributeName = correctedAttributeName
    self.chosenOptionIndex = chosenOptionIndex
    self.note = note
  }
}

public struct DiarySnapshot: Equatable, Sendable {
  public var entries: [DiaryEntry]
  public var latestAnalyses: [UUID: DiaryAnalysis]

  public init(entries: [DiaryEntry], latestAnalyses: [UUID: DiaryAnalysis]) {
    self.entries = entries
    self.latestAnalyses = latestAnalyses
  }
}

public enum DiaryReasonPolarity: String, Codable, Sendable, CaseIterable {
  case benefit
  case cost
}

public struct DiaryReason: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var text: String
  public var polarity: DiaryReasonPolarity

  public init(id: UUID = UUID(), text: String, polarity: DiaryReasonPolarity) {
    self.id = id
    self.text = text
    self.polarity = polarity
  }
}

public struct DiaryOption: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var index: Int
  public var title: String
  public var reasons: [DiaryReason]

  public init(
    id: UUID = UUID(),
    index: Int,
    title: String,
    reasons: [DiaryReason]
  ) {
    self.id = id
    self.index = index
    self.title = title
    self.reasons = reasons
  }
}

public struct DiaryEntry: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var rawText: String
  public var options: [DiaryOption]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    rawText: String,
    options: [DiaryOption],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.rawText = rawText
    self.options = options
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct AttributeConflict: Codable, Identifiable, Equatable, Sendable {
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

public struct ClusterProfile: Codable, Identifiable, Equatable, Sendable {
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

public struct DiaryAnalysis: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var entryID: UUID
  public var createdAt: Date
  public var assetVersion: Int
  public var modelID: String
  public var sourceDOI: String
  public var attributeConflicts: [AttributeConflict]
  public var clusterProfiles: [ClusterProfile]

  public init(
    id: UUID = UUID(),
    entryID: UUID,
    createdAt: Date = Date(),
    assetVersion: Int,
    modelID: String,
    sourceDOI: String,
    attributeConflicts: [AttributeConflict],
    clusterProfiles: [ClusterProfile]
  ) {
    self.id = id
    self.entryID = entryID
    self.createdAt = createdAt
    self.assetVersion = assetVersion
    self.modelID = modelID
    self.sourceDOI = sourceDOI
    self.attributeConflicts = attributeConflicts
    self.clusterProfiles = clusterProfiles
  }
}

public struct Feedback: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var entryID: UUID
  public var analysisID: UUID?
  public var conflictWasUseful: Bool
  public var correctedClusterID: Int?
  public var correctedAttributeName: String?
  public var chosenOptionIndex: Int?
  public var note: String
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    entryID: UUID,
    analysisID: UUID?,
    conflictWasUseful: Bool,
    correctedClusterID: Int? = nil,
    correctedAttributeName: String? = nil,
    chosenOptionIndex: Int? = nil,
    note: String = "",
    createdAt: Date = Date()
  ) {
    self.id = id
    self.entryID = entryID
    self.analysisID = analysisID
    self.conflictWasUseful = conflictWasUseful
    self.correctedClusterID = correctedClusterID
    self.correctedAttributeName = correctedAttributeName
    self.chosenOptionIndex = chosenOptionIndex
    self.note = note
    self.createdAt = createdAt
  }
}

public struct PreferenceStatistics: Codable, Equatable, Sendable {
  public var entryCount: Int
  public var feedbackCount: Int
  public var acceptedConflictCount: Int
  public var rejectedConflictCount: Int
  public var mostFrequentClusters: [ClusterFrequency]
  public var chosenOptionCounts: [Int: Int]

  public init(
    entryCount: Int,
    feedbackCount: Int,
    acceptedConflictCount: Int,
    rejectedConflictCount: Int,
    mostFrequentClusters: [ClusterFrequency],
    chosenOptionCounts: [Int: Int]
  ) {
    self.entryCount = entryCount
    self.feedbackCount = feedbackCount
    self.acceptedConflictCount = acceptedConflictCount
    self.rejectedConflictCount = rejectedConflictCount
    self.mostFrequentClusters = mostFrequentClusters
    self.chosenOptionCounts = chosenOptionCounts
  }

  public static var empty: PreferenceStatistics {
    PreferenceStatistics(
      entryCount: 0,
      feedbackCount: 0,
      acceptedConflictCount: 0,
      rejectedConflictCount: 0,
      mostFrequentClusters: [],
      chosenOptionCounts: [:]
    )
  }
}

public struct ClusterFrequency: Codable, Identifiable, Equatable, Sendable {
  public var id: Int { clusterID }
  public var clusterID: Int
  public var label: String
  public var count: Int

  public init(clusterID: Int, label: String, count: Int) {
    self.clusterID = clusterID
    self.label = label
    self.count = count
  }
}

public struct DiaryExport: Codable, Equatable, Sendable {
  public var schemaVersion: Int
  public var exportedAt: Date
  public var entries: [DiaryEntry]
  public var analyses: [DiaryAnalysis]
  public var feedback: [Feedback]

  public init(
    schemaVersion: Int = 1,
    exportedAt: Date = Date(),
    entries: [DiaryEntry],
    analyses: [DiaryAnalysis],
    feedback: [Feedback]
  ) {
    self.schemaVersion = schemaVersion
    self.exportedAt = exportedAt
    self.entries = entries
    self.analyses = analyses
    self.feedback = feedback
  }
}

extension EntryDraftCommand {
  static func sample() -> EntryDraftCommand {
    EntryDraftCommand(
      rawText: "Should I stay or leave?",
      option1Title: "Stay",
      option2Title: "Leave",
      option1Benefits: ["Stable income", "Close to family", "Lower risk"],
      option1Costs: ["Less growth", "Boredom", "Missed opportunity"],
      option2Benefits: ["Career growth", "New skills", "Independence"],
      option2Costs: ["Financial risk", "Stress", "Less family time"]
    )
  }
}

extension String {
  var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
