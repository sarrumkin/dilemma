import DecisionModels
import DiaryVault
import Foundation

/// Loads the latest saved feedback for an entry and optional analysis.
/// Detail screens use it to restore the user's previous usefulness and choice inputs.
public struct LoadFeedbackForAnalysisUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction(entryID: UUID, analysisID: UUID?) throws -> Feedback? {
    try vault.feedback(entryID: entryID, analysisID: analysisID)?.decisionModel()
  }
}
