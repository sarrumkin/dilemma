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
      databaseURL: url
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
    #expect(analysis.embeddings.rawText == command.rawText)
    #expect(analysis.embeddings.dilemmaText.modelName == "Stub Model")
    #expect(analysis.embeddings.options.map(\.title) == [command.option1Title, command.option2Title])
    #expect(analysis.embeddings.reasons.count == 12)

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
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decodedExport = try decoder.decode(DiaryExport.self, from: exportData)
    let exportedAnalysis = try #require(decodedExport.analyses.first)
    #expect(exportedAnalysis.embeddings == analysis.embeddings)

    try useCases.deleteDiaryData()
    try useCases.prepareDiary()
    let empty = try useCases.loadDiarySnapshot()
    #expect(empty.entries.isEmpty)
  }

  @Test
  func savingFeedbackUpdatesExistingDecisionAndDeletesWhenCleared() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url
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
        chosenOptionIndex: nil,
        note: "No decision yet"
      )
    )
    #expect(try useCases.loadFeedbackForAnalysis(entryID: entry.id, analysisID: analysis.id) == nil)

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
    #expect(savedFeedbackResult == nil)
    statistics = try useCases.loadPreferenceStatistics()
    #expect(statistics.feedbackCount == 0)
    #expect(statistics.chosenOptionCounts.isEmpty)
    #expect(statistics.chosenClusterDilemmaCount == 0)
  }

  @Test
  func reanalyzeIncompleteAnalysesMigratesLegacyProjectionRows() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url
    )
    let useCases = DecisionUseCases.testing(
      vault: vault,
      analysisGenerator: StubAnalysisGenerator()
    )

    try useCases.prepareDiary()
    let command = EntryDraftCommand.sample()
    let created = try await useCases.createAnalyzedEntry(command)
    let entry = try #require(created.entries.first)
    let analysis = try #require(created.latestAnalyses[entry.id])
    try vault.saveAnalysis(analysis.legacyStoredModel())

    let legacySnapshot = try useCases.loadDiarySnapshot()
    let legacyAnalysis = try #require(legacySnapshot.latestAnalyses[entry.id])
    #expect(legacyAnalysis.id == analysis.id)
    #expect(legacyAnalysis.embeddings.reasons.isEmpty)

    let progressRecorder = ReanalysisProgressRecorder()
    let result = try await useCases.reanalyzeIncompleteAnalyses { progress in
      await progressRecorder.append(progress)
    }
    let progressEvents = await progressRecorder.events

    #expect(result.updatedCount == 1)
    #expect(result.failedCount == 0)
    #expect(progressEvents == [
      ReanalyzeIncompleteAnalysesProgress(totalCount: 1, completedCount: 0, isRunning: true),
      ReanalyzeIncompleteAnalysesProgress(
        totalCount: 1,
        completedCount: 0,
        currentEntryID: entry.id,
        isRunning: true
      ),
      ReanalyzeIncompleteAnalysesProgress(totalCount: 1, completedCount: 1, isRunning: false),
    ])
    let migratedAnalysis = try #require(result.snapshot.latestAnalyses[entry.id])
    #expect(migratedAnalysis.id == analysis.id)
    #expect(migratedAnalysis.embeddings.rawText == command.rawText)
    #expect(migratedAnalysis.embeddings.reasons.count == 12)

    let reloaded = try useCases.loadDiarySnapshot()
    #expect(reloaded.latestAnalyses[entry.id]?.embeddings.reasons.count == 12)
  }

  @Test
  func exportSingleDilemmaAsDraftJSON() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url
    )
    let useCases = DecisionUseCases.testing(
      vault: vault,
      analysisGenerator: StubAnalysisGenerator()
    )
    try useCases.prepareDiary()
    let command = EntryDraftCommand.sample()

    let created = try await useCases.createAnalyzedEntry(command)
    let entry = try #require(created.entries.first)
    let analysis = try #require(created.latestAnalyses[entry.id])
    let exportData = try useCases.exportDilemmaDraft(entry: entry, analysis: analysis)
    let decoded = try JSONDecoder().decode(DilemmaDraftJSON.self, from: exportData)
    let decodedCommand = try decoded.makeEntryDraftCommand()

    #expect(decoded.schemaVersion == 1)
    #expect(decodedCommand.rawText == command.rawText)
    #expect(decodedCommand.option1Benefits == command.option1Benefits)
    #expect(decodedCommand.option2Costs == command.option2Costs)
    #expect(decoded.analysis == analysis)
  }

  @Test
  func deleteSingleDilemmaReturnsSnapshotWithoutDeletedAnalysis() async throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url
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
      databaseURL: url
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
      databaseURL: url
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
      databaseURL: url
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

