import DecisionModels
import DiaryVault

extension Feedback {
  func storedModel() -> StoredFeedback {
    StoredFeedback(
      id: id,
      entryID: entryID,
      analysisID: analysisID,
      conflictWasUseful: conflictWasUseful,
      correctedClusterID: correctedClusterID,
      correctedAttributeName: correctedAttributeName,
      chosenOptionIndex: chosenOptionIndex,
      note: note,
      createdAt: createdAt
    )
  }
}

extension StoredFeedback {
  func decisionModel() -> Feedback {
    Feedback(
      id: id,
      entryID: entryID,
      analysisID: analysisID,
      conflictWasUseful: conflictWasUseful,
      correctedClusterID: correctedClusterID,
      correctedAttributeName: correctedAttributeName,
      chosenOptionIndex: chosenOptionIndex,
      note: note,
      createdAt: createdAt
    )
  }
}
