import DecisionModels
import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class StatisticsModel {
  private(set) var statistics = PreferenceStatistics.empty
  private(set) var clusterStatistics = ClusterDilemmaStatistics.empty
  var errorMessage: String?

  @ObservationIgnored private let loadPreferenceStatistics: LoadPreferenceStatisticsUseCase
  @ObservationIgnored private let loadDiarySnapshot: LoadDiarySnapshotUseCase

  init(
    loadPreferenceStatistics: LoadPreferenceStatisticsUseCase,
    loadDiarySnapshot: LoadDiarySnapshotUseCase
  ) {
    self.loadPreferenceStatistics = loadPreferenceStatistics
    self.loadDiarySnapshot = loadDiarySnapshot
  }

  var hasDiaryEntries: Bool {
    statistics.entryCount > 0
  }

  var hasAnalyzedEntries: Bool {
    clusterStatistics.analyzedEntryCount > 0
  }

  var hasClusterGroups: Bool {
    !clusterStatistics.groups.isEmpty
  }

  func reload() {
    do {
      let loadedStatistics = try loadPreferenceStatistics()
      let snapshot = try loadDiarySnapshot()
      statistics = loadedStatistics
      clusterStatistics = ClusterDilemmaStatistics(snapshot: snapshot)
      errorMessage = nil
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .loadStatistics)
    }
  }
}
