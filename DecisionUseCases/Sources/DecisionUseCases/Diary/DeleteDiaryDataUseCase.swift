import DiaryVault

/// Deletes all local diary data from the vault.
/// Settings uses it for the destructive privacy workflow without touching storage APIs directly.
public struct DeleteDiaryDataUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws {
    try vault.deleteAllData()
  }
}
