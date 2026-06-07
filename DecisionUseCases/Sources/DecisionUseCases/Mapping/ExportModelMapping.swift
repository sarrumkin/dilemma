import DecisionModels
import DiaryVault

extension StoredDiaryExport {
  func decisionModel() throws -> DiaryExport {
    DiaryExport(
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      entries: entries.map { $0.decisionModel() },
      analyses: try analyses.map { try $0.decisionModel() },
      feedback: feedback.map { $0.decisionModel() }
    )
  }
}
