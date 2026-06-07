import DecisionModels
import DiaryVault
import Foundation

/// Creates a diary entry and immediately stores its full local analysis.
/// This is the main write workflow for new dilemmas, keeping entry and analysis persistence together.
public struct CreateAnalyzedEntryUseCase: Sendable {
  private let vault: DiaryVault
  private let analysisGenerator: EntryAnalysisGenerating

  init(vault: DiaryVault, analysisGenerator: EntryAnalysisGenerating) {
    self.vault = vault
    self.analysisGenerator = analysisGenerator
  }

  public func callAsFunction(_ command: EntryDraftCommand) async throws -> DiarySnapshot {
    let now = Date()
    var entry = command.makeEntry(createdAt: now)

    let analysis = try await analysisGenerator.analysis(for: command, entryID: entry.id)
    entry.updatedAt = Date()
    try vault.saveEntry(entry.storedModel())
    try vault.saveAnalysis(try analysis.storedModel())

    return try LoadDiarySnapshotUseCase(vault: vault)()
  }
}
