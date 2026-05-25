import DecisionUseCases
import Foundation

@MainActor
struct AppDependencies {
  let useCases: DecisionUseCases
  let userDefaults: UserDefaults

  static func live() -> AppDependencies {
    AppDependencies(useCases: .live(), userDefaults: .standard)
  }

  func makeDiaryListModel() -> DiaryListModel {
    DiaryListModel(loadDiarySnapshot: useCases.loadDiarySnapshot)
  }

  func makeNewEntryModel(onCreated: @escaping @MainActor (DiarySnapshot) -> Void) -> NewEntryModel {
    NewEntryModel(
      createAnalyzedEntry: useCases.createAnalyzedEntry,
      onCreated: onCreated
    )
  }

  func makeStatisticsModel() -> StatisticsModel {
    StatisticsModel(loadPreferenceStatistics: useCases.loadPreferenceStatistics)
  }

  func makePrivacySettingsModel() -> PrivacySettingsModel {
    PrivacySettingsModel(
      prepareDiary: useCases.prepareDiary,
      unlockDiary: useCases.unlockDiary,
      exportDiaryData: useCases.exportDiaryData,
      deleteDiaryData: useCases.deleteDiaryData,
      userDefaults: userDefaults
    )
  }
}
