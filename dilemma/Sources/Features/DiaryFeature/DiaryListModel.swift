import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class DiaryListModel {
  private(set) var entries: [DiaryEntrySnapshot] = []
  private(set) var latestAnalyses: [UUID: AnalysisSnapshot] = [:]
  var errorMessage: String?

  @ObservationIgnored private let loadDiarySnapshot: LoadDiarySnapshotUseCase

  init(loadDiarySnapshot: LoadDiarySnapshotUseCase) {
    self.loadDiarySnapshot = loadDiarySnapshot
  }

  func reload() {
    do {
      apply(try loadDiarySnapshot())
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func apply(_ snapshot: DiarySnapshot) {
    entries = snapshot.entries
    latestAnalyses = snapshot.latestAnalyses
    errorMessage = nil
  }

  func latestAnalysis(for entry: DiaryEntrySnapshot) -> AnalysisSnapshot? {
    latestAnalyses[entry.id]
  }
}
