import Foundation
import Testing

@testable import DecisionModels
@testable import DecisionUseCases
import DiaryVault

@Suite
struct DecisionUseCasesTests {
  @Test
  func diaryRoundTripUsesSharedVaultAndDTOs() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    let useCases = DecisionUseCases.testing(
      vault: vault,
      analysisGenerator: StubAnalysisGenerator()
    )

    try useCases.prepareDiary()
    let command = EntryDraftCommand.sample()
    #expect(command.isValid)

    let created = try await useCases.createAnalyzedEntry(command)
    #expect(created.entries.count == 1)
    let entry = try #require(created.entries.first)
    #expect(entry.rawText == command.rawText)
    #expect(entry.options.count == 2)
    #expect(entry.options.flatMap(\.reasons).count == 12)

    let analysis = try #require(created.latestAnalyses[entry.id])
    #expect(analysis.modelID == "stub-model")
    #expect(analysis.attributeConflicts.first?.attributeName == "money")

    try useCases.saveFeedback(
      FeedbackCommand(
        entryID: entry.id,
        analysisID: analysis.id,
        conflictWasUseful: true,
        correctedClusterID: 4,
        chosenOptionIndex: 1,
        note: " Useful framing. "
      )
    )

    let statistics = try useCases.loadPreferenceStatistics()
    #expect(statistics.entryCount == 1)
    #expect(statistics.feedbackCount == 1)
    #expect(statistics.acceptedConflictCount == 1)
    #expect(statistics.chosenOptionCounts[1] == 1)
    #expect(statistics.chosenClusterDilemmaCount == 1)

    let exportData = try useCases.exportDiaryData()
    #expect(!exportData.isEmpty)

