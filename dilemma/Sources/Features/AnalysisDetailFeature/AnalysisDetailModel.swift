import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class AnalysisDetailModel {
  let entry: DiaryEntrySnapshot
  let analysis: AnalysisSnapshot?
  var conflictWasUseful = true
  var correctedClusterID: Int?
  var correctedAttributeName = ""
  var chosenOptionIndex: Int?
  var note = ""
  var didSaveFeedback = false
  var errorMessage: String?

  @ObservationIgnored private let saveFeedbackUseCase: SaveFeedbackUseCase
  @ObservationIgnored private let onFeedbackSaved: @MainActor () -> Void

  init(
    entry: DiaryEntrySnapshot,
    analysis: AnalysisSnapshot?,
    saveFeedback: SaveFeedbackUseCase,
    onFeedbackSaved: @escaping @MainActor () -> Void
  ) {
    self.entry = entry
    self.analysis = analysis
    self.saveFeedbackUseCase = saveFeedback
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

  func uniqueClusters() -> [ClusterProfileSnapshot] {
    guard let analysis else { return [] }
    return Dictionary(grouping: analysis.clusterProfiles, by: \.clusterID)
      .compactMap { $0.value.first }
      .sorted { $0.clusterID < $1.clusterID }
  }
}
