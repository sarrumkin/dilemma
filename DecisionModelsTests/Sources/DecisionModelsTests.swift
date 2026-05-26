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
    #expect(decoded.feedback.first?.analysisID == analysisID)
  }
}
