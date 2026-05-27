import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class SettingsModel {
  var requiresDeviceUnlock: Bool {
    didSet {
      userDefaults.set(requiresDeviceUnlock, forKey: Self.requiresDeviceUnlockKey)
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
  @ObservationIgnored private let unlockDiary: UnlockDiaryUseCase
  @ObservationIgnored private let exportDiaryData: ExportDiaryDataUseCase
  @ObservationIgnored private let deleteDiaryData: DeleteDiaryDataUseCase
  @ObservationIgnored private let userDefaults: UserDefaults
  private static let requiresDeviceUnlockKey = "requiresDeviceUnlock"
  private static let usesDarkThemeKey = "usesDarkTheme"

  init(
    prepareDiary: PrepareDiaryUseCase,
    unlockDiary: UnlockDiaryUseCase,
    exportDiaryData: ExportDiaryDataUseCase,
    deleteDiaryData: DeleteDiaryDataUseCase,
    userDefaults: UserDefaults
  ) {
    self.prepareDiary = prepareDiary
    self.unlockDiary = unlockDiary
    self.exportDiaryData = exportDiaryData
    self.deleteDiaryData = deleteDiaryData
    self.userDefaults = userDefaults
    self.requiresDeviceUnlock = userDefaults.bool(forKey: Self.requiresDeviceUnlockKey)
    self.usesDarkTheme = userDefaults.bool(forKey: Self.usesDarkThemeKey)
  }

  func unlockIfNeededAndPrepare() async -> Bool { 
    do {
      if requiresDeviceUnlock {
        try await unlockDiary()
      }
      try prepareDiary()
      errorMessage = nil
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  func prepareExportFile() {
    do {
      exportURL = try exportDiaryData.makeTemporaryExportFile()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
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
      errorMessage = error.localizedDescription
      return false
    }
  }
}
