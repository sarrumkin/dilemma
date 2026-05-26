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

    let exportData = try useCases.exportDiaryData()
    #expect(!exportData.isEmpty)

    try useCases.deleteDiaryData()
    try useCases.prepareDiary()
    let empty = try useCases.loadDiarySnapshot()
    #expect(empty.entries.isEmpty)
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
