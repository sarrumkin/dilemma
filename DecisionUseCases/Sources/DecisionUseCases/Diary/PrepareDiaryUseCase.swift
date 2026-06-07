import DiaryVault

/// Prepares the private local diary database for app use.
/// It creates or migrates vault schema before the UI loads entries or statistics.
public struct PrepareDiaryUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws {
    try vault.prepare()
  }
}
