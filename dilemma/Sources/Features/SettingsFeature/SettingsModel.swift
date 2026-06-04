import DecisionUseCases
import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Hashable, Identifiable {
  case english = "en"
  case russian = "ru"

  var id: String {
    rawValue
  }

  var locale: Locale {
    Locale(identifier: rawValue)
  }

  static var preferred: AppLanguage {
    let preferredIdentifier = Locale.preferredLanguages.first ?? Locale.current.identifier
    return preferredIdentifier.hasPrefix("ru") ? .russian : .english
  }
}

@MainActor
@Observable
final class SettingsModel {
  var appLanguage: AppLanguage {
    didSet {
      AppLocalization.language = appLanguage
      userDefaults.set(appLanguage.rawValue, forKey: Self.appLanguageKey)
    }
  }

  var usesDarkTheme: Bool {
    didSet {
      userDefaults.set(usesDarkTheme, forKey: Self.usesDarkThemeKey)
    }
  }
  var exportURL: URL?
  var errorMessage: String?

  @ObservationIgnored private let prepareDiary: PrepareDiaryUseCase
  @ObservationIgnored private let exportDiaryData: ExportDiaryDataUseCase
  @ObservationIgnored private let deleteDiaryData: DeleteDiaryDataUseCase
  @ObservationIgnored private let userDefaults: UserDefaults
  private static let appLanguageKey = "appLanguage"
  private static let usesDarkThemeKey = "usesDarkTheme"

  init(
    prepareDiary: PrepareDiaryUseCase,
    exportDiaryData: ExportDiaryDataUseCase,
    deleteDiaryData: DeleteDiaryDataUseCase,
    userDefaults: UserDefaults
  ) {
    self.prepareDiary = prepareDiary
    self.exportDiaryData = exportDiaryData
    self.deleteDiaryData = deleteDiaryData
    self.userDefaults = userDefaults
    let storedLanguage = userDefaults.string(forKey: Self.appLanguageKey)
      .flatMap(AppLanguage.init(rawValue:)) ?? .preferred
    self.appLanguage = storedLanguage
    self.usesDarkTheme = userDefaults.bool(forKey: Self.usesDarkThemeKey)
    AppLocalization.language = storedLanguage
  }

  func prepareDiaryForUse() -> Bool {
    do {
      try prepareDiary()
      errorMessage = nil
      return true
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .prepareDiary)
      return false
    }
  }

  func prepareExportFile() {
    do {
      exportURL = try exportDiaryData.makeTemporaryExportFile()
      errorMessage = nil
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .exportDiary)
    }
  }

  func deleteAllUserData() -> Bool {
    do {
      try deleteDiaryData()
      try prepareDiary()
      exportURL = nil
      errorMessage = nil
      return true
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .deleteData)
      return false
    }
  }
}
