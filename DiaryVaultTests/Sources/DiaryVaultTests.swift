import Foundation
import Testing

@testable import DiaryVault

@Suite
struct DiaryVaultTests {
  @Test
  func saveLoadExportAndDeleteRoundTrip() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url
    )
    try vault.prepare()

    let entry = sampleEntry()
    try vault.saveEntry(entry)
    let loaded = try vault.entry(id: entry.id)

    #expect(loaded.rawText == entry.rawText)
    #expect(loaded.options.count == 2)
    #expect(loaded.options.flatMap(\.reasons).count == 12)

    let analysis = StoredDecisionAnalysis(
      entryID: entry.id,
      assetVersion: 1,
      modelID: "sentence-transformers/all-MiniLM-L12-v2",
      sourceDOI: "10.1073/pnas.2406489122",
      attributeConflicts: [
        StoredAttributeConflict(
          attributeName: "money",
          option1Score: 0.8,
          option2Score: -0.2,
          difference: 1.0,
          rank: 1
        ),
      ],
      clusterProfiles: [
        StoredClusterProfile(optionIndex: 1, clusterID: 4, label: "Cluster 4: money", score: 0.7),
        StoredClusterProfile(optionIndex: 2, clusterID: 10, label: "Cluster 10: career", score: 0.6),
      ]
    )
    try vault.saveAnalysis(analysis)

    let feedback = StoredFeedback(
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
      StoredClusterFrequency(clusterID: 4, label: "Cluster 4: money", count: 1),
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
    let decodedExport = try decoder.decode(StoredDiaryExport.self, from: exportData)
    #expect(decodedExport.schemaVersion == 1)
    #expect(decodedExport.entries.first?.options.flatMap(\.reasons).count ?? 0 == 12)

    try vault.deleteAllData()
    #expect(!FileManager.default.fileExists(atPath: url.path))
    try vault.prepare()
    #expect(try vault.entries().isEmpty)
  }

  @Test
  func saveFeedbackUpdatesExistingDecisionAndDeletesWhenCleared() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url
    )
    try vault.prepare()

    let entry = sampleEntry()
    let analysis = sampleAnalysis(
      entryID: entry.id,
      clusterID: 4,
      label: "Cluster 4: money"
    )
    try vault.saveEntry(entry)
    try vault.saveAnalysis(analysis)

    try vault.saveFeedback(
      StoredFeedback(
        entryID: entry.id,
        analysisID: analysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: nil,
        note: "No decision yet",
        createdAt: Date(timeIntervalSince1970: 0)
      )
    )
    #expect(try vault.feedback(entryID: entry.id, analysisID: analysis.id) == nil)
    #expect(try vault.feedback(entryID: entry.id).isEmpty)

    try vault.saveFeedback(
      StoredFeedback(
        entryID: entry.id,
        analysisID: analysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: 1,
        note: "First choice",
        createdAt: Date(timeIntervalSince1970: 1)
      )
    )
    try vault.saveFeedback(
      StoredFeedback(
        entryID: entry.id,
        analysisID: analysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: 2,
        note: "Changed choice",
        createdAt: Date(timeIntervalSince1970: 2)
      )
    )

    let changedFeedbackResult = try vault.feedback(entryID: entry.id, analysisID: analysis.id)
    let changedFeedback = try #require(changedFeedbackResult)
    #expect(try vault.feedback(entryID: entry.id).count == 1)
    #expect(changedFeedback.chosenOptionIndex == 2)
    #expect(changedFeedback.note == "Changed choice")

    var statistics = try vault.statistics()
    #expect(statistics.feedbackCount == 1)
    #expect(statistics.chosenOptionCounts == [2: 1])
    #expect(statistics.chosenClusterDilemmaCount == 1)
    #expect(statistics.mostFrequentClusters == [
      StoredClusterFrequency(clusterID: 104, label: "Other 4", count: 1),
    ])

    try vault.saveFeedback(
      StoredFeedback(
        entryID: entry.id,
        analysisID: analysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: nil,
        note: "No final decision",
        createdAt: Date(timeIntervalSince1970: 3)
      )
    )

    let clearedFeedbackResult = try vault.feedback(entryID: entry.id, analysisID: analysis.id)
    #expect(clearedFeedbackResult == nil)
    #expect(try vault.feedback(entryID: entry.id).isEmpty)

    statistics = try vault.statistics()
    #expect(statistics.feedbackCount == 0)
    #expect(statistics.chosenOptionCounts.isEmpty)
    #expect(statistics.chosenClusterDilemmaCount == 0)
    #expect(statistics.mostFrequentClusters.isEmpty)
  }

  @Test
  func saveLoadFullAnalysisRoundTripAndUpdate() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(databaseURL: url)
    try vault.prepare()

    let entry = sampleEntry(
      rawText: "Should I keep consulting or join a product team?",
      createdAt: Date(timeIntervalSince1970: 100),
      updatedAt: Date(timeIntervalSince1970: 101)
    )
    try vault.saveEntry(entry)

    let reasonIDs = entry.options.flatMap(\.reasons).map(\.id)
    let analysisID = UUID()
    let analysis = fullSampleAnalysis(
      id: analysisID,
      entryID: entry.id,
      rawText: entry.rawText,
      reasonIDs: Array(reasonIDs.prefix(2)),
      createdAt: Date(timeIntervalSince1970: 200),
      variant: "initial"
    )
    try vault.saveAnalysis(analysis)

    let loaded = try #require(try vault.analyses(entryID: entry.id).first)
    #expect(loaded == analysis)
    #expect(loaded.hasFullAnalysisPayload)
    #expect(loaded.embeddings.rawText == entry.rawText)
    #expect(loaded.embeddings.dilemmaText.values == [0.125, -0.25, 0.5])

    let snapshotAnalysis = try #require(try vault.snapshot().latestAnalyses[entry.id])
    #expect(snapshotAnalysis == analysis)

    let updated = fullSampleAnalysis(
      id: analysisID,
      entryID: entry.id,
      rawText: "\(entry.rawText) Updated.",
      reasonIDs: Array(reasonIDs.prefix(1)),
      createdAt: Date(timeIntervalSince1970: 300),
      variant: "updated"
    )
    try vault.saveAnalysis(updated)

    let reloaded = try #require(try vault.analyses(entryID: entry.id).first)
    #expect(reloaded == updated)
    #expect(reloaded.reasonMatches.count == 1)
    #expect(reloaded.embeddings.reasons.count == 1)
    #expect(reloaded.warnings == ["updated warning"])
  }

  @Test
  func deleteEntryRemovesItFromAnalysisStatisticsAndExport() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url
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
      StoredFeedback(
        entryID: deletedEntry.id,
        analysisID: deletedAnalysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: 1
      )
    )
    try vault.saveFeedback(
      StoredFeedback(
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
      StoredClusterFrequency(clusterID: 10, label: "Cluster 10: career", count: 1),
    ])

    let export = try vault.exportData()
    #expect(export.entries.map(\.id) == [keptEntry.id])
    #expect(export.analyses.map(\.entryID) == [keptEntry.id])
    #expect(export.feedback.map(\.entryID) == [keptEntry.id])
  }

  @Test
  func statisticsChoosePositiveClusterOverHighMagnitudeNegativeCluster() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
    let vault = DiaryVault(
      databaseURL: url
    )
    try vault.prepare()

    let entry = sampleEntry()
    try vault.saveEntry(entry)

    let analysis = StoredDecisionAnalysis(
      entryID: entry.id,
      assetVersion: 1,
      modelID: "sentence-transformers/all-MiniLM-L12-v2",
      sourceDOI: "10.1073/pnas.2406489122",
      attributeConflicts: [
        StoredAttributeConflict(
          attributeName: "money",
          option1Score: 0.8,
          option2Score: -0.2,
          difference: 1.0,
          rank: 1
        ),
      ],
      clusterProfiles: [
        StoredClusterProfile(optionIndex: 1, clusterID: 4, label: "Cluster 4: money", score: 0.4),
        StoredClusterProfile(optionIndex: 1, clusterID: 8, label: "Cluster 8: stress", score: -0.95),
        StoredClusterProfile(optionIndex: 2, clusterID: 10, label: "Cluster 10: career", score: 0.2),
      ]
    )
    try vault.saveAnalysis(analysis)
    try vault.saveFeedback(
      StoredFeedback(
        entryID: entry.id,
        analysisID: analysis.id,
        conflictWasUseful: true,
        chosenOptionIndex: 1
      )
    )

    let statistics = try vault.statistics()
    #expect(statistics.chosenClusterDilemmaCount == 1)
    #expect(statistics.mostFrequentClusters == [
      StoredClusterFrequency(clusterID: 4, label: "Cluster 4: money", count: 1),
    ])
  }

  private func sampleEntry(
    rawText: String = "Should I stay or leave?",
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> StoredDiaryEntry {
    StoredDiaryEntry(
      rawText: rawText,
      options: [
        StoredDiaryOption(
          index: 1,
          title: "Stay",
          reasons: [
            StoredDiaryReason(text: "Stable income", polarity: .benefit),
            StoredDiaryReason(text: "Close to family", polarity: .benefit),
            StoredDiaryReason(text: "Lower risk", polarity: .benefit),
            StoredDiaryReason(text: "Less growth", polarity: .cost),
            StoredDiaryReason(text: "Boredom", polarity: .cost),
            StoredDiaryReason(text: "Missed opportunity", polarity: .cost),
          ]
        ),
        StoredDiaryOption(
          index: 2,
          title: "Leave",
          reasons: [
            StoredDiaryReason(text: "Career growth", polarity: .benefit),
            StoredDiaryReason(text: "New skills", polarity: .benefit),
            StoredDiaryReason(text: "Independence", polarity: .benefit),
            StoredDiaryReason(text: "Financial risk", polarity: .cost),
            StoredDiaryReason(text: "Stress", polarity: .cost),
            StoredDiaryReason(text: "Less family time", polarity: .cost),
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
  ) -> StoredDecisionAnalysis {
    StoredDecisionAnalysis(
      entryID: entryID,
      createdAt: createdAt,
      assetVersion: 1,
      modelID: "sentence-transformers/all-MiniLM-L12-v2",
      sourceDOI: "10.1073/pnas.2406489122",
      attributeConflicts: [
        StoredAttributeConflict(
          attributeName: label,
          option1Score: 0.8,
          option2Score: -0.2,
          difference: 1.0,
          rank: 1
        ),
      ],
      clusterProfiles: [
        StoredClusterProfile(optionIndex: 1, clusterID: clusterID, label: label, score: 0.7),
        StoredClusterProfile(optionIndex: 2, clusterID: clusterID + 100, label: "Other \(clusterID)", score: 0.1),
      ]
    )
  }

  private func fullSampleAnalysis(
    id: UUID,
    entryID: UUID,
    rawText: String,
    reasonIDs: [UUID],
    createdAt: Date,
    variant: String
  ) -> StoredDecisionAnalysis {
    let modelID = "sentence-transformers/all-MiniLM-L12-v2"
    let modelName = "MiniLM L12"
    let attribute = StoredAttributeDefinition(
      attributeID: variant == "initial" ? 10 : 20,
      name: variant == "initial" ? "career growth" : "focus",
      source: "bhatia",
      clusterID: 4
    )
    let cluster = StoredClusterMetadata(
      clusterID: variant == "initial" ? 4 : 8,
      label: variant == "initial" ? "Cluster 4: career" : "Cluster 8: focus",
      representativeAttributeName: attribute.name,
      sortOrder: 1
    )

    return StoredDecisionAnalysis(
      id: id,
      entryID: entryID,
      createdAt: createdAt,
      schemaVersion: StoredDecisionAnalysis.currentSchemaVersion,
      model: StoredAnalysisModelMetadata(id: modelID, name: modelName, embeddingDimension: 3),
      asset: StoredAnalysisAssetMetadata(
        version: variant == "initial" ? 1 : 2,
        resourceName: "bhatia_attributes.sqlite",
        sourceDOI: "10.1073/pnas.2406489122"
      ),
      clusterMethod: StoredAnalysisClusterMethodMetadata(
        id: "k_means_attribute_embeddings",
        label: "K-means attribute embeddings"
      ),
      embeddings: StoredDecisionAnalysisEmbeddings(
        rawText: rawText,
        dilemmaText: StoredEmbeddingVector(
          modelID: modelID,
          modelName: modelName,
          dimension: 3,
          values: [0.125, -0.25, 0.5]
        ),
        options: [
          StoredOptionEmbedding(
            optionIndex: 1,
            title: "Keep consulting",
            embedding: StoredEmbeddingVector(
              modelID: modelID,
              modelName: modelName,
              dimension: 3,
              values: [0.5, 0.25, 0.125]
            )
          ),
          StoredOptionEmbedding(
            optionIndex: 2,
            title: "Join product",
            embedding: StoredEmbeddingVector(
              modelID: modelID,
              modelName: modelName,
              dimension: 3,
              values: [-0.5, 0.25, -0.125]
            )
          ),
        ],
        reasons: reasonIDs.enumerated().map { offset, reasonID in
          StoredReasonEmbedding(
            reasonID: reasonID,
            optionIndex: offset == 0 ? 1 : 2,
            polarity: offset == 0 ? .benefit : .cost,
            text: offset == 0 ? "High autonomy" : "Less learning",
            embedding: StoredEmbeddingVector(
              modelID: modelID,
              modelName: modelName,
              dimension: 3,
              values: [Float(offset) + 0.25, -0.5, 0.75]
            )
          )
        }
      ),
      reasonMatches: reasonIDs.enumerated().map { offset, reasonID in
        StoredReasonMatchResult(
          reason: StoredReasonInput(
            id: reasonID,
            text: offset == 0 ? "High autonomy" : "Less learning",
            optionIndex: offset == 0 ? 1 : 2,
            polarity: offset == 0 ? .benefit : .cost
          ),
          rawScores: [0.5, -0.25, Float(offset)],
          centeredScores: [0.25, -0.5, Float(offset) + 0.125],
          topMatches: [
            StoredAttributeScore(
              attribute: StoredAttributeMetadata(
                attributeID: attribute.attributeID,
                rowIndex: offset,
                name: attribute.name,
                source: attribute.source,
                direction: offset == 0 ? .pro : .con,
                vectorOffset: offset * 3,
                clusterID: attribute.clusterID
              ),
              score: 0.5
            ),
          ]
        )
      },
      optionAttributeProfiles: [
        StoredOptionAttributeProfile(
          optionIndex: 1,
          scores: [StoredAttributeProfileScore(attribute: attribute, score: 0.5)]
        ),
        StoredOptionAttributeProfile(
          optionIndex: 2,
          scores: [StoredAttributeProfileScore(attribute: attribute, score: -0.25)]
        ),
      ],
      optionClusterProfiles: [
        StoredOptionClusterProfile(
          optionIndex: 1,
          scores: [StoredClusterScore(cluster: cluster, score: 0.75)]
        ),
        StoredOptionClusterProfile(
          optionIndex: 2,
          scores: [StoredClusterScore(cluster: cluster, score: -0.25)]
        ),
      ],
      metrics: StoredAnalysisMetrics(
        modelLoadMilliseconds: 1.5,
        embeddingMilliseconds: 2.5,
        scoringMilliseconds: 3.5,
        approximateMemoryMegabytes: 4.5
      ),
      warnings: ["\(variant) warning"],
      attributeConflicts: [
        StoredAttributeConflict(
          attributeName: attribute.name,
          option1Score: 0.5,
          option2Score: -0.25,
          difference: 0.75,
          rank: 1
        ),
      ],
      clusterProfiles: [
        StoredClusterProfile(optionIndex: 1, clusterID: cluster.clusterID, label: cluster.label, score: 0.75),
        StoredClusterProfile(optionIndex: 2, clusterID: cluster.clusterID, label: cluster.label, score: -0.25),
      ]
    )
  }
}
