import DecisionModels
import Foundation

public struct SimilarityEvaluationQuery: Identifiable, Sendable {
  public let id: String
  public let draft: DecisionDraft
  public let label: String?
  public let relevantRecordIDs: Set<String>

  /// Creates an evaluation query and the set of corpus records considered relevant for it.
  public init(
    id: String,
    draft: DecisionDraft,
    label: String? = nil,
    relevantRecordIDs: Set<String>
  ) {
    self.id = id
    self.draft = draft
    self.label = label
    self.relevantRecordIDs = relevantRecordIDs
  }
}

public struct SimilarityMethodEvaluationResult: Sendable {
  public let method: SimilarityMethod
  public let matches: [SimilarityMatch]
  public let relevantCountAtK: Int
  public let hitAtK: Bool

  /// Computes relevance counts for one method's ranked matches.
  public init(method: SimilarityMethod, matches: [SimilarityMatch], relevantRecordIDs: Set<String>) {
    self.method = method
    self.matches = matches
    self.relevantCountAtK = matches.filter { relevantRecordIDs.contains($0.recordID) }.count
    self.hitAtK = self.relevantCountAtK > 0
  }
}

public struct SimilarityEvaluationCaseResult: Sendable {
  public let queryID: String
  public let queryLabel: String?
  public let relevantRecordIDs: Set<String>
  public let methodResults: [SimilarityMethodEvaluationResult]

  /// Creates all method-level evaluation results for one query.
  public init(
    queryID: String,
    queryLabel: String?,
    relevantRecordIDs: Set<String>,
    methodResults: [SimilarityMethodEvaluationResult]
  ) {
    self.queryID = queryID
    self.queryLabel = queryLabel
    self.relevantRecordIDs = relevantRecordIDs
    self.methodResults = methodResults
  }
}

public struct SimilarityEvaluationSummary: Sendable {
  public let topK: Int
  public let cases: [SimilarityEvaluationCaseResult]

  /// Creates an evaluation summary over all queries and methods.
  public init(topK: Int, cases: [SimilarityEvaluationCaseResult]) {
    self.topK = topK
    self.cases = cases
  }

  /// Counts how many query cases had at least one relevant match for the given method.
  public func hitCount(for method: SimilarityMethod) -> Int {
    cases.reduce(0) { total, result in
      guard let methodResult = result.methodResults.first(where: { $0.method == method }) else {
        return total
      }
      return total + (methodResult.hitAtK ? 1 : 0)
    }
  }
}

public struct SimilarityEvaluationRunner: Sendable {
  private let service: DecisionSimilarityService

  /// Creates an evaluator around a similarity service.
  public init(service: DecisionSimilarityService = DecisionSimilarityService()) {
    self.service = service
  }

  /// Runs Bhatia, KMeans, and full-text similarity for every query against the same corpus.
  public func evaluate(
    queries: [SimilarityEvaluationQuery],
    corpus: [SimilarityCorpusRecord],
    topK: Int = 3
  ) async throws -> SimilarityEvaluationSummary {
    var cases = [SimilarityEvaluationCaseResult]()
    cases.reserveCapacity(queries.count)

    for query in queries {
      let bhatia = try await service.similarRecordsByClusters(
        query: query.draft,
        corpus: corpus,
        clusterMethod: .bhatiaWardReddit,
        topK: topK
      )
      let kmeans = try await service.similarRecordsByClusters(
        query: query.draft,
        corpus: corpus,
        clusterMethod: .kMeansAttributeEmbeddings,
        topK: topK
      )
      let textEmbedding = try await service.similarRecordsByTextEmbedding(
        query: query.draft,
        corpus: corpus,
        topK: topK
      )

      cases.append(
        SimilarityEvaluationCaseResult(
          queryID: query.id,
          queryLabel: query.label,
          relevantRecordIDs: query.relevantRecordIDs,
          methodResults: [bhatia, kmeans, textEmbedding].map {
            SimilarityMethodEvaluationResult(
              method: $0.method,
              matches: $0.matches,
              relevantRecordIDs: query.relevantRecordIDs
            )
          }
        )
      )
    }

    return SimilarityEvaluationSummary(topK: topK, cases: cases)
  }
}

public enum SimilarityEvaluationCSVFormatter {
  /// Renders a similarity evaluation summary as CSV rows.
  public static func string(from summary: SimilarityEvaluationSummary) -> String {
    var rows = ["query_id,query_label,method,rank,record_id,record_label,score,is_relevant"]

    for result in summary.cases {
      for methodResult in result.methodResults {
        for (index, match) in methodResult.matches.enumerated() {
          rows.append(
            [
              result.queryID,
              result.queryLabel ?? "",
              methodResult.method.rawValue,
              String(index + 1),
              match.recordID,
              match.label ?? "",
              String(format: "%.6f", Double(match.score)),
              result.relevantRecordIDs.contains(match.recordID) ? "true" : "false",
            ].map(escapeCSV).joined(separator: ",")
          )
        }
      }
    }

    return rows.joined(separator: "\n") + "\n"
  }

  /// Escapes one CSV field according to RFC 4180 quoting rules used by spreadsheet readers.
  private static func escapeCSV(_ value: String) -> String {
    if value.contains(",") || value.contains("\"") || value.contains("\n") {
      return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return value
  }
}

public enum SimilarityEvaluationMarkdownFormatter {
  /// Renders a similarity evaluation summary as a Markdown report.
  public static func string(from summary: SimilarityEvaluationSummary) -> String {
    var lines = [
      "# Similarity Methods Swift Evaluation",
      "",
      "- Model: sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
      "- Dataset: synthetic English dilemmas",
      "- Top K: \(summary.topK)",
      "- Evaluation: qualitative illustrative retrieval, not a statistical benchmark",
      "",
      "## Hit Summary",
      "",
      "| Method | hits@\(summary.topK) | Queries |",
      "| --- | ---: | ---: |",
    ]

    for method in SimilarityMethod.allCases {
      lines.append("| \(method.label) | \(summary.hitCount(for: method)) | \(summary.cases.count) |")
    }

    for result in summary.cases {
      lines.append(contentsOf: [
        "",
        "## \(result.queryID)",
        "",
        "- Label: \(result.queryLabel ?? "")",
        "- Relevant records: \(result.relevantRecordIDs.sorted().joined(separator: ", "))",
        "",
        "| Method | Rank | Record | Score | Relevant |",
        "| --- | ---: | --- | ---: | --- |",
      ])

      for methodResult in result.methodResults {
        for (index, match) in methodResult.matches.enumerated() {
          let relevant = result.relevantRecordIDs.contains(match.recordID) ? "yes" : "no"
          lines.append(
            "| \(methodResult.method.label) | \(index + 1) | \(match.recordID) | \(String(format: "%.4f", Double(match.score))) | \(relevant) |"
          )
        }
      }
    }

    lines.append(contentsOf: [
      "",
      "## Notes",
      "",
      "- Bhatia and KMeans methods compare conflict structure over the same 207 Bhatia attributes.",
      "- Bhatia uses the reconstructed Ward mapping from Reddit option profiles.",
      "- KMeans uses an alternate grouping of the same attributes by multilingual MiniLM L12 mean pro/con embeddings.",
      "- Full-text embedding compares canonical structured text directly.",
    ])

    return lines.joined(separator: "\n") + "\n"
  }
}
