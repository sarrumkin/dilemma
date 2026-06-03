import DecisionUseCases
import Foundation
import Observation

@MainActor
@Observable
final class DilemmaJSONImportModel {
  var jsonText = ""
  var errorMessage: String?
  private(set) var isBusy = false
  private(set) var importProgress: DilemmaDraftImportProgress?

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
      errorMessage = AppLocalization.string("Paste a JSON array to import.")
      return false
    }

    isBusy = true
    errorMessage = nil
    importProgress = nil
    defer {
      isBusy = false
      importProgress = nil
    }

    do {
      let result = try await importDilemmaDrafts(jsonData: data) { [weak self] progress in
        await self?.setImportProgress(progress)
      }
      onImported(result)
      return true
    } catch {
      errorMessage = importErrorMessage(error)
      return false
    }
  }

  func importDrafts(from url: URL) async -> Bool {
    isBusy = true
    errorMessage = nil
    importProgress = nil
    defer {
      isBusy = false
      importProgress = nil
    }

    let hasSecurityScope = url.startAccessingSecurityScopedResource()
    defer {
      if hasSecurityScope {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let data = try Data(contentsOf: url)
      let result = try await importDilemmaDrafts(jsonData: data) { [weak self] progress in
        await self?.setImportProgress(progress)
      }
      onImported(result)
      return true
    } catch {
      errorMessage = importErrorMessage(error)
      return false
    }
  }

  private func importErrorMessage(_ error: Error) -> String {
    let summary = AppErrorMessage.message(for: error, context: .importJSON)
    let details = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !details.isEmpty, details != summary else {
      return summary
    }
    return "\(summary)\n\(details)"
  }

  private func setImportProgress(_ progress: DilemmaDraftImportProgress) {
    importProgress = progress
  }
}
