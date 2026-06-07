/// Aggregate preference counters for the diary.
/// It summarizes feedback and chosen outcomes without exposing vault tables to the app.
public struct PreferenceStatistics: Codable, Equatable, Sendable {
  public var entryCount: Int
  public var feedbackCount: Int
  public var acceptedConflictCount: Int
  public var rejectedConflictCount: Int
  public var mostFrequentClusters: [ClusterFrequency]
  public var chosenOptionCounts: [Int: Int]
  public var chosenClusterDilemmaCount: Int

  public init(
    entryCount: Int,
    feedbackCount: Int,
    acceptedConflictCount: Int,
    rejectedConflictCount: Int,
    mostFrequentClusters: [ClusterFrequency],
    chosenOptionCounts: [Int: Int],
    chosenClusterDilemmaCount: Int = 0
  ) {
    self.entryCount = entryCount
    self.feedbackCount = feedbackCount
    self.acceptedConflictCount = acceptedConflictCount
    self.rejectedConflictCount = rejectedConflictCount
    self.mostFrequentClusters = mostFrequentClusters
    self.chosenOptionCounts = chosenOptionCounts
    self.chosenClusterDilemmaCount = chosenClusterDilemmaCount
  }

  public static var empty: PreferenceStatistics {
    PreferenceStatistics(
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

/// Frequency of a cluster in aggregate statistics.
/// It gives statistics views stable cluster identity, label, and count for ranking common themes.
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
