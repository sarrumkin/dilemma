import Foundation
import Testing

@testable import DecisionKernel

/// Постоянный runner similarity-эксперимента, который сохраняет отдельный отчет для каждого запуска.
@Suite
struct SimilarityExperimentRunTests {
  private static let topK = 3
  private static let model = "sentence-transformers/all-MiniLM-L12-v2"
  private static let modelResourceName = "all-MiniLM-L12-v2"

  /// Проверяет наличие bundled model и обоих SQLite assets, без которых отчет нельзя пересчитать.
  private static var requiredResourcesAvailable: Bool {
    let bundle = DecisionKernelResourceBundle.bundle
    let modelURL = bundle.url(
      forResource: modelResourceName,
      withExtension: nil,
      subdirectory: "Models"
    )
    let bhatiaAssetURL = bundle.url(
      forResource: DecisionClusterMethod.bhatiaWardReddit.assetResourceName,
      withExtension: "sqlite",
      subdirectory: "Attributes"
    )
    let kMeansAssetURL = bundle.url(
      forResource: DecisionClusterMethod.kMeansAttributeEmbeddings.assetResourceName,
      withExtension: "sqlite",
      subdirectory: "Attributes"
    )
    return modelURL != nil && bhatiaAssetURL != nil && kMeansAssetURL != nil
  }

  /// Запускает synthetic similarity experiment и пишет metadata, Markdown и CSV в новый run-каталог.
  @Test(
    .enabled(
      if: Self.requiredResourcesAvailable,
      "Bundled L12 model folder, Bhatia SQLite asset, or KMeans SQLite asset is not present."
    )
  )
  func runSyntheticSimilarityExperiment() async throws {
    // Фиксируем время старта: оно нужно и для duration, и для стабильного имени run-каталога.
    let startedAt = Date()

    // Загружаем synthetic dataset из test bundle, чтобы runner работал с теми же данными, что и проверки схемы.
    let dataset = try SyntheticSimilarityDataset.load()

    // Превращаем corpus-записи dataset в searchable records для DecisionSimilarityService.
    let corpus = dataset.makeCorpus()

    // Превращаем query-записи dataset в evaluation queries с множеством релевантных corpus ids.
    let queries = dataset.makeEvaluationQueries()

    // Запускаем общий evaluator: он последовательно считает Bhatia clusters, KMeans clusters и full-text embedding.
    let summary = try await SimilarityEvaluationRunner().evaluate(
      queries: queries,
      corpus: corpus,
      topK: Self.topK
    )

    // Сохраняем длительность полного прогона, включая model load, embedding и scoring.
    let durationSeconds = Date().timeIntervalSince(startedAt)

    // Берем raw bytes dataset, чтобы записать checksum конкретной версии входных данных в metadata.
    let datasetData = try SyntheticSimilarityDataset.bundledDatasetData()

    // Создаем уникальный run id, чтобы новый отчет не перезаписал предыдущие результаты.
    let runID = Self.makeRunID(startedAt: startedAt)

    // Создаем каталог DecisionKernelTests/Resources/SimilarityExperiment/Runs/<run_id>.
    let runDirectory = try Self.createRunDirectory(runID: runID)

    // Собираем metadata, по которой можно воспроизвести контекст запуска без чтения Markdown/CSV.
    let metadata = SimilarityExperimentRunMetadata(
      runID: runID,
      generatedAt: Self.isoString(from: startedAt),
      topK: Self.topK,
      model: Self.model,
      modelResourceName: Self.modelResourceName,
      assetResourceNames: [
        "bhatia": DecisionClusterMethod.bhatiaWardReddit.assetResourceName,
        "kMeans": DecisionClusterMethod.kMeansAttributeEmbeddings.assetResourceName,
      ],
      corpusCount: corpus.count,
      queryCount: queries.count,
      datasetChecksum: Self.fnv1a64Checksum(for: datasetData),
      durationSeconds: durationSeconds
    )

    // Записываем metadata.json рядом с отчетами конкретного запуска.
    try Self.write(metadata: metadata, to: runDirectory)

    // Записываем человекочитаемый Markdown и табличный CSV из одного и того же summary.
    try Self.write(summary: summary, to: runDirectory)

    // Проверяем, что evaluator вернул результат для каждого query из synthetic dataset.
    #expect(summary.cases.count == dataset.queries.count)

    // Проверяем, что runner реально создал все три ожидаемых артефакта запуска.
    #expect(FileManager.default.fileExists(atPath: runDirectory.appendingPathComponent("metadata.json").path))
    #expect(FileManager.default.fileExists(atPath: runDirectory.appendingPathComponent("similarity_experiment_run.md").path))
    #expect(FileManager.default.fileExists(atPath: runDirectory.appendingPathComponent("similarity_experiment_run.csv").path))

    // Печатаем путь, чтобы его было легко открыть из xcodebuild logs.
    print("SIMILARITY_EXPERIMENT_RUN_DIR=\(runDirectory.path)")
  }

  /// Создает стабильный человекочитаемый run id из UTC timestamp и короткого UUID.
  private static func makeRunID(startedAt: Date, uuid: UUID = UUID()) -> String {
    "\(runIDTimestamp(from: startedAt))_\(uuid.uuidString.prefix(8).lowercased())"
  }

  /// Создает каталог Runs/<run_id> внутри DecisionKernelTests/Resources/SimilarityExperiment.
  private static func createRunDirectory(runID: String) throws -> URL {
    let directory = SyntheticSimilarityDataset.repositoryResourceDirectoryURL()
      .appendingPathComponent("Runs")
      .appendingPathComponent(runID)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Записывает metadata.json с отсортированными ключами для удобного diff.
  private static func write(metadata: SimilarityExperimentRunMetadata, to directory: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(metadata)
    try data.write(to: directory.appendingPathComponent("metadata.json"), options: .atomic)
  }

  /// Записывает Markdown и CSV версии одного evaluation summary.
  private static func write(summary: SimilarityEvaluationSummary, to directory: URL) throws {
    try SimilarityEvaluationMarkdownFormatter.string(from: summary).write(
      to: directory.appendingPathComponent("similarity_experiment_run.md"),
      atomically: true,
      encoding: .utf8
    )
    try SimilarityEvaluationCSVFormatter.string(from: summary).write(
      to: directory.appendingPathComponent("similarity_experiment_run.csv"),
      atomically: true,
      encoding: .utf8
    )
  }

  /// Форматирует дату в UTC timestamp без двоеточий, безопасный для имени каталога.
  private static func runIDTimestamp(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
    return formatter.string(from: date)
  }

  /// Форматирует дату в ISO8601 для metadata.json.
  private static func isoString(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  /// Считает быстрый FNV-1a checksum для фиксации версии synthetic dataset в metadata.
  private static func fnv1a64Checksum(for data: Data) -> String {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in data {
      hash ^= UInt64(byte)
      hash &*= 0x100000001b3
    }
    return String(format: "fnv1a64:%016llx", hash)
  }
}

/// Metadata одного сохраненного запуска similarity-эксперимента.
private struct SimilarityExperimentRunMetadata: Encodable {
  let runID: String
  let generatedAt: String
  let topK: Int
  let model: String
  let modelResourceName: String
  let assetResourceNames: [String: String]
  let corpusCount: Int
  let queryCount: Int
  let datasetChecksum: String
  let durationSeconds: TimeInterval
}
