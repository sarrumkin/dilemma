import DiaryVault
import Foundation

/// Composition container for all app-facing business operations.
/// The app receives this single value so UI code can depend on workflows instead of kernel or vault details.
public struct DecisionUseCases: Sendable {
  public let prepareDiary: PrepareDiaryUseCase
  public let loadDiarySnapshot: LoadDiarySnapshotUseCase
  public let createAnalyzedEntry: CreateAnalyzedEntryUseCase
  public let saveFeedback: SaveFeedbackUseCase
  public let loadFeedbackForAnalysis: LoadFeedbackForAnalysisUseCase
  public let loadPreferenceStatistics: LoadPreferenceStatisticsUseCase
  public let exportDiaryData: ExportDiaryDataUseCase
  public let exportDilemmaDraft: ExportDilemmaDraftUseCase
  public let importDilemmaDrafts: ImportDilemmaDraftsUseCase
  public let reanalyzeIncompleteAnalyses: ReanalyzeIncompleteAnalysesUseCase
  public let deleteDiaryEntry: DeleteDiaryEntryUseCase
  public let deleteDiaryData: DeleteDiaryDataUseCase

  public static func live() -> DecisionUseCases {
    let vault = DiaryVault()
    return live(vault: vault)
  }

  static func live(vault: DiaryVault) -> DecisionUseCases {
    let analysisGenerator = LiveEntryAnalysisGenerator(runAnalysis: RunDecisionAnalysisUseCase())
    return DecisionUseCases(
      prepareDiary: PrepareDiaryUseCase(vault: vault),
      loadDiarySnapshot: LoadDiarySnapshotUseCase(vault: vault),
      createAnalyzedEntry: CreateAnalyzedEntryUseCase(vault: vault, analysisGenerator: analysisGenerator),
      saveFeedback: SaveFeedbackUseCase(vault: vault),
      loadFeedbackForAnalysis: LoadFeedbackForAnalysisUseCase(vault: vault),
      loadPreferenceStatistics: LoadPreferenceStatisticsUseCase(vault: vault),
      exportDiaryData: ExportDiaryDataUseCase(vault: vault),
      exportDilemmaDraft: ExportDilemmaDraftUseCase(),
      importDilemmaDrafts: ImportDilemmaDraftsUseCase(vault: vault, analysisGenerator: analysisGenerator),
      reanalyzeIncompleteAnalyses: ReanalyzeIncompleteAnalysesUseCase(vault: vault, analysisGenerator: analysisGenerator),
      deleteDiaryEntry: DeleteDiaryEntryUseCase(vault: vault),
      deleteDiaryData: DeleteDiaryDataUseCase(vault: vault)
    )
  }

  static func testing(vault: DiaryVault, analysisGenerator: EntryAnalysisGenerating) -> DecisionUseCases {
    DecisionUseCases(
      prepareDiary: PrepareDiaryUseCase(vault: vault),
      loadDiarySnapshot: LoadDiarySnapshotUseCase(vault: vault),
      createAnalyzedEntry: CreateAnalyzedEntryUseCase(vault: vault, analysisGenerator: analysisGenerator),
      saveFeedback: SaveFeedbackUseCase(vault: vault),
      loadFeedbackForAnalysis: LoadFeedbackForAnalysisUseCase(vault: vault),
      loadPreferenceStatistics: LoadPreferenceStatisticsUseCase(vault: vault),
      exportDiaryData: ExportDiaryDataUseCase(vault: vault),
      exportDilemmaDraft: ExportDilemmaDraftUseCase(),
      importDilemmaDrafts: ImportDilemmaDraftsUseCase(vault: vault, analysisGenerator: analysisGenerator),
      reanalyzeIncompleteAnalyses: ReanalyzeIncompleteAnalysesUseCase(vault: vault, analysisGenerator: analysisGenerator),
      deleteDiaryEntry: DeleteDiaryEntryUseCase(vault: vault),
      deleteDiaryData: DeleteDiaryDataUseCase(vault: vault)
    )
  }
}
