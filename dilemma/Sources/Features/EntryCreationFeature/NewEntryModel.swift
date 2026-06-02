import DecisionModels
import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class NewEntryModel {
  var command = EntryDraftCommand()
  var errorMessage: String?
  private(set) var isBusy = false

  @ObservationIgnored private let createAnalyzedEntry: CreateAnalyzedEntryUseCase
  @ObservationIgnored private let onCreated: @MainActor (DiarySnapshot) -> Void

  init(
    createAnalyzedEntry: CreateAnalyzedEntryUseCase,
    onCreated: @escaping @MainActor (DiarySnapshot) -> Void
  ) {
    self.createAnalyzedEntry = createAnalyzedEntry
    self.onCreated = onCreated
  }

  func analyze() async -> Bool {
    isBusy = true
    errorMessage = nil
    defer { isBusy = false }

    do {
      let snapshot = try await createAnalyzedEntry(command)
      onCreated(snapshot)
      return true
    } catch {
      errorMessage = AppErrorMessage.message(for: error, context: .analyzeEntry)
      return false
    }
  }
}
