import Foundation
import Testing
import DecisionModels

@testable import DecisionKernel

/// Набор unit-тестов для загрузки векторов, attribute scoring и агрегации conflict-профилей.
@Suite
struct AttributeScoringTests {
  /// Проверяет, что little-endian Float16 файл разворачивается в ожидаемые Float значения.
  @Test
  func float16VectorLoaderExpandsLittleEndianValues() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("f16")
    let values: [Float16] = [1, -2, 0.5]
    var data = Data()

    for value in values {
      let bits = value.bitPattern
      data.append(UInt8(bits & 0xff))
      data.append(UInt8(bits >> 8))
    }

    try data.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let loaded = try loadFloat16VectorFile(at: url, expectedCount: 3)
    #expect(loaded == [1, -2, 0.5])
  }

  /// Проверяет, что benefit reasons матчятся только с pro rows, а cost reasons только с con rows.
  @Test
  func benefitScoresOnlyProAndCostScoresOnlyCon() {
    let store = makeStore()

    let benefit = AttributeScoring.topMatches(
      reasonVector: [1, 0],
      reasonPolarity: .benefit,
      store: store,
      topK: 2
    )
    #expect(benefit.top.map(\.attribute.direction) == [.pro, .pro])
    #expect(benefit.top.first?.attribute.name == "money")

    let cost = AttributeScoring.topMatches(
      reasonVector: [0, 1],
      reasonPolarity: .cost,
      store: store,
      topK: 2
    )
    #expect(cost.top.map(\.attribute.direction) == [.con, .con])
    #expect(cost.top.first?.attribute.name == "risk")
  }

  /// Проверяет row-centering и усреднение centered scores в option profile.
  @Test
  func rowCenterAndOptionProfileAggregation() {
    let reason1 = ReasonInput(text: "benefit", optionIndex: 1, polarity: .benefit)
    let reason2 = ReasonInput(text: "cost", optionIndex: 1, polarity: .cost)
    let centered = AttributeScoring.rowCenter([1, 2, .nan])
    #expect(abs(centered[0] + 0.5) < 0.0001)
    #expect(abs(centered[1] - 0.5) < 0.0001)
    #expect(centered[2].isNaN)

    let results = [
      ReasonMatchResult(
        reason: reason1,
        rawScores: [],
        centeredScores: [2, 4],
        topMatches: []
      ),
      ReasonMatchResult(
        reason: reason2,
        rawScores: [],
        centeredScores: [1, 3],
        topMatches: []
      ),
    ]

    let profiles = AttributeScoring.optionProfiles(from: results, attributeCount: 2)
    #expect(profiles[1] == [1, 1])
  }

  /// Проверяет, что pro/con rows одного attribute схлопываются в единый attribute profile.
  @Test
  func attributeProfilesCollapseProAndConRowsToUniqueAttributes() {
    let store = makeStore()
    let results = [
      ReasonMatchResult(
        reason: ReasonInput(text: "benefit", optionIndex: 1, polarity: .benefit),
        rawScores: [],
        centeredScores: [2, 4, .nan, .nan],
        topMatches: []
      ),
      ReasonMatchResult(
        reason: ReasonInput(text: "cost", optionIndex: 1, polarity: .cost),
        rawScores: [],
        centeredScores: [.nan, .nan, 1, 3],
        topMatches: []
      ),
    ]

    let profiles = AttributeScoring.optionAttributeProfiles(from: results, store: store)

    #expect(profiles[1] == [1, 1])
    #expect(store.attributeDefinitions.map(\.name) == ["money", "risk"])
  }

  /// Проверяет, что conflict vector строится как abs(option1 - option2) и не зависит от порядка опций.
  @Test
  func conflictVectorIgnoresOptionOrder() {
    let profiles: [Int: [Float]] = [
      1: [1, -2, 4],
      2: [-3, 1, 4],
    ]
    let swapped: [Int: [Float]] = [
      1: profiles[2]!,
      2: profiles[1]!,
    ]

    #expect(AttributeScoring.conflictVector(optionProfiles: profiles) == [4, 3, 0])
    #expect(AttributeScoring.conflictVector(optionProfiles: profiles) == AttributeScoring.conflictVector(optionProfiles: swapped))
  }

  /// Проверяет стабильный порядок cluster-вектора и поведение нормализации для нулевого вектора.
  @Test
  func clusterVectorAggregationKeepsStableClusterOrder() {
    let store = makeStore()
    let aggregator = ClusterAggregator(store: store)

    #expect(aggregator.vector(fromAttributeProfile: [2, 4]) == [2, 4])
    #expect(AttributeScoring.normalize([Float(0), Float(0)]) == [0, 0])
  }

  /// Проверяет, что DecisionDraft validation требует текст дилеммы и структурированные опции.
  @Test
  func decisionDraftValidationRequiresStructuredReasons() throws {
    let valid = DecisionAnalysisRunner.defaultDraft

    _ = try valid.validated()

    let invalid = DecisionDraft(rawText: "", options: [])
    do {
      _ = try invalid.validated()
      Issue.record("Expected missing dilemma text validation error.")
    } catch let error as DecisionDraftValidationError {
      #expect(error == .missingDilemmaText)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  /// Проверяет загрузку production SQLite asset, если он доступен в bundle тестового окружения.
  @Test
  func productionSQLiteAssetLoadsIfPresent() throws {
    let assetURL = DecisionKernelResourceBundle.bundle.url(
      forResource: "DilemmaAssets",
      withExtension: "sqlite",
      subdirectory: "Attributes"
    )
    guard assetURL != nil else { return }

    let store = try AttributeEmbeddingStore.loadSQLite()

    #expect(store.attributeDefinitions.count == 207)
    #expect(store.metadata.attributes.count == 414)
    #expect(store.clusters.count == 25)
    #expect(store.assetVersion == 2)
    #expect(store.metadata.model.shortName == "multi_l12")
    #expect(store.dimension == 384)
  }

  /// Создает компактный in-memory AttributeEmbeddingStore для unit-тестов scoring и агрегации.
  private func makeStore() -> AttributeEmbeddingStore {
    let attributes = [
      AttributeMetadata(attributeID: 1, rowIndex: 0, name: "money", source: "test", direction: .pro, vectorOffset: 0, clusterID: 1),
      AttributeMetadata(attributeID: 2, rowIndex: 1, name: "risk", source: "test", direction: .pro, vectorOffset: 2, clusterID: 2),
      AttributeMetadata(attributeID: 1, rowIndex: 2, name: "money", source: "test", direction: .con, vectorOffset: 4, clusterID: 1),
      AttributeMetadata(attributeID: 2, rowIndex: 3, name: "risk", source: "test", direction: .con, vectorOffset: 6, clusterID: 2),
    ]
    let metadata = AttributeAssetMetadata(
      assetVersion: 1,
      sourceDoi: "test",
      model: AttributeAssetModel(id: "test", shortName: "test", embeddingDimension: 2),
      vectors: AttributeVectorFile(file: "test.f16", dtype: "float16", layout: "row-major", normalized: true),
      attributes: attributes
    )

    return AttributeEmbeddingStore(
      metadata: metadata,
      vectors: [
        [1, 0],
        [0, 1],
        [1, 0],
        [0, 1],
      ],
      clusters: [
        ClusterMetadata(
          clusterID: 1,
          label: "money",
          representativeAttributeName: "money",
          sortOrder: 1
        ),
        ClusterMetadata(
          clusterID: 2,
          label: "risk",
          representativeAttributeName: "risk",
          sortOrder: 2
        ),
      ]
    )
  }
}
