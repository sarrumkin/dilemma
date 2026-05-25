import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class StatisticsModel {
  private(set) var statistics = PreferenceStatisticsSnapshot.empty
  var errorMessage: String?

  @ObservationIgnored private let loadPreferenceStatistics: LoadPreferenceStatisticsUseCase

  init(loadPreferenceStatistics: LoadPreferenceStatisticsUseCase) {
    self.loadPreferenceStatistics = loadPreferenceStatistics
  }

  func reload() {
    do {
      statistics = try loadPreferenceStatistics()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private extension PreferenceStatisticsSnapshot {
  static var empty: PreferenceStatisticsSnapshot {
    PreferenceStatisticsSnapshot(
      entryCount: 0,
      feedbackCount: 0,
      acceptedConflictCount: 0,
      rejectedConflictCount: 0,
      mostFrequentClusters: [],
      chosenOptionCounts: [:]
    )
  }
}
