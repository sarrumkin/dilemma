import DecisionModels
import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class StatisticsModel {
  private(set) var statistics = PreferenceStatistics.empty
  private(set) var clusterStatistics = ClusterDilemmaStatistics.empty
  private(set) var recordedDecisionRecords: [RecordedDecisionRecord] = []
  var errorMessage: String?

  @ObservationIgnored private let loadPreferenceStatistics: LoadPreferenceStatisticsUseCase
  @ObservationIgnored private let loadDiarySnapshot: LoadDiarySnapshotUseCase
  @ObservationIgnored private let loadFeedbackForAnalysis: LoadFeedbackForAnalysisUseCase

  init(
    loadPreferenceStatistics: LoadPreferenceStatisticsUseCase,
    loadDiarySnapshot: LoadDiarySnapshotUseCase,
    loadFeedbackForAnalysis: LoadFeedbackForAnalysisUseCase
  ) {
    self.loadPreferenceStatistics = loadPreferenceStatistics
    self.loadDiarySnapshot = loadDiarySnapshot
    self.loadFeedbackForAnalysis = loadFeedbackForAnalysis
  }

  var hasDiaryEntries: Bool {
    statistics.entryCount > 0
  }

  var hasAnalyzedEntries: Bool {
    clusterStatistics.analyzedEntryCount > 0
  }

  var hasClusterGroups: Bool {
    !clusterStatistics.groups.isEmpty
  }

  var hasRecordedDecisions: Bool {
    !recordedDecisionRecords.isEmpty
  }

  func reload() {
    do {
      let loadedStatistics = try loadPreferenceStatistics()
      let snapshot = try loadDiarySnapshot()
      statistics = loadedStatistics
      clusterStatistics = ClusterDilemmaStatistics(snapshot: snapshot)
      recordedDecisionRecords = try recordedDecisions(from: snapshot)
      errorMessage = nil
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .loadStatistics)
    }
  }

  private func recordedDecisions(from snapshot: DiarySnapshot) throws -> [RecordedDecisionRecord] {
    try snapshot.entries.compactMap { entry in
      guard
        let analysis = snapshot.latestAnalyses[entry.id],
        let feedback = try loadFeedbackForAnalysis(entryID: entry.id, analysisID: analysis.id),
        feedback.chosenOptionIndex != nil
      else {
        return nil
      }

      return RecordedDecisionRecord(
        entry: entry,
        analysis: analysis,
        feedback: feedback
      )
    }
    .sorted {
      if $0.feedback.createdAt == $1.feedback.createdAt {
        return $0.entry.updatedAt > $1.entry.updatedAt
      }
      return $0.feedback.createdAt > $1.feedback.createdAt
    }
  }
}

struct RecordedDecisionRecord: Identifiable, Equatable, Sendable {
  var id: UUID { entry.id }
  let entry: DiaryEntry
  let analysis: DiaryAnalysis
  let feedback: Feedback

  var chosenOptionTitle: String {
    guard let chosenOptionIndex = feedback.chosenOptionIndex else {
      return "Not decided yet"
    }
    return entry.options.first { $0.index == chosenOptionIndex }?.title ?? "Option \(chosenOptionIndex)"
  }
}
