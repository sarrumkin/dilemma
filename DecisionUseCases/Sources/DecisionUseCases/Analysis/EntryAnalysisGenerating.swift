import DecisionModels
import Foundation

/// Testable seam for generating full analysis for a diary entry.
/// Live code uses the local kernel; tests can inject deterministic analysis without loading models.
protocol EntryAnalysisGenerating: Sendable {
  func analysis(for command: EntryDraftCommand, entryID: UUID) async throws -> DecisionAnalysis
}

/// Live implementation that maps entry commands into kernel drafts.
/// It preserves the diary entry id as the analysis entry id so vault records stay connected.
struct LiveEntryAnalysisGenerator: EntryAnalysisGenerating {
  let runAnalysis: RunDecisionAnalysisUseCase

  func analysis(for command: EntryDraftCommand, entryID: UUID) async throws -> DecisionAnalysis {
    try await runAnalysis(command.makeDraft(id: entryID))
  }
}
