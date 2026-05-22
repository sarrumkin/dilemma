import Foundation
import Testing

@testable import dilemma

@Suite
struct BhatiaScoringTests {
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

  @Test
  func benefitScoresOnlyProAndCostScoresOnlyCon() {
    let store = makeStore()

    let benefit = BhatiaScoring.topMatches(
      reasonVector: [1, 0],
      reasonPolarity: .benefit,
      store: store,
      topK: 2
    )
    #expect(benefit.top.map(\.attribute.direction) == [.pro, .pro])
    #expect(benefit.top.first?.attribute.name == "money")

    let cost = BhatiaScoring.topMatches(
      reasonVector: [0, 1],
      reasonPolarity: .cost,
      store: store,
      topK: 2
    )
    #expect(cost.top.map(\.attribute.direction) == [.con, .con])
    #expect(cost.top.first?.attribute.name == "risk")
  }

  @Test
  func rowCenterAndOptionProfileAggregation() {
    let reason1 = ReasonInput(text: "benefit", optionIndex: 1, polarity: .benefit)
    let reason2 = ReasonInput(text: "cost", optionIndex: 1, polarity: .cost)
    let centered = BhatiaScoring.rowCenter([1, 2, .nan])
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

    let profiles = BhatiaScoring.optionProfiles(from: results, attributeCount: 2)
    #expect(profiles[1] == [1, 1])
  }

  private func makeStore() -> AttributeEmbeddingStore {
    let attributes = [
      AttributeMetadata(rowIndex: 0, name: "money", source: "test", direction: .pro, vectorOffset: 0),
      AttributeMetadata(rowIndex: 1, name: "risk", source: "test", direction: .pro, vectorOffset: 2),
      AttributeMetadata(rowIndex: 2, name: "money", source: "test", direction: .con, vectorOffset: 4),
      AttributeMetadata(rowIndex: 3, name: "risk", source: "test", direction: .con, vectorOffset: 6),
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
      ]
    )
  }
}
