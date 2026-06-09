import DecisionModels
import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class DiaryListModel {
  private(set) var entries: [DiaryEntry] = []
  private(set) var latestAnalyses: [UUID: DecisionAnalysis] = [:]
  private(set) var latestFeedback: [UUID: Feedback] = [:]
  var errorMessage: String?

  @ObservationIgnored private let loadDiarySnapshot: LoadDiarySnapshotUseCase
  @ObservationIgnored private let deleteDiaryEntry: DeleteDiaryEntryUseCase

  init(
    loadDiarySnapshot: LoadDiarySnapshotUseCase,
    deleteDiaryEntry: DeleteDiaryEntryUseCase
  ) {
    self.loadDiarySnapshot = loadDiarySnapshot
    self.deleteDiaryEntry = deleteDiaryEntry
  }

  func reload() {
    do {
      apply(try loadDiarySnapshot())
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .loadDiary)
    }
  }

  func apply(_ snapshot: DiarySnapshot) {
    entries = snapshot.entries
    latestAnalyses = snapshot.latestAnalyses
    latestFeedback = snapshot.latestFeedback
    errorMessage = nil
  }

  func latestAnalysis(for entry: DiaryEntry) -> DecisionAnalysis? {
    latestAnalyses[entry.id]
  }

  func latestFeedback(for entry: DiaryEntry) -> Feedback? {
    latestFeedback[entry.id]
  }

  func delete(_ entry: DiaryEntry) -> Bool {
    do {
      apply(try deleteDiaryEntry(id: entry.id))
      return true
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .deleteEntry)
      return false
    }
  }
}
