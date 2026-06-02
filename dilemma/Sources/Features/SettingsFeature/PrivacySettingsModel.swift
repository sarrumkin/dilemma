import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class PrivacySettingsModel {
  var requiresDeviceUnlock: Bool {
    didSet {
      userDefaults.set(requiresDeviceUnlock, forKey: Self.requiresDeviceUnlockKey)
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
  }

  func unlockIfNeededAndPrepare() async -> Bool {
    do {
      if requiresDeviceUnlock {
        try await unlockDiary(reason: String(localized: "Unlock your private decision diary."))
      }
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