private actor ReanalysisProgressRecorder {
  private(set) var events: [ReanalyzeIncompleteAnalysesProgress] = []

  func append(_ progress: ReanalyzeIncompleteAnalysesProgress) {
    events.append(progress)
  }
}

private extension DecisionAnalysis {
  func legacyStoredModel() -> StoredDecisionAnalysis {
    StoredDecisionAnalysis(
      id: id,
      entryID: entryID,
      createdAt: createdAt,
      assetVersion: assetVersion,
      modelID: modelID,
      sourceDOI: sourceDOI,
      attributeConflicts: attributeConflicts.map {
        StoredAttributeConflict(
          id: $0.id,
          attributeName: $0.attributeName,
          option1Score: $0.option1Score,
          option2Score: $0.option2Score,
          difference: $0.difference,
          rank: $0.rank
        )
      },
      clusterProfiles: clusterProfiles.map {
        StoredClusterProfile(
          id: $0.id,
          optionIndex: $0.optionIndex,
          clusterID: $0.clusterID,
          label: $0.label,
          score: $0.score
        )
      }
    )
  }
}

private struct StubAnalysisGenerator: EntryAnalysisGenerating {
  func analysis(for command: EntryDraftCommand, entryID: UUID) async throws -> DecisionAnalysis {
    let option1Reasons = command.option1Benefits.map { ($0, ReasonPolarity.benefit) }
      + command.option1Costs.map { ($0, ReasonPolarity.cost) }
    let option2Reasons = command.option2Benefits.map { ($0, ReasonPolarity.benefit) }
      + command.option2Costs.map { ($0, ReasonPolarity.cost) }
    let reasonInputs = option1Reasons.map {
      ReasonInput(text: $0.0, optionIndex: 1, polarity: $0.1)
    } + option2Reasons.map {
      ReasonInput(text: $0.0, optionIndex: 2, polarity: $0.1)
    }
    let moneyAttribute = AttributeDefinition(
      attributeID: 1,
      name: "money",
      source: "stub",
      clusterID: 4
    )

    return DecisionAnalysis(
      entryID: entryID,
      model: AnalysisModelMetadata(id: "stub-model", name: "Stub Model", embeddingDimension: 3),
      asset: AnalysisAssetMetadata(version: 1, resourceName: "stub-assets", sourceDOI: "stub-doi"),
      clusterMethod: AnalysisClusterMethodMetadata(id: "stub-cluster-method", label: "Stub clusters"),
      embeddings: DecisionAnalysisEmbeddings(
        rawText: command.rawText,
        dilemmaText: embedding(values: [1, 0, 0]),
        options: [
          OptionEmbedding(optionIndex: 1, title: command.option1Title, embedding: embedding(values: [0, 1, 0])),
          OptionEmbedding(optionIndex: 2, title: command.option2Title, embedding: embedding(values: [0, 0, 1])),
        ],
        reasons: [1, 2].flatMap { optionIndex in
          reasonInputs
            .filter { $0.optionIndex == optionIndex }
            .enumerated()
            .map { offset, reason in
              ReasonEmbedding(
                reasonID: reason.id,
                optionIndex: reason.optionIndex,
                polarity: reason.polarity,
                text: reason.text,
                embedding: embedding(values: [Float(optionIndex), Float(offset + 1), 1])
              )
            }
        }
      ),
      reasonMatches: [],
      optionAttributeProfiles: [
        OptionAttributeProfile(
          optionIndex: 1,
          scores: [AttributeProfileScore(attribute: moneyAttribute, score: 0.8)]
        ),
        OptionAttributeProfile(
          optionIndex: 2,
          scores: [AttributeProfileScore(attribute: moneyAttribute, score: -0.1)]
        ),
      ],
      optionClusterProfiles: [
        OptionClusterProfile(
          optionIndex: 1,
          scores: [
            ClusterScore(
              cluster: ClusterMetadata(
                clusterID: 4,
                label: "Cluster 4: money",
                representativeAttributeName: "money",
                sortOrder: 4
              ),
              score: 0.7
            ),
          ]
        ),
        OptionClusterProfile(
          optionIndex: 2,
          scores: [
            ClusterScore(
              cluster: ClusterMetadata(
                clusterID: 10,
                label: "Cluster 10: career",
                representativeAttributeName: "career",
                sortOrder: 10
              ),
              score: 0.5
            ),
          ]
        ),
      ],
      metrics: AnalysisMetrics(),
      warnings: []
    )
  }

  private func embedding(values: [Float]) -> EmbeddingVector {
    EmbeddingVector(
      modelID: "stub-model",
      modelName: "Stub Model",
      dimension: values.count,
      values: values
    )
  }
}
