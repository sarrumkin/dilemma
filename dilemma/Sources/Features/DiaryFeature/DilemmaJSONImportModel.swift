import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class DilemmaJSONImportModel {
  var jsonText = ""
  var errorMessage: String?
  private(set) var isBusy = false

  var canImport: Bool {
    !jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
  }

  @ObservationIgnored private let importDilemmaDrafts: ImportDilemmaDraftsUseCase
  @ObservationIgnored private let onImported: @MainActor (DilemmaDraftImportResult) -> Void

  init(
    importDilemmaDrafts: ImportDilemmaDraftsUseCase,
    onImported: @escaping @MainActor (DilemmaDraftImportResult) -> Void
  ) {
    self.importDilemmaDrafts = importDilemmaDrafts
    self.onImported = onImported
  }

  func importDrafts() async -> Bool {
    let trimmedJSON = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedJSON.isEmpty, let data = trimmedJSON.data(using: .utf8) else {
      errorMessage = "Paste a JSON array to import."
      return false
    }

    isBusy = true
    errorMessage = nil
    defer { isBusy = false }

    do {
      let result = try await importDilemmaDrafts(jsonData: data)
      onImported(result)
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }
}
