import Foundation

public enum StoredReasonPolarity: String, Codable, Sendable, CaseIterable {
  case benefit
  case cost
}

public struct StoredReason: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var text: String
  public var polarity: StoredReasonPolarity

  public init(id: UUID = UUID(), text: String, polarity: StoredReasonPolarity) {
    self.id = id
    self.text = text
    self.polarity = polarity
  }
}

public struct StoredDecisionOption: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var index: Int
  public var title: String
  public var reasons: [StoredReason]

  public init(
    id: UUID = UUID(),
    index: Int,
    title: String,
    reasons: [StoredReason]
  ) {
    self.id = id
    self.index = index
    self.title = title
    self.reasons = reasons
  }
}

public struct DiaryEntryRecord: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var rawText: String
  public var options: [StoredDecisionOption]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    rawText: String,
    options: [StoredDecisionOption],
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

public struct StoredDecisionAnalysis: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var entryID: UUID
  public var createdAt: Date
  public var assetVersion: Int
  public var modelID: String
  public var sourceDOI: String
  public var attributeConflicts: [StoredAttributeConflict]
  public var clusterProfiles: [StoredClusterProfile]

  public init(
    id: UUID = UUID(),
    entryID: UUID,
    createdAt: Date = Date(),
    assetVersion: Int,
    modelID: String,
    sourceDOI: String,
    attributeConflicts: [StoredAttributeConflict],
    clusterProfiles: [StoredClusterProfile]
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

public struct FeedbackRecord: Codable, Identifiable, Equatable, Sendable {
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
  public var exportedAt: Date
  public var entries: [DiaryEntryRecord]
  public var analyses: [StoredDecisionAnalysis]
  public var feedback: [FeedbackRecord]

  public init(
    exportedAt: Date = Date(),
    entries: [DiaryEntryRecord],
    analyses: [StoredDecisionAnalysis],
    feedback: [FeedbackRecord]
  ) {
    self.exportedAt = exportedAt
    self.entries = entries
    self.analyses = analyses
    self.feedback = feedback
  }
}
