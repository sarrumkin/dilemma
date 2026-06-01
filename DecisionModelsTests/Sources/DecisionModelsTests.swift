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
}
