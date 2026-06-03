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
    #expect(statistics.mostFrequentClusters == [
      ClusterFrequency(clusterID: 4, label: "Cluster 4: money", count: 1),
    ])
    #expect(statistics.chosenOptionCounts[1] == 1)
    #expect(statistics.chosenClusterDilemmaCount == 1)

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

  @Test
  func deleteEntryRemovesItFromAnalysisStatisticsAndExport() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    try vault.prepare()

    let deletedEntry = sampleEntry(rawText: "Should I delete this dilemma?")
    let keptEntry = sampleEntry(rawText: "Should this dilemma remain?")
    try vault.saveEntry(deletedEntry)
    try vault.saveEntry(keptEntry)

    let deletedAnalysis = sampleAnalysis(
      entryID: deletedEntry.id,
      clusterID: 4,
      label: "Cluster 4: money"
    )
    let keptAnalysis = sampleAnalysis(
      entryID: keptEntry.id,
      clusterID: 10,
      label: "Cluster 10: career"
    )
    try vault.saveAnalysis(deletedAnalysis)
    try vault.saveAnalysis(keptAnalysis)
    try vault.saveFeedback(
      Feedback(
        entryID: deletedEntry.id,
        analysisID: deletedAnalysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: 1
      )
    )
    try vault.saveFeedback(
      Feedback(
        entryID: keptEntry.id,
        analysisID: keptAnalysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: 1
      )
    )

    try vault.deleteEntry(id: deletedEntry.id)

    do {
      _ = try vault.entry(id: deletedEntry.id)
      Issue.record("Expected deleted entry lookup to fail.")
    } catch let error as DiaryVaultError {
      #expect(error == .notFound)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
    #expect(try vault.entries().map(\.id) == [keptEntry.id])
    #expect(try vault.analyses(entryID: deletedEntry.id).isEmpty)
    #expect(try vault.feedback(entryID: deletedEntry.id).isEmpty)

    let statistics = try vault.statistics()
    #expect(statistics.entryCount == 1)
    #expect(statistics.feedbackCount == 1)
    #expect(statistics.chosenClusterDilemmaCount == 1)
    #expect(statistics.mostFrequentClusters == [
      ClusterFrequency(clusterID: 10, label: "Cluster 10: career", count: 1),
    ])

    let export = try vault.exportData()
    #expect(export.entries.map(\.id) == [keptEntry.id])
    #expect(export.analyses.map(\.entryID) == [keptEntry.id])
    #expect(export.feedback.map(\.entryID) == [keptEntry.id])
  }

  @Test
  func snapshotLoadsLargeDiaryWithLatestAnalyses() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url,
      keyProvider: EphemeralKeyProvider(),
      authenticator: NoOpVaultAuthenticator()
    )
    try vault.prepare()

    let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
    let entries = try (0..<120).map { index in
      let entry = sampleEntry(
        rawText: "Dilemma \(index)",
        createdAt: baseDate,
        updatedAt: baseDate.addingTimeInterval(TimeInterval(index))
      )
      try vault.saveEntry(entry)
      try vault.saveAnalysis(
        sampleAnalysis(
          entryID: entry.id,
          clusterID: 10 + index,
          label: "Old \(index)",
          createdAt: baseDate.addingTimeInterval(TimeInterval(index) - 1_000)
        )
      )
      try vault.saveAnalysis(
        sampleAnalysis(
          entryID: entry.id,
          clusterID: 1_000 + index,
          label: "Latest \(index)",
          createdAt: baseDate.addingTimeInterval(TimeInterval(index))
        )
      )
      return entry
    }

    let snapshot = try vault.snapshot()
    let expectedEntryIDs = entries
      .sorted { $0.updatedAt > $1.updatedAt }
      .map(\.id)

    #expect(snapshot.entries.map(\.id) == expectedEntryIDs)
    #expect(snapshot.entries.count == 120)
    #expect(snapshot.latestAnalyses.count == 120)
    #expect(snapshot.entries.allSatisfy { entry in
      entry.options.count == 2 && entry.options.flatMap(\.reasons).count == 12
    })
    for (index, entry) in entries.enumerated() {
      let latestAnalysis = try #require(snapshot.latestAnalyses[entry.id])
      #expect(latestAnalysis.attributeConflicts.first?.attributeName == "Latest \(index)")
      #expect(latestAnalysis.clusterProfiles.first?.clusterID == 1_000 + index)
    }
  }

  private func sampleEntry(
    rawText: String = "Should I stay or leave?",
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> DiaryEntry {
    DiaryEntry(
      rawText: rawText,
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
      ],
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  private func sampleAnalysis(
    entryID: UUID,
    clusterID: Int,
    label: String,
    createdAt: Date = Date()
  ) -> DiaryAnalysis {
    DiaryAnalysis(
      entryID: entryID,
      createdAt: createdAt,
      assetVersion: 1,
      modelID: "sentence-transformers/all-MiniLM-L12-v2",
      sourceDOI: "10.1073/pnas.2406489122",
      attributeConflicts: [
        AttributeConflict(
          attributeName: label,
          option1Score: 0.8,
          option2Score: -0.2,
          difference: 1.0,
          rank: 1
        ),
      ],
      clusterProfiles: [
        ClusterProfile(optionIndex: 1, clusterID: clusterID, label: label, score: 0.7),
        ClusterProfile(optionIndex: 2, clusterID: clusterID + 100, label: "Other \(clusterID)", score: 0.1),
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
