import DecisionModels
import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class StatisticsModel {
  private(set) var statistics = PreferenceStatistics.empty
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
