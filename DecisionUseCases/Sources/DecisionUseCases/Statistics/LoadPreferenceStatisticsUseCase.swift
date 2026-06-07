import DecisionModels
import DiaryVault

/// Loads aggregate preference statistics from local diary data.
/// It maps vault aggregate records into canonical statistics models for the stats screen.
public struct LoadPreferenceStatisticsUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws -> PreferenceStatistics {
    try vault.statistics().decisionModel()
  }
}
