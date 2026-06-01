import Foundation
import Testing

@testable import DecisionKernel

/// Якорный тип для поиска ресурсов внутри bundle тестового таргета.
final class SimilarityExperimentResourceAnchor {}

/// Синтетический набор дилемм для проверки similarity-поиска и отчетов эксперимента.
struct SyntheticSimilarityDataset: Decodable {
  let corpus: [SyntheticRecord]
  let queries: [SyntheticRecord]

  /// Загружает синтетический dataset из test bundle с учетом старого glob-layout и нового folder-reference layout.
  static func load() throws -> SyntheticSimilarityDataset {
    let data = try bundledDatasetData()
    return try JSONDecoder().decode(SyntheticSimilarityDataset.self, from: data)
  }

  /// Загружает raw JSON bytes того dataset, который реально попал в test bundle.
  static func bundledDatasetData() throws -> Data {
    try Data(contentsOf: bundledDatasetURL())
  }

  /// Возвращает URL bundled JSON dataset для диагностики и вычисления checksum.
  static func bundledDatasetURL() throws -> URL {
    let bundle = Bundle(for: SimilarityExperimentResourceAnchor.self)
    let candidates = [
      bundle.url(
        forResource: "synthetic_dataset",
        withExtension: "json",
        subdirectory: "Resources/SimilarityExperiment"
      ),
      bundle.url(
        forResource: "synthetic_dataset",
        withExtension: "json",
        subdirectory: "SimilarityExperiment"
      ),
      bundle.url(forResource: "synthetic_dataset", withExtension: "json"),
    ]

    if let url = candidates.compactMap({ $0 }).first {
      return url
    }

    let checkedPaths = [
      "Resources/SimilarityExperiment/synthetic_dataset.json",
      "SimilarityExperiment/synthetic_dataset.json",
      "synthetic_dataset.json",
    ]
    throw NSError(
      domain: "DecisionKernelTests.SyntheticSimilarityDataset",
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey:
          "synthetic_dataset.json was not found in test bundle. Checked: \(checkedPaths.joined(separator: ", "))",
      ]
    )
  }

  /// Возвращает URL каталога с ресурсами similarity-эксперимента в рабочей копии репозитория.
  static func repositoryResourceDirectoryURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Resources")
      .appendingPathComponent("SimilarityExperiment")
  }

  /// Возвращает URL исходного synthetic_dataset.json в рабочей копии репозитория.
  static func repositoryDatasetURL() -> URL {
    repositoryResourceDirectoryURL().appendingPathComponent("synthetic_dataset.json")
  }

  /// Преобразует corpus-секцию dataset в записи, которые ранжирует DecisionSimilarityService.
  func makeCorpus() -> [SimilarityCorpusRecord] {
    corpus.map {
      SimilarityCorpusRecord(id: $0.id, draft: $0.makeDraft(), label: $0.label)
    }
  }

  /// Преобразует query-секцию dataset в evaluation queries с множеством релевантных corpus-записей.
  func makeEvaluationQueries() -> [SimilarityEvaluationQuery] {
    queries.map {
      SimilarityEvaluationQuery(
        id: $0.id,
        draft: $0.makeDraft(),
        label: $0.label,
        relevantRecordIDs: Set($0.relevantRecordIds)
      )
    }
  }
}

/// Одна синтетическая дилемма из corpus или query-секции.
struct SyntheticRecord: Decodable {
  let id: String
  let label: String
  let relevantRecordIds: [String]
  let rawText: String
  let options: [SyntheticOption]

  enum CodingKeys: String, CodingKey {
    case id
    case label
    case relevantRecordIds
    case rawText
    case options
  }

  /// Декодирует запись и подставляет пустой список релевантных id для corpus-записей.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    label = try container.decode(String.self, forKey: .label)
    relevantRecordIds = try container.decodeIfPresent(
      [String].self,
      forKey: .relevantRecordIds
    ) ?? []
    rawText = try container.decode(String.self, forKey: .rawText)
    options = try container.decode([SyntheticOption].self, forKey: .options)
  }

  /// Строит DecisionDraft с двумя опциями и структурированными benefit/cost reasons.
  func makeDraft() -> DecisionDraft {
    DecisionDraft(
      rawText: rawText,
      options: options.enumerated().map { offset, option in
        DecisionOption(
          index: offset + 1,
          title: option.title,
          reasons: option.benefits.map { Reason(text: $0, polarity: .benefit) }
            + option.costs.map { Reason(text: $0, polarity: .cost) }
        )
      }
    )
  }
}

/// Одна опция синтетической дилеммы с раздельными benefit и cost причинами.
struct SyntheticOption: Decodable {
  let title: String
  let benefits: [String]
  let costs: [String]
}
