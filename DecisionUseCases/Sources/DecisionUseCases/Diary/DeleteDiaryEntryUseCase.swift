import DecisionModels
import DiaryVault
import Foundation

/// Deletes one diary entry and its dependent vault data.
/// It returns a fresh snapshot so list and statistics screens can update from one operation.
public struct DeleteDiaryEntryUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction(id: UUID) throws -> DiarySnapshot {
    try vault.deleteEntry(id: id)
    return try LoadDiarySnapshotUseCase(vault: vault)()
  }
}
