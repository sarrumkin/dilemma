import DecisionModels
import DiaryVault

/// Saves user feedback or final choice for a dilemma analysis.
/// It normalizes text input and maps the app command into the vault feedback record.
public struct SaveFeedbackUseCase: Sendable {
  private let vault: DiaryVault

  init(vault: DiaryVault) {
    self.vault = vault
  }

  public func callAsFunction(_ command: FeedbackCommand) throws {
    try vault.saveFeedback(
      Feedback(
        entryID: command.entryID,
        analysisID: command.analysisID,
        conflictWasUseful: command.conflictWasUseful,
        correctedClusterID: command.correctedClusterID,
        correctedAttributeName: command.correctedAttributeName?.trimmed.nilIfEmpty,
        chosenOptionIndex: command.chosenOptionIndex,
        note: command.note.trimmed
      ).storedModel()
    )
  }
}
