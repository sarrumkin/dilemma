import DecisionModels
import DiaryVault
import Foundation

extension EntryDraftCommand {
  func makeEntry(createdAt: Date = Date()) -> DiaryEntry {
    DiaryEntry(
      rawText: rawText.trimmed,
      options: [
        DiaryOption(
          index: 1,
          title: option1Title.trimmed,
          reasons: diaryReasons(benefits: option1Benefits, costs: option1Costs)
        ),
        DiaryOption(
          index: 2,
          title: option2Title.trimmed,
          reasons: diaryReasons(benefits: option2Benefits, costs: option2Costs)
        ),
      ],
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }

  func makeDraft(id: UUID) -> DecisionDraft {
    DecisionDraft(
      id: id,
      rawText: rawText.trimmed,
      options: [
        DecisionOption(
          index: 1,
          title: option1Title.trimmed,
          reasons: kernelReasons(benefits: option1Benefits, costs: option1Costs)
        ),
        DecisionOption(
          index: 2,
          title: option2Title.trimmed,
          reasons: kernelReasons(benefits: option2Benefits, costs: option2Costs)
        ),
      ]
    )
  }

  private func diaryReasons(benefits: [String], costs: [String]) -> [DiaryReason] {
    benefits.map { DiaryReason(text: $0.trimmed, polarity: .benefit) }
      + costs.map { DiaryReason(text: $0.trimmed, polarity: .cost) }
  }

  private func kernelReasons(benefits: [String], costs: [String]) -> [Reason] {
    benefits.map { Reason(text: $0.trimmed, polarity: .benefit) }
      + costs.map { Reason(text: $0.trimmed, polarity: .cost) }
  }
}

extension StoredDiaryEntry {
  func makeEntryDraftCommand() -> EntryDraftCommand {
    let sortedOptions = options.sorted { $0.index < $1.index }
    let option1 = sortedOptions.first(where: { $0.index == 1 }) ?? sortedOptions.first
    let option2 = sortedOptions.first(where: { $0.index == 2 }) ?? sortedOptions.dropFirst().first

    return EntryDraftCommand(
      rawText: rawText,
      option1Title: option1?.title ?? "",
      option2Title: option2?.title ?? "",
      option1Benefits: option1?.texts(for: .benefit) ?? [],
      option1Costs: option1?.texts(for: .cost) ?? [],
      option2Benefits: option2?.texts(for: .benefit) ?? [],
      option2Costs: option2?.texts(for: .cost) ?? []
    )
  }
}

private extension StoredDiaryOption {
  func texts(for polarity: StoredDiaryReasonPolarity) -> [String] {
    reasons
      .filter { $0.polarity == polarity }
      .map(\.text)
  }
}
