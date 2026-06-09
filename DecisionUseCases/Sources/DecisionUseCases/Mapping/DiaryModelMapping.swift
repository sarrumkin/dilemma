import DecisionModels
import DiaryVault
import Foundation

extension StoredDiarySnapshot {
  func decisionModel() throws -> DiarySnapshot {
    var analyses: [UUID: DecisionAnalysis] = [:]
    for (entryID, analysis) in latestAnalyses {
      analyses[entryID] = try analysis.decisionModel()
    }
    let feedback = Dictionary(uniqueKeysWithValues: latestFeedback.map { entryID, feedback in
      (entryID, feedback.decisionModel())
    })
    return DiarySnapshot(
      entries: entries.map { $0.decisionModel() },
      latestAnalyses: analyses,
      latestFeedback: feedback
    )
  }
}

extension DiaryEntry {
  func storedModel() -> StoredDiaryEntry {
    StoredDiaryEntry(
      id: id,
      rawText: rawText,
      options: options.map { $0.storedModel() },
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension StoredDiaryEntry {
  func decisionModel() -> DiaryEntry {
    DiaryEntry(
      id: id,
      rawText: rawText,
      options: options.map { $0.decisionModel() },
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension DiaryOption {
  func storedModel() -> StoredDiaryOption {
    StoredDiaryOption(
      id: id,
      index: index,
      title: title,
      reasons: reasons.map { $0.storedModel() }
    )
  }
}

extension StoredDiaryOption {
  func decisionModel() -> DiaryOption {
    DiaryOption(
      id: id,
      index: index,
      title: title,
      reasons: reasons.map { $0.decisionModel() }
    )
  }
}

extension DiaryReason {
  func storedModel() -> StoredDiaryReason {
    StoredDiaryReason(
      id: id,
      text: text,
      polarity: StoredDiaryReasonPolarity(rawValue: polarity.rawValue) ?? .benefit
    )
  }
}

extension StoredDiaryReason {
  func decisionModel() -> DiaryReason {
    DiaryReason(
      id: id,
      text: text,
      polarity: DiaryReasonPolarity(rawValue: polarity.rawValue) ?? .benefit
    )
  }
}
