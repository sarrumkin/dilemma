import DecisionModels
import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class AnalysisDetailModel {
  let entry: DiaryEntry
  let analysis: DiaryAnalysis?
  var conflictWasUseful = true
  var correctedClusterID: Int?
  var correctedAttributeName = ""
  var chosenOptionIndex: Int?
  var note = ""
  var didSaveFeedback = false
  var exportURL: URL?
  var errorMessage: String?

  @ObservationIgnored private let saveFeedbackUseCase: SaveFeedbackUseCase
  @ObservationIgnored private let exportDilemmaDraft: ExportDilemmaDraftUseCase
  @ObservationIgnored private let onFeedbackSaved: @MainActor () -> Void

  init(
    entry: DiaryEntry,
    analysis: DiaryAnalysis?,
    saveFeedback: SaveFeedbackUseCase,
    exportDilemmaDraft: ExportDilemmaDraftUseCase,
    onFeedbackSaved: @escaping @MainActor () -> Void
  ) {
    self.entry = entry
    self.analysis = analysis
    self.saveFeedbackUseCase = saveFeedback
    self.exportDilemmaDraft = exportDilemmaDraft
    self.onFeedbackSaved = onFeedbackSaved
  }

  func saveFeedback() {
    guard let analysis else { return }
    do {
      try saveFeedbackUseCase(
        FeedbackCommand(
          entryID: entry.id,
          analysisID: analysis.id,
          conflictWasUseful: conflictWasUseful,
          correctedClusterID: correctedClusterID,
          correctedAttributeName: correctedAttributeName,
          chosenOptionIndex: chosenOptionIndex,
          note: note
        )
      )
      didSaveFeedback = true
      errorMessage = nil
      onFeedbackSaved()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func prepareExportFile() {
    do {
      exportURL = try exportDilemmaDraft.makeTemporaryExportFile(entry: entry)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func uniqueClusters() -> [ClusterProfile] {
    guard let analysis else { return [] }
    return Dictionary(grouping: analysis.clusterProfiles, by: \.clusterID)
      .compactMap { $0.value.first }
      .sorted { $0.clusterID < $1.clusterID }
  }
}
