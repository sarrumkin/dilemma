import DecisionModels
import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class AnalysisDetailModel {
  let entry: DiaryEntry
  let analysis: DecisionAnalysis?
  let allEntries: [DiaryEntry]
  let latestAnalyses: [UUID: DecisionAnalysis]
  var chosenOptionIndex: Int?
  var note = ""
  private(set) var savedFeedback: Feedback?
  private(set) var isEditingFeedback = false
  private(set) var likelyChoiceAdvice: LikelyChoiceAdvice?
  private(set) var likelyChoiceAdviceStatus: LikelyChoiceAdviceStatus = .noAnalysis
  var didSaveFeedback = false
  var exportURL: URL?
  var errorMessage: String?

  @ObservationIgnored private let saveFeedbackUseCase: SaveFeedbackUseCase
  @ObservationIgnored private let loadFeedbackForAnalysisUseCase: LoadFeedbackForAnalysisUseCase
  @ObservationIgnored private let exportDilemmaDraft: ExportDilemmaDraftUseCase
  @ObservationIgnored private let onFeedbackSaved: @MainActor () -> Void

  init(
    entry: DiaryEntry,
    analysis: DecisionAnalysis?,
    allEntries: [DiaryEntry] = [],
    latestAnalyses: [UUID: DecisionAnalysis] = [:],
    saveFeedback: SaveFeedbackUseCase,
    loadFeedbackForAnalysis: LoadFeedbackForAnalysisUseCase,
    exportDilemmaDraft: ExportDilemmaDraftUseCase,
    onFeedbackSaved: @escaping @MainActor () -> Void
  ) {
    self.entry = entry
    self.analysis = analysis
    self.allEntries = allEntries
    self.latestAnalyses = latestAnalyses
    self.saveFeedbackUseCase = saveFeedback
    self.loadFeedbackForAnalysisUseCase = loadFeedbackForAnalysis
    self.exportDilemmaDraft = exportDilemmaDraft
    self.onFeedbackSaved = onFeedbackSaved
    reloadSavedFeedback()
    reloadLikelyChoiceAdvice()
  }

  var canSaveFeedback: Bool {
    analysis != nil && isEditingFeedback && (chosenOptionIndex != nil || hasSavedFeedback)
  }

  var hasSavedFeedback: Bool {
    savedFeedback != nil
  }

  var savedDecisionTitle: String {
    optionTitle(for: savedFeedback?.chosenOptionIndex)
  }

  var recordedChoiceTitle: String? {
    guard let chosenOptionIndex = savedFeedback?.chosenOptionIndex else { return nil }
    return optionTitle(for: chosenOptionIndex)
  }

  var savedNote: String {
    savedFeedback?.note ?? ""
  }

  var optionTitlesByIndex: [Int: String] {
    Dictionary(uniqueKeysWithValues: entry.options.map { ($0.index, $0.title) })
  }

  var saveFeedbackButtonTitle: String {
    hasSavedFeedback ? "Save changes" : "Save decision"
  }

  func saveFeedback() {
    guard let analysis, canSaveFeedback else { return }
    do {
      try saveFeedbackUseCase(
        FeedbackCommand(
          entryID: entry.id,
          analysisID: analysis.id,
          conflictWasUseful: true,
          chosenOptionIndex: chosenOptionIndex,
          note: note
        )
      )
      savedFeedback = try loadFeedbackForAnalysisUseCase(entryID: entry.id, analysisID: analysis.id)
      if savedFeedback == nil {
        chosenOptionIndex = nil
        note = ""
        isEditingFeedback = false
        didSaveFeedback = false
      } else {
        applySavedFeedback()
        isEditingFeedback = false
        didSaveFeedback = true
      }
      errorMessage = nil
      reloadLikelyChoiceAdvice()
      onFeedbackSaved()
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .saveFeedback)
    }
  }

  func startEditingFeedback() {
    chosenOptionIndex = savedFeedback?.chosenOptionIndex
    note = savedFeedback?.note ?? ""
    isEditingFeedback = true
    didSaveFeedback = false
  }

  func cancelEditingFeedback() {
    applySavedFeedback()
    isEditingFeedback = false
    didSaveFeedback = false
  }

  func prepareExportFile() {
    do {
      exportURL = try exportDilemmaDraft.makeTemporaryExportFile(entry: entry, analysis: analysis)
      errorMessage = nil
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .exportEntry)
    }
  }

  func reloadSavedFeedback() {
    guard let analysis else {
      savedFeedback = nil
      chosenOptionIndex = nil
      note = ""
      isEditingFeedback = false
      return
    }

    do {
      savedFeedback = try loadFeedbackForAnalysisUseCase(entryID: entry.id, analysisID: analysis.id)
      if savedFeedback == nil {
        chosenOptionIndex = nil
        note = ""
        isEditingFeedback = false
      } else {
        applySavedFeedback()
        isEditingFeedback = false
      }
    } catch {
      savedFeedback = nil
      chosenOptionIndex = nil
      note = ""
      isEditingFeedback = false
    }
  }

  func reloadLikelyChoiceAdvice(limit: Int = 5) {
    guard let analysis else {
      likelyChoiceAdvice = nil
      likelyChoiceAdviceStatus = .noAnalysis
      return
    }

    do {
      let visibleCandidates = visibleSimilarDilemmaCandidates(limit: limit)
      guard !visibleCandidates.isEmpty else {
        likelyChoiceAdvice = nil
        likelyChoiceAdviceStatus = .noSimilarDilemmas
        return
      }

      let decidedChoices = try similarDecidedChoices(from: visibleCandidates)
      guard !decidedChoices.isEmpty else {
        likelyChoiceAdvice = nil
        likelyChoiceAdviceStatus = .notEnoughMarkedSimilarDilemmas
        return
      }

      let advice = LikelyChoiceAdvice(
        currentAnalysis: analysis,
        currentOptionIndices: entry.options.map(\.index),
        decidedChoices: decidedChoices,
        limit: limit
      )
      likelyChoiceAdvice = advice
      likelyChoiceAdviceStatus = advice == nil ? .unavailable : .available
    } catch {
      likelyChoiceAdvice = nil
      likelyChoiceAdviceStatus = .unavailable
    }
  }

  func similarDilemmas(limit: Int = 5) -> [SimilarDilemma] {
    guard let analysis else { return [] }

    return visibleSimilarDilemmaCandidates(limit: limit)
      .map { candidate in
        SimilarDilemma(
          entry: candidate.entry,
          score: candidate.score,
          recordedChoiceTitle: recordedChoiceTitle(for: candidate)
        )
      }
  }

  func makeSimilarDilemmaModel(for match: SimilarDilemma) -> AnalysisDetailModel {
    AnalysisDetailModel(
      entry: match.entry,
      analysis: latestAnalyses[match.entry.id],
      allEntries: allEntries,
      latestAnalyses: latestAnalyses,
      saveFeedback: saveFeedbackUseCase,
      loadFeedbackForAnalysis: loadFeedbackForAnalysisUseCase,
      exportDilemmaDraft: exportDilemmaDraft,
      onFeedbackSaved: onFeedbackSaved
    )
  }

  private func visibleSimilarDilemmaCandidates(limit: Int) -> [SimilarDilemmaCandidate] {
    Array(similarDilemmaCandidates().prefix(limit))
  }

  private func similarDilemmaCandidates() -> [SimilarDilemmaCandidate] {
    guard
      let analysis
    else {
      return []
    }

    return allEntries.compactMap { candidateEntry in
      guard
        candidateEntry.id != entry.id,
        let candidateAnalysis = latestAnalyses[candidateEntry.id],
        let score = LikelyChoiceAdvice.conflictSimilarity(
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
        let feedback = try loadFeedbackForAnalysisUseCase(
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
      let feedback = try? loadFeedbackForAnalysisUseCase(
        entryID: candidate.entry.id,
        analysisID: candidate.analysis.id
      ),
      let chosenOptionIndex = feedback.chosenOptionIndex
    else {
      return nil
    }

    return optionTitle(for: chosenOptionIndex, in: candidate.entry)
  }

  private func applySavedFeedback() {
    chosenOptionIndex = savedFeedback?.chosenOptionIndex
    note = savedFeedback?.note ?? ""
  }

  private func optionTitle(for optionIndex: Int?) -> String {
    guard let optionIndex else { return "Not decided yet" }
    return optionTitle(for: optionIndex, in: entry)
  }

  private func optionTitle(for optionIndex: Int, in entry: DiaryEntry) -> String {
    entry.options.first { $0.index == optionIndex }?.title ?? "Option \(optionIndex)"
  }
}

enum LikelyChoiceAdviceStatus: Equatable {
  case noAnalysis
  case noSimilarDilemmas
  case notEnoughMarkedSimilarDilemmas
  case unavailable
  case available
}

struct SimilarDilemma: Identifiable {
  var id: UUID { entry.id }
  let entry: DiaryEntry
  let score: Double
  let recordedChoiceTitle: String?
}

private struct SimilarDilemmaCandidate {
  let entry: DiaryEntry
  let analysis: DecisionAnalysis
  let score: Double
}
