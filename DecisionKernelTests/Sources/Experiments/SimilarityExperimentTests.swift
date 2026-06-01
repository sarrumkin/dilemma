import Foundation
import Testing

@testable import DecisionKernel

/// Проверки синтетического набора и базовых similarity-компонентов без записи отчетов на диск.
@Suite
struct SimilarityExperimentTests {
  /// Проверяет, что synthetic dataset валиден как структурированный DecisionDraft и содержит релевантные corpus-id.
  @Test
  func syntheticDatasetSchemaIsValid() throws {
    let dataset = try SyntheticSimilarityDataset.load()

    #expect(dataset.corpus.count >= 10)
    #expect(dataset.queries.count >= 3)

    let corpusIDs = Set(dataset.corpus.map(\.id))
    for record in dataset.corpus + dataset.queries {
      let draft = record.makeDraft()
      _ = try draft.validated()
      #expect(draft.options.count == 2)
      for option in draft.options {
        #expect(option.reasons.filter { $0.polarity == .benefit }.count == 3)
        #expect(option.reasons.filter { $0.polarity == .cost }.count == 3)
      }
    }

    for query in dataset.queries {
      #expect(!query.relevantRecordIds.isEmpty)
      for relevantID in query.relevantRecordIds {
        #expect(corpusIDs.contains(relevantID))
      }
    }
  }

  /// Проверяет, что canonical text baseline сохраняет dilemma, обе опции и обе группы reasons.
  @Test
  func canonicalTextIncludesAllStructuredFields() throws {
    let dataset = try SyntheticSimilarityDataset.load()
    let record = try #require(dataset.corpus.first)
    let text = DecisionSimilarityService.canonicalText(for: record.makeDraft())

    #expect(text.contains("Dilemma:"))
    #expect(text.contains("Option 1:"))
    #expect(text.contains("Option 1 benefits:"))
    #expect(text.contains("Option 1 costs:"))
    #expect(text.contains("Option 2:"))
    #expect(text.contains("Option 2 benefits:"))
    #expect(text.contains("Option 2 costs:"))
    #expect(text.contains(record.rawText))
  }

  /// Проверяет, что все три similarity-метода возвращают конечные top-3 scores без дублей.
  @Test(
    .enabled(
      if: DecisionKernelResourceBundle.bundle.url(
        forResource: "all-MiniLM-L12-v2",
        withExtension: nil,
        subdirectory: "Models"
      ) != nil
        && DecisionKernelResourceBundle.bundle.url(
          forResource: "DilemmaAssetsKMeans",
          withExtension: "sqlite",
          subdirectory: "Attributes"
        ) != nil,
      "Bundled L12 model folder or KMeans SQLite asset is not present."
    )
  )
  func similarityMethodsReturnFiniteTop3Matches() async throws {
    let dataset = try SyntheticSimilarityDataset.load()
    let service = DecisionSimilarityService()
    let corpus = dataset.makeCorpus()

    for queryRecord in dataset.queries {
      let query = queryRecord.makeDraft()
      let results = [
        try await service.similarRecordsByClusters(
          query: query,
          corpus: corpus,
          clusterMethod: .bhatiaWardReddit,
          topK: 3
        ),
        try await service.similarRecordsByClusters(
          query: query,
          corpus: corpus,
          clusterMethod: .kMeansAttributeEmbeddings,
          topK: 3
        ),
        try await service.similarRecordsByTextEmbedding(
          query: query,
          corpus: corpus,
          topK: 3
        ),
      ]

      for result in results {
        #expect(result.matches.count == 3)
        #expect(Set(result.matches.map(\.recordID)).count == result.matches.count)
        for match in result.matches {
          #expect(match.score.isFinite)
          #expect(corpus.contains { $0.id == match.recordID })
        }
      }
    }
  }

  /// Проверяет, что CSV и Markdown formatters включают query id и все имена методов.
  @Test
  func evaluationFormattersIncludeQueriesAndMethods() {
    let summary = SimilarityEvaluationSummary(
      topK: 3,
      cases: [
        SimilarityEvaluationCaseResult(
          queryID: "query-career-home",
          queryLabel: "career_family_balance",
          relevantRecordIDs: ["career-family-remote"],
          methodResults: SimilarityMethod.allCases.map { method in
            SimilarityMethodEvaluationResult(
              method: method,
              matches: [
                SimilarityMatch(
                  recordID: "career-family-remote",
                  method: method,
                  score: 0.9,
                  label: "career_family_balance"
                ),
              ],
              relevantRecordIDs: ["career-family-remote"]
            )
          }
        ),
      ]
    )

    let csv = SimilarityEvaluationCSVFormatter.string(from: summary)
    let markdown = SimilarityEvaluationMarkdownFormatter.string(from: summary)

    #expect(csv.contains("query-career-home"))
    #expect(csv.contains(SimilarityMethod.bhatiaClusters.rawValue))
    #expect(csv.contains(SimilarityMethod.kMeansClusters.rawValue))
    #expect(csv.contains(SimilarityMethod.textEmbedding.rawValue))
    #expect(markdown.contains("query-career-home"))
    #expect(markdown.contains("Bhatia clusters"))
    #expect(markdown.contains("KMeans clusters"))
    #expect(markdown.contains("Full-text embedding"))
  }
}