    try useCases.deleteDiaryData()
    try useCases.prepareDiary()
    let empty = try useCases.loadDiarySnapshot()
    #expect(empty.entries.isEmpty)
  }

  @Test
  func savingFeedbackUpdatesExistingDecisionAndAllowsNoDecision() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    let useCases = DecisionUseCases.testing(
      vault: vault,
      analysisGenerator: StubAnalysisGenerator()
    )

    try useCases.prepareDiary()
    let created = try await useCases.createAnalyzedEntry(.sample())
    let entry = try #require(created.entries.first)
    let analysis = try #require(created.latestAnalyses[entry.id])

    try useCases.saveFeedback(
      FeedbackCommand(
        entryID: entry.id,
        analysisID: analysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: 1,
        note: "First"
      )
    )
    try useCases.saveFeedback(
      FeedbackCommand(
        entryID: entry.id,
        analysisID: analysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: 2,
        note: "Changed"
      )
    )

    var savedFeedbackResult = try useCases.loadFeedbackForAnalysis(
      entryID: entry.id,
      analysisID: analysis.id
    )
    var savedFeedback = try #require(savedFeedbackResult)
    #expect(savedFeedback.chosenOptionIndex == 2)
    #expect(savedFeedback.note == "Changed")
    var statistics = try useCases.loadPreferenceStatistics()
    #expect(statistics.feedbackCount == 1)
    #expect(statistics.chosenOptionCounts == [2: 1])
    #expect(statistics.chosenClusterDilemmaCount == 1)

    try useCases.saveFeedback(
      FeedbackCommand(
        entryID: entry.id,
        analysisID: analysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: nil,
        note: "No final decision"
      )
    )

    savedFeedbackResult = try useCases.loadFeedbackForAnalysis(
      entryID: entry.id,
      analysisID: analysis.id
    )
    savedFeedback = try #require(savedFeedbackResult)
    #expect(savedFeedback.chosenOptionIndex == nil)
    #expect(savedFeedback.note == "No final decision")
    statistics = try useCases.loadPreferenceStatistics()
    #expect(statistics.feedbackCount == 1)
    #expect(statistics.chosenOptionCounts.isEmpty)
    #expect(statistics.chosenClusterDilemmaCount == 0)
  }

  @Test
  func exportSingleDilemmaAsDraftJSON() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    let useCases = DecisionUseCases.testing(
      vault: vault,
      analysisGenerator: StubAnalysisGenerator()
    )
    try useCases.prepareDiary()
    let command = EntryDraftCommand.sample()

    let created = try await useCases.createAnalyzedEntry(command)
    let entry = try #require(created.entries.first)
    let exportData = try useCases.exportDilemmaDraft(entry: entry)
    let decoded = try JSONDecoder().decode(DilemmaDraftJSON.self, from: exportData)
    let decodedCommand = try decoded.makeEntryDraftCommand()

    #expect(decoded.schemaVersion == 1)
    #expect(decodedCommand.rawText == command.rawText)
    #expect(decodedCommand.option1Benefits == command.option1Benefits)
    #expect(decodedCommand.option2Costs == command.option2Costs)
  }

  @Test
  func deleteSingleDilemmaReturnsSnapshotWithoutDeletedAnalysis() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    let useCases = DecisionUseCases.testing(
      vault: vault,
      analysisGenerator: StubAnalysisGenerator()
    )
    try useCases.prepareDiary()

    let first = try await useCases.createAnalyzedEntry(.sample())
    let deletedEntry = try #require(first.entries.first)
    let deletedAnalysis = try #require(first.latestAnalyses[deletedEntry.id])
    var secondCommand = EntryDraftCommand.sample()
    secondCommand.rawText = "Should I keep this dilemma?"
    let second = try await useCases.createAnalyzedEntry(secondCommand)
    let keptEntry = try #require(second.entries.first(where: { $0.id != deletedEntry.id }))

    try useCases.saveFeedback(
      FeedbackCommand(
        entryID: deletedEntry.id,
        analysisID: deletedAnalysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: 1
      )
    )

    let snapshot = try useCases.deleteDiaryEntry(id: deletedEntry.id)

    #expect(snapshot.entries.map(\.id) == [keptEntry.id])
    #expect(snapshot.latestAnalyses[deletedEntry.id] == nil)
    #expect(snapshot.latestAnalyses[keptEntry.id] != nil)
    let statistics = try useCases.loadPreferenceStatistics()
    #expect(statistics.entryCount == 1)
    #expect(statistics.feedbackCount == 0)
  }

  @Test
  func importDilemmaDraftArrayAnalyzesEveryItem() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    let useCases = DecisionUseCases.testing(
      vault: vault,
      analysisGenerator: StubAnalysisGenerator()
    )
    try useCases.prepareDiary()

    var second = EntryDraftCommand.sample()
    second.rawText = "Should I move cities?"
    second.option1Title = "Stay nearby"
    second.option2Title = "Move"
    let payload = [
      DilemmaDraftJSON(command: .sample()),
      DilemmaDraftJSON(command: second),
    ]
    let jsonData = try JSONEncoder().encode(payload)
    let progressRecorder = ProgressRecorder()

    let result = try await useCases.importDilemmaDrafts(jsonData: jsonData) { progress in
      await progressRecorder.append(progress)
    }
    let progressEvents = await progressRecorder.events

    #expect(result.importedCount == 2)
    #expect(progressEvents == [
      DilemmaDraftImportProgress(completedCount: 0, totalCount: 2),
      DilemmaDraftImportProgress(completedCount: 1, totalCount: 2),
      DilemmaDraftImportProgress(completedCount: 2, totalCount: 2),
    ])
    #expect(result.snapshot.entries.count == 2)
    #expect(result.snapshot.latestAnalyses.count == 2)
    #expect(result.snapshot.entries.allSatisfy { entry in
      entry.options.count == 2 && entry.options.flatMap(\.reasons).count == 12
    })
    #expect(result.snapshot.latestAnalyses.values.allSatisfy { analysis in
      analysis.attributeConflicts.count == 1 && analysis.clusterProfiles.count == 2
    })
    #expect(Set(result.snapshot.entries.map(\.rawText)) == Set([
      "Should I stay or leave?",
      "Should I move cities?",
    ]))
  }

  @Test
  func importDilemmaDraftBlocksAnalyzesEveryNestedItem() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    let useCases = DecisionUseCases.testing(
      vault: vault,
      analysisGenerator: StubAnalysisGenerator()
    )
    try useCases.prepareDiary()

    var second = EntryDraftCommand.sample()
    second.rawText = "Should I fund the project or keep savings?"
    second.option1Title = "Fund the project"
    second.option2Title = "Keep savings"
    let jsonData = """
    [
      {
        "schemaVersion": 1,
        "id": "growth_vs_security",
        "title": "Growth vs security",
        "comment": "A block-level note for humans.",
        "intent": "Import should ignore block metadata and import nested dilemmas.",
        "dilemmas": [
          \(String(data: try JSONEncoder().encode(DilemmaDraftJSON(command: .sample())), encoding: .utf8)!),
          \(String(data: try JSONEncoder().encode(DilemmaDraftJSON(command: second)), encoding: .utf8)!)
        ]
      }
    ]
    """.data(using: .utf8)!

    let result = try await useCases.importDilemmaDrafts(jsonData: jsonData)

    #expect(result.importedCount == 2)
    #expect(result.snapshot.entries.count == 2)
    #expect(Set(result.snapshot.entries.map(\.rawText)) == Set([
      "Should I stay or leave?",
      "Should I fund the project or keep savings?",
    ]))
  }

  @Test
  func importDilemmaDraftArrayValidatesBeforeSavingAnything() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    let useCases = DecisionUseCases.testing(
      vault: vault,
      analysisGenerator: StubAnalysisGenerator()
    )
    try useCases.prepareDiary()

    let invalid = DilemmaDraftJSON(
      rawText: "Should I choose the invalid option?",
      options: [
        DilemmaDraftOptionJSON(
          title: "One",
          benefits: ["A", "B", "C"],
          costs: ["Only one cost"]
        ),
        DilemmaDraftOptionJSON(
          title: "Two",
          benefits: ["A", "B", "C"],
          costs: ["A", "B", "C"]
        ),
      ]
    )
    let jsonData = try JSONEncoder().encode([
      DilemmaDraftJSON(command: .sample()),
      invalid,
    ])

    do {
      _ = try await useCases.importDilemmaDrafts(jsonData: jsonData)
      Issue.record("Expected batch import validation error.")
    } catch let error as DilemmaDraftImportError {
      #expect(error == .invalidItem(
        index: 2,
        reason: DilemmaDraftJSONValidationError.notEnoughReasons(
          optionIndex: 1,
          polarity: .cost,
          expected: 3,
          actual: 1
        ).localizedDescription
      ))
    } catch {
      Issue.record("Unexpected error: \(error)")
    }

    let snapshot = try useCases.loadDiarySnapshot()
    #expect(snapshot.entries.isEmpty)
    #expect(snapshot.latestAnalyses.isEmpty)
  }
}

private actor ProgressRecorder {
  private(set) var events: [DilemmaDraftImportProgress] = []

  func append(_ progress: DilemmaDraftImportProgress) {
    events.append(progress)
  }
}

private struct StubAnalysisGenerator: EntryAnalysisGenerating {
  func analysis(for command: EntryDraftCommand, entryID: UUID) async throws -> DiaryAnalysis {
    DiaryAnalysis(
      entryID: entryID,
      assetVersion: 1,
      modelID: "stub-model",
      sourceDOI: "stub-doi",
      attributeConflicts: [
        AttributeConflict(
          attributeName: "money",
          option1Score: 0.8,
          option2Score: -0.1,
          difference: 0.9,
          rank: 1
        ),
      ],
      clusterProfiles: [
        ClusterProfile(optionIndex: 1, clusterID: 4, label: "Cluster 4: money", score: 0.7),
        ClusterProfile(optionIndex: 2, clusterID: 10, label: "Cluster 10: career", score: 0.5),
      ]
    )
  }
}

private struct EphemeralKeyProvider: DatabaseKeyProvider {
  func databaseKey() throws -> Data {
    Data(repeating: 9, count: 32)
  }

  func deleteDatabaseKey() throws {}
}
