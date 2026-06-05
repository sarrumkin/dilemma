import Foundation
import Testing

@testable import DecisionModels

@Suite
struct DecisionModelsTests {
  @Test
  func entryDraftRequiresCompleteStructuredInput() {
    var command = EntryDraftCommand.sample()
    #expect(command.isValid)

    command.option1Benefits = ["Only one benefit"]
    #expect(!command.isValid)

    command = .sample()
    command.option2Costs[1] = "   "
    #expect(!command.isValid)

    command = .sample()
    command.rawText = "\n"
    #expect(!command.isValid)
  }

  @Test
  func diaryExportCodableRoundTripPreservesPayload() throws {
    let entryID = UUID()
    let analysisID = UUID()
    let export = DiaryExport(
      schemaVersion: 1,
      exportedAt: Date(timeIntervalSince1970: 123),
      entries: [
        DiaryEntry(
          id: entryID,
          rawText: "Should I stay or leave?",
          options: [
            DiaryOption(
              index: 1,
              title: "Stay",
              reasons: [
                DiaryReason(text: "Stable income", polarity: .benefit),
                DiaryReason(text: "Less growth", polarity: .cost),
              ]
            ),
          ],
          createdAt: Date(timeIntervalSince1970: 100),
          updatedAt: Date(timeIntervalSince1970: 110)
        ),
      ],
      analyses: [
        DiaryAnalysis(
          id: analysisID,
          entryID: entryID,
          assetVersion: 1,
          modelID: "stub-model",
          sourceDOI: "stub-doi",
          attributeConflicts: [
            AttributeConflict(
              attributeName: "money",
              option1Score: 0.8,
              option2Score: -0.2,
              difference: 1.0,
              rank: 1
            ),
          ],
          attributeProfiles: [
            AttributeProfile(optionIndex: 1, attributeID: 7, attributeName: "money", score: 0.9),
          ],
          clusterProfiles: [
            ClusterProfile(optionIndex: 1, clusterID: 4, label: "Cluster 4: money", score: 0.7),
          ]
        ),
      ],
      feedback: [
        Feedback(
          entryID: entryID,
          analysisID: analysisID,
          conflictWasUseful: true,
          correctedClusterID: 4,
          chosenOptionIndex: 1,
          note: "Useful framing."
        ),
      ]
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(export)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(DiaryExport.self, from: data)

    #expect(decoded.schemaVersion == 1)
    #expect(decoded.entries.first?.id == entryID)
    #expect(decoded.entries.first?.options.first?.reasons.count == 2)
    #expect(decoded.analyses.first?.id == analysisID)
    #expect(decoded.analyses.first?.attributeProfiles.first?.attributeName == "money")
    #expect(decoded.feedback.first?.analysisID == analysisID)
  }

  @Test
  func diaryAnalysisDecodesLegacyPayloadWithoutAttributeProfiles() throws {
    let data = """
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "entryID": "00000000-0000-0000-0000-000000000002",
      "createdAt": "2026-01-01T00:00:00Z",
      "assetVersion": 1,
      "modelID": "stub-model",
      "sourceDOI": "stub-doi",
      "attributeConflicts": [],
      "clusterProfiles": []
    }
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let analysis = try decoder.decode(DiaryAnalysis.self, from: data)

    #expect(analysis.attributeProfiles.isEmpty)
  }

  @Test
  func dilemmaDraftJSONCodableAndCommandConversion() throws {
    var command = EntryDraftCommand.sample()
    command.option1Benefits.append("More predictability")
    #expect(command.isValid)

    let export = DilemmaDraftJSON(command: command)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(export)
    let decoded = try JSONDecoder().decode(DilemmaDraftJSON.self, from: data)
    let decodedCommand = try decoded.makeEntryDraftCommand()

    #expect(decoded.schemaVersion == 1)
    #expect(decodedCommand.rawText == command.rawText)
    #expect(decodedCommand.option1Benefits.count == 4)
    #expect(decodedCommand.option2Costs == command.option2Costs)
  }

  @Test
  func dilemmaDraftJSONAllowsMissingSchemaVersionAndTrimsPayload() throws {
    let data = """
    {
      "rawText": " Should I stay or leave? ",
      "options": [
        {
          "title": " Stay ",
          "benefits": [" Stable income ", "Close to family", "Lower risk", " "],
          "costs": ["Less growth", "Boredom", "Missed opportunity"]
        },
        {
          "title": "Leave",
          "benefits": ["Career growth", "New skills", "Independence"],
          "costs": ["Financial risk", "Stress", "Less family time"]
        }
      ]
    }
    """.data(using: .utf8)!

    let draft = try JSONDecoder().decode(DilemmaDraftJSON.self, from: data)
    let command = try draft.makeEntryDraftCommand()

    #expect(draft.schemaVersion == nil)
    #expect(command.rawText == "Should I stay or leave?")
    #expect(command.option1Title == "Stay")
    #expect(command.option1Benefits == ["Stable income", "Close to family", "Lower risk"])
  }

  @Test
  func dilemmaDraftJSONRejectsInvalidShape() throws {
    let unsupported = DilemmaDraftJSON(
      schemaVersion: 2,
      rawText: "Should I stay or leave?",
      options: [
        DilemmaDraftOptionJSON(
          title: "Stay",
          benefits: ["Stable income", "Close to family", "Lower risk"],
          costs: ["Less growth", "Boredom", "Missed opportunity"]
        ),
        DilemmaDraftOptionJSON(
          title: "Leave",
          benefits: ["Career growth", "New skills", "Independence"],
          costs: ["Financial risk", "Stress", "Less family time"]
        ),
      ]
    )
    do {
      try unsupported.makeEntryDraftCommand()
      Issue.record("Expected unsupported schema version error.")
    } catch let error as DilemmaDraftJSONValidationError {
      #expect(error == .unsupportedSchemaVersion(2))
    } catch {
      Issue.record("Unexpected error: \(error)")
    }

    let notEnoughReasons = DilemmaDraftJSON(
      rawText: "Should I stay or leave?",
      options: [
        DilemmaDraftOptionJSON(
          title: "Stay",
          benefits: ["Stable income", "Close to family", "Lower risk"],
          costs: ["Less growth", "Boredom"]
        ),
        DilemmaDraftOptionJSON(
          title: "Leave",
          benefits: ["Career growth", "New skills", "Independence"],
          costs: ["Financial risk", "Stress", "Less family time"]
        ),
      ]
    )
    do {
      try notEnoughReasons.makeEntryDraftCommand()
      Issue.record("Expected not enough reasons error.")
    } catch let error as DilemmaDraftJSONValidationError {
      #expect(error == .notEnoughReasons(
        optionIndex: 1,
        polarity: .cost,
        expected: 3,
        actual: 2
      ))
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test
  func dilemmaDraftJSONExportsDiaryEntryWithoutAnalysisPayload() throws {
    let entry = DiaryEntry(
      rawText: "Should I stay or leave?",
      options: [
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
      ]
    )

    let draft = try DilemmaDraftJSON(entry: entry)
    let command = try draft.makeEntryDraftCommand()

    #expect(draft.schemaVersion == 1)
    #expect(command.option1Title == "Stay")
    #expect(command.option2Title == "Leave")
    #expect(command.option2Costs == ["Financial risk", "Stress", "Less family time"])
  }

  @Test
  func clusterDilemmaStatisticsGroupsAnalyzedTopClustersWithoutFeedback() throws {
    let olderEntry = sampleEntry(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      rawText: "Older dilemma",
      updatedAt: Date(timeIntervalSince1970: 100)
    )
    let newerEntry = sampleEntry(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
      rawText: "Newer dilemma",
      updatedAt: Date(timeIntervalSince1970: 200)
    )
    let entryWithoutAnalysis = sampleEntry(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
      rawText: "Unanalyzed dilemma",
      updatedAt: Date(timeIntervalSince1970: 300)
    )

    let olderAnalysis = sampleAnalysis(
      entryID: olderEntry.id,
      clusterProfiles: [
        ClusterProfile(optionIndex: 1, clusterID: 1, label: "Shared", score: 0.5),
        ClusterProfile(optionIndex: 1, clusterID: 2, label: "Beta", score: 0.4),
        ClusterProfile(optionIndex: 1, clusterID: 3, label: "Gamma", score: 0.3),
        ClusterProfile(optionIndex: 1, clusterID: 4, label: "Not top positive", score: 0.2),
        ClusterProfile(optionIndex: 1, clusterID: 5, label: "Negative A", score: -0.6),
        ClusterProfile(optionIndex: 1, clusterID: 6, label: "Negative B", score: -0.5),
        ClusterProfile(optionIndex: 1, clusterID: 7, label: "Negative C", score: -0.4),
        ClusterProfile(optionIndex: 1, clusterID: 8, label: "Not top negative", score: -0.3),
        ClusterProfile(optionIndex: 2, clusterID: 1, label: "Shared", score: -0.7),
        ClusterProfile(optionIndex: 2, clusterID: 10, label: "Alpha Tie", score: 0.6),
        ClusterProfile(optionIndex: 2, clusterID: 11, label: "Delta", score: 0.5),
        ClusterProfile(optionIndex: 2, clusterID: 12, label: "Epsilon", score: 0.4),
      ]
    )
    let newerAnalysis = sampleAnalysis(
      entryID: newerEntry.id,
      clusterProfiles: [
        ClusterProfile(optionIndex: 1, clusterID: 20, label: "Omega", score: 0.9),
        ClusterProfile(optionIndex: 1, clusterID: 1, label: "Shared", score: 0.7),
        ClusterProfile(optionIndex: 1, clusterID: 21, label: "Zeta", score: 0.6),
        ClusterProfile(optionIndex: 1, clusterID: 22, label: "Eta", score: 0.5),
      ]
    )

    let statistics = ClusterDilemmaStatistics(snapshot: DiarySnapshot(
      entries: [olderEntry, newerEntry, entryWithoutAnalysis],
      latestAnalyses: [
        olderEntry.id: olderAnalysis,
        newerEntry.id: newerAnalysis,
      ]
    ))

    #expect(statistics.analyzedEntryCount == 2)
    #expect(statistics.groups.first?.clusterID == 1)
    #expect(!statistics.groups.contains { $0.clusterID == 4 })
    #expect(!statistics.groups.contains { $0.clusterID == 8 })

    let sharedGroup = try #require(statistics.groups.first { $0.clusterID == 1 })
    #expect(sharedGroup.count == 2)
    #expect(sharedGroup.records.map(\.entry.id) == [newerEntry.id, olderEntry.id])

    let olderSharedRecord = try #require(sharedGroup.records.first { $0.entry.id == olderEntry.id })
    #expect(olderSharedRecord.optionIndices == [1, 2])
    #expect(olderSharedRecord.strongestScore == -0.7)

    let alphaTieIndex = try #require(statistics.groups.firstIndex { $0.clusterID == 10 })
    let betaIndex = try #require(statistics.groups.firstIndex { $0.clusterID == 2 })
    #expect(alphaTieIndex < betaIndex)
  }

  private func sampleEntry(id: UUID, rawText: String, updatedAt: Date) -> DiaryEntry {
    DiaryEntry(
      id: id,
      rawText: rawText,
      options: [
        DiaryOption(
          index: 1,
          title: "Stay",
          reasons: [
            DiaryReason(text: "Stable income", polarity: .benefit),
            DiaryReason(text: "Less growth", polarity: .cost),
          ]
        ),
        DiaryOption(
          index: 2,
          title: "Leave",
          reasons: [
            DiaryReason(text: "Career growth", polarity: .benefit),
            DiaryReason(text: "Financial risk", polarity: .cost),
          ]
        ),
      ],
      createdAt: updatedAt,
      updatedAt: updatedAt
    )
  }

  private func sampleAnalysis(entryID: UUID, clusterProfiles: [ClusterProfile]) -> DiaryAnalysis {
    DiaryAnalysis(
      entryID: entryID,
      assetVersion: 1,
      modelID: "stub-model",
      sourceDOI: "stub-doi",
      attributeConflicts: [],
      clusterProfiles: clusterProfiles
    )
  }
}
