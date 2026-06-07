import DecisionModels
import DiaryVault

/// Loads the canonical diary snapshot for UI state.
/// It maps vault storage records into `DecisionModels` so screens never depend on DB models.
public struct LoadDiarySnapshotUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction() throws -> DiarySnapshot {
    try vault.snapshot().decisionModel()
  }
}
