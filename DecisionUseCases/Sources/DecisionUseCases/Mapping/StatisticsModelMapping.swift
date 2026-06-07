import DecisionModels
import DiaryVault

extension StoredPreferenceStatistics {
  func decisionModel() -> PreferenceStatistics {
    PreferenceStatistics(
      entryCount: entryCount,
      feedbackCount: feedbackCount,
      acceptedConflictCount: acceptedConflictCount,
      rejectedConflictCount: rejectedConflictCount,
      mostFrequentClusters: mostFrequentClusters.map { $0.decisionModel() },
      chosenOptionCounts: chosenOptionCounts,
      chosenClusterDilemmaCount: chosenClusterDilemmaCount
    )
  }
}

extension StoredClusterFrequency {
  func decisionModel() -> ClusterFrequency {
    ClusterFrequency(clusterID: clusterID, label: label, count: count)
  }
}
