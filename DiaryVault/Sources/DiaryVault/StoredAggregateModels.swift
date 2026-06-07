import Foundation

public struct StoredClusterFrequency: Codable, Equatable, Sendable {
  public var clusterID: Int
  public var label: String
  public var count: Int

  public init(clusterID: Int, label: String, count: Int) {
    self.clusterID = clusterID
    self.label = label
    self.count = count
  }
}

public struct StoredPreferenceStatistics: Codable, Equatable, Sendable {
  public var entryCount: Int
  public var feedbackCount: Int
  public var acceptedConflictCount: Int
  public var rejectedConflictCount: Int
  public var mostFrequentClusters: [StoredClusterFrequency]
  public var chosenOptionCounts: [Int: Int]
  public var chosenClusterDilemmaCount: Int

  public init(
    entryCount: Int,
    feedbackCount: Int,
    acceptedConflictCount: Int,
    rejectedConflictCount: Int,
    mostFrequentClusters: [StoredClusterFrequency],
    chosenOptionCounts: [Int: Int],
    chosenClusterDilemmaCount: Int
  ) {
    self.entryCount = entryCount
    self.feedbackCount = feedbackCount
    self.acceptedConflictCount = acceptedConflictCount
    self.rejectedConflictCount = rejectedConflictCount
    self.mostFrequentClusters = mostFrequentClusters
    self.chosenOptionCounts = chosenOptionCounts
    self.chosenClusterDilemmaCount = chosenClusterDilemmaCount
  }

  public static var empty: StoredPreferenceStatistics {
    StoredPreferenceStatistics(
      entryCount: 0,
      feedbackCount: 0,
      acceptedConflictCount: 0,
      rejectedConflictCount: 0,
      mostFrequentClusters: [],
      chosenOptionCounts: [:],
      chosenClusterDilemmaCount: 0
    )
  }
}

public struct StoredDiaryExport: Codable, Equatable, Sendable {
  public var schemaVersion: Int
  public var exportedAt: Date
  public var entries: [StoredDiaryEntry]
  public var analyses: [StoredDecisionAnalysis]
  public var feedback: [StoredFeedback]

  public init(
    schemaVersion: Int = 1,
    exportedAt: Date = Date(),
    entries: [StoredDiaryEntry],
    analyses: [StoredDecisionAnalysis],
    feedback: [StoredFeedback]
  ) {
    self.schemaVersion = schemaVersion
    self.exportedAt = exportedAt
    self.entries = entries
    self.analyses = analyses
    self.feedback = feedback
  }
}
