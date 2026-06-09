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
  private(set) var likelyChoiceSimilarDilemmas: [SimilarDilemma] = []
  var didSaveFeedback = false
  var exportURL: URL?
  var errorMessage: String?

  @ObservationIgnored private let saveFeedbackUseCase: SaveFeedbackUseCase
  @ObservationIgnored private let loadFeedbackForAnalysisUseCase: LoadFeedbackForAnalysisUseCase
  @ObservationIgnored private let loadLikelyChoiceAdviceUseCase: LoadLikelyChoiceAdviceUseCase
  @ObservationIgnored private let exportDilemmaDraft: ExportDilemmaDraftUseCase
  @ObservationIgnored private let onFeedbackSaved: @MainActor () -> Void

  init(
    entry: DiaryEntry,
    analysis: DecisionAnalysis?,
    allEntries: [DiaryEntry] = [],
    latestAnalyses: [UUID: DecisionAnalysis] = [:],
    saveFeedback: SaveFeedbackUseCase,
    loadFeedbackForAnalysis: LoadFeedbackForAnalysisUseCase,
    loadLikelyChoiceAdvice: LoadLikelyChoiceAdviceUseCase,
    exportDilemmaDraft: ExportDilemmaDraftUseCase,
    onFeedbackSaved: @escaping @MainActor () -> Void
  ) {
    self.entry = entry
    self.analysis = analysis
    self.allEntries = allEntries
    self.latestAnalyses = latestAnalyses
    self.saveFeedbackUseCase = saveFeedback
    self.loadFeedbackForAnalysisUseCase = loadFeedbackForAnalysis
    self.loadLikelyChoiceAdviceUseCase = loadLikelyChoiceAdvice
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
    do {
      let snapshot = try loadLikelyChoiceAdviceUseCase(
        entry: entry,
        analysis: analysis,
        allEntries: allEntries,
        latestAnalyses: latestAnalyses,
        limit: limit
      )
      likelyChoiceAdvice = snapshot.advice
      likelyChoiceAdviceStatus = snapshot.status
      likelyChoiceSimilarDilemmas = snapshot.similarDilemmas
    } catch {
      likelyChoiceAdvice = nil
      likelyChoiceAdviceStatus = .unavailable
      likelyChoiceSimilarDilemmas = []
    }
  }

  func similarDilemmas(limit: Int = 5) -> [SimilarDilemma] {
    Array(likelyChoiceSimilarDilemmas.prefix(limit))
  }

  func makeSimilarDilemmaModel(for match: SimilarDilemma) -> AnalysisDetailModel {
    AnalysisDetailModel(
      entry: match.entry,
      analysis: latestAnalyses[match.entry.id],
      allEntries: allEntries,
      latestAnalyses: latestAnalyses,
      saveFeedback: saveFeedbackUseCase,
      loadFeedbackForAnalysis: loadFeedbackForAnalysisUseCase,
      loadLikelyChoiceAdvice: loadLikelyChoiceAdviceUseCase,
      exportDilemmaDraft: exportDilemmaDraft,
      onFeedbackSaved: onFeedbackSaved
    )
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
