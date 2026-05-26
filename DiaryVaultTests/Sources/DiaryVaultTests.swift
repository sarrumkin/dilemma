import Foundation
import Testing

import DecisionModels
@testable import DiaryVault

@Suite
struct DiaryVaultTests {
  @Test
  func saveLoadExportAndDeleteRoundTrip() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    try vault.prepare()

    let entry = sampleEntry()
    try vault.saveEntry(entry)
    let loaded = try vault.entry(id: entry.id)

    #expect(loaded.rawText == entry.rawText)
    #expect(loaded.options.count == 2)
    #expect(loaded.options.flatMap(\.reasons).count == 12)

    let analysis = DiaryAnalysis(
      entryID: entry.id,
      assetVersion: 1,
      modelID: "sentence-transformers/all-MiniLM-L12-v2",
      sourceDOI: "10.1073/pnas.2406489122",
      attributeConflicts: [
        AttributeConflict(
          attributeName: "money",
          option1Score: 0.8,
          option2Score: -0.2,
          difference: 1.0,
          rank: 1
        ),
      ],
      clusterProfiles: [
        ClusterProfile(optionIndex: 1, clusterID: 4, label: "Cluster 4: money", score: 0.7),
        ClusterProfile(optionIndex: 2, clusterID: 10, label: "Cluster 10: career", score: 0.6),
      ]
    )
    try vault.saveAnalysis(analysis)

    let feedback = Feedback(
      entryID: entry.id,
      analysisID: analysis.id,
      conflictWasUseful: true,
      correctedClusterID: 4,
      chosenOptionIndex: 1,
      note: "Useful framing."
    )
    try vault.saveFeedback(feedback)

    let statistics = try vault.statistics()
    #expect(statistics.entryCount == 1)
    #expect(statistics.feedbackCount == 1)
    #expect(statistics.acceptedConflictCount == 1)
    #expect(statistics.mostFrequentClusters.count == 2)
    #expect(statistics.chosenOptionCounts[1] == 1)

    let export = try vault.exportData()
    #expect(export.schemaVersion == 1)
    #expect(export.entries.count == 1)
    #expect(export.analyses.count == 1)
    #expect(export.feedback.count == 1)
    let exportData = try vault.exportJSONData()
    #expect(!exportData.isEmpty)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decodedExport = try decoder.decode(DiaryExport.self, from: exportData)
    #expect(decodedExport.schemaVersion == 1)
    #expect(decodedExport.entries.first?.options.flatMap(\.reasons).count ?? 0 == 12)

    try vault.deleteAllData()
    #expect(!FileManager.default.fileExists(atPath: url.path))
    try vault.prepare()
    #expect(try vault.entries().isEmpty)
  }

  private func sampleEntry() -> DiaryEntry {
    DiaryEntry(
      rawText: "Should I stay or leave?",
      options: [
        DiaryOption(
          index: 1,
          title: "Stay",
          reasons: [
            DiaryReason(text: "Stable income", polarity: .benefit),
            DiaryReason(text: "Close to family", polarity: .benefit),
            DiaryReason(text: "Lower risk", polarity: .benefit),
            DiaryReason(text: "Less growth", polarity: .cost),
            DiaryReason(text: "Boredom", polarity: .cost),
            DiaryReason(text: "Missed opportunity", polarity: .cost),
          ]
        ),
        DiaryOption(
          index: 2,
          title: "Leave",
          reasons: [
            DiaryReason(text: "Career growth", polarity: .benefit),
            DiaryReason(text: "New skills", polarity: .benefit),
            DiaryReason(text: "Independence", polarity: .benefit),
            DiaryReason(text: "Financial risk", polarity: .cost),
            DiaryReason(text: "Stress", polarity: .cost),
            DiaryReason(text: "Less family time", polarity: .cost),
          ]
        ),
      ]
    )
  }
}

private struct EphemeralKeyProvider: DatabaseKeyProvider {
  func databaseKey() throws -> Data {
    Data(repeating: 7, count: 32)
  }

  func deleteDatabaseKey() throws {}
}
