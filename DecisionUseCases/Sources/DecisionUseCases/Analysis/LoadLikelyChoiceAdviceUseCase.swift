import DecisionKernel
import DecisionModels
import DiaryVault
import Foundation

public struct LikelyChoiceAdviceSnapshot: Equatable, Sendable {
  public var advice: LikelyChoiceAdvice?
  public var status: LikelyChoiceAdviceStatus
  public var similarDilemmas: [SimilarDilemma]

  public init(
    advice: LikelyChoiceAdvice?,
    status: LikelyChoiceAdviceStatus,
    similarDilemmas: [SimilarDilemma]
  ) {
    self.advice = advice
    self.status = status
    self.similarDilemmas = similarDilemmas
  }
}

public enum LikelyChoiceAdviceStatus: Equatable, Sendable {
  case noAnalysis
  case noSimilarDilemmas
  case notEnoughMarkedSimilarDilemmas
  case unavailable
  case available
}

public struct SimilarDilemma: Identifiable, Equatable, Sendable {
  public var id: UUID { entry.id }
  public let entry: DiaryEntry
  public let score: Double
  public let recordedChoiceTitle: String?

  public init(entry: DiaryEntry, score: Double, recordedChoiceTitle: String?) {
    self.entry = entry
    self.score = score
    self.recordedChoiceTitle = recordedChoiceTitle
  }
}

public struct LoadLikelyChoiceAdviceUseCase: Sendable {
  private let loadFeedbackForAnalysis: LoadFeedbackForAnalysisUseCase
  private let recommendationService: DecisionRecommendationService

  init(
    vault: DiaryVault,
    recommendationService: DecisionRecommendationService = DecisionRecommendationService()
  ) {
    self.loadFeedbackForAnalysis = LoadFeedbackForAnalysisUseCase(vault: vault)
    self.recommendationService = recommendationService
  }

  public func callAsFunction(
    entry: DiaryEntry,
    analysis: DecisionAnalysis?,
    allEntries: [DiaryEntry],
    latestAnalyses: [UUID: DecisionAnalysis],
    limit: Int = 5
  ) throws -> LikelyChoiceAdviceSnapshot {
    guard let analysis else {
      return LikelyChoiceAdviceSnapshot(advice: nil, status: .noAnalysis, similarDilemmas: [])
    }

    let visibleCandidates = Array(similarDilemmaCandidates(
      entry: entry,
      analysis: analysis,
      allEntries: allEntries,
      latestAnalyses: latestAnalyses
    ).prefix(limit))
    guard !visibleCandidates.isEmpty else {
      return LikelyChoiceAdviceSnapshot(advice: nil, status: .noSimilarDilemmas, similarDilemmas: [])
    }

    let similarDilemmas = visibleCandidates.map { candidate in
      SimilarDilemma(
        entry: candidate.entry,
        score: candidate.score,
        recordedChoiceTitle: recordedChoiceTitle(for: candidate)
      )
    }
    let decidedChoices = try similarDecidedChoices(from: visibleCandidates)
    guard !decidedChoices.isEmpty else {
      return LikelyChoiceAdviceSnapshot(
        advice: nil,
        status: .notEnoughMarkedSimilarDilemmas,
        similarDilemmas: similarDilemmas
      )
    }

    let advice = recommendationService.likelyChoiceAdvice(
      currentAnalysis: analysis,
      currentOptionIndices: entry.options.map(\.index),
      decidedChoices: decidedChoices,
      limit: limit
    )
    return LikelyChoiceAdviceSnapshot(
      advice: advice,
      status: advice == nil ? .unavailable : .available,
      similarDilemmas: similarDilemmas
    )
  }

  private func similarDilemmaCandidates(
    entry: DiaryEntry,
    analysis: DecisionAnalysis,
    allEntries: [DiaryEntry],
    latestAnalyses: [UUID: DecisionAnalysis]
  ) -> [SimilarDilemmaCandidate] {
    allEntries.compactMap { candidateEntry in
      guard
        candidateEntry.id != entry.id,
        let candidateAnalysis = latestAnalyses[candidateEntry.id],
        let score = DecisionRecommendationService.conflictSimilarity(
          between: analysis,
          and: candidateAnalysis
        )
      else {
        return nil
      }

      guard score.isFinite, score > 0 else { return nil }

      return SimilarDilemmaCandidate(
        entry: candidateEntry,
        analysis: candidateAnalysis,
        score: score
      )
    }
    .sorted {
      if $0.score == $1.score {
        return $0.entry.updatedAt > $1.entry.updatedAt
      }
      return $0.score > $1.score
    }
  }

  private func similarDecidedChoices(
    from candidates: [SimilarDilemmaCandidate]
  ) throws -> [SimilarDecidedChoice] {
    var choices: [SimilarDecidedChoice] = []
    for candidate in candidates {
      guard
        let feedback = try loadFeedbackForAnalysis(
          entryID: candidate.entry.id,
          analysisID: candidate.analysis.id
        ),
        let chosenOptionIndex = feedback.chosenOptionIndex
      else {
        continue
      }

      choices.append(SimilarDecidedChoice(
        analysis: candidate.analysis,
        chosenOptionIndex: chosenOptionIndex
      ))
    }
    return choices
  }

  private func recordedChoiceTitle(for candidate: SimilarDilemmaCandidate) -> String? {
    guard
      let feedback = try? loadFeedbackForAnalysis(
        entryID: candidate.entry.id,
        analysisID: candidate.analysis.id
      ),
      let chosenOptionIndex = feedback.chosenOptionIndex
    else {
      return nil
    }

    return optionTitle(for: chosenOptionIndex, in: candidate.entry)
  }

  private func optionTitle(for optionIndex: Int, in entry: DiaryEntry) -> String {
    entry.options.first { $0.index == optionIndex }?.title ?? "Option \(optionIndex)"
  }
}

private struct SimilarDilemmaCandidate {
  let entry: DiaryEntry
  let analysis: DecisionAnalysis
  let score: Double
}
