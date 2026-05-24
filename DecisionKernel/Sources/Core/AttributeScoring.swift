import Accelerate
import Foundation

enum AttributeScoring {
  static func topMatches(
    reasonVector: [Float],
    reasonPolarity: ReasonPolarity,
    store: AttributeEmbeddingStore,
    topK: Int
  ) -> (scores: [Float], top: [AttributeScore]) {
    let candidateIndices = store.directionIndices(for: reasonPolarity.targetDirection)
    var directionScores = Array(repeating: Float.nan, count: store.metadata.attributes.count)
    var ranked = [AttributeScore]()
    ranked.reserveCapacity(candidateIndices.count)

    // Benefits are scored against pro vectors, while costs are scored against
    // con vectors. Both sides are normalized, so cosine similarity is dot.
    for index in candidateIndices {
      let score = store.dot(normalizedReasonVector: reasonVector, attributeIndex: index)
      directionScores[index] = score
      ranked.append(AttributeScore(attribute: store.metadata.attributes[index], score: score))
    }

    ranked.sort { $0.score > $1.score }
    return (directionScores, Array(ranked.prefix(topK)))
  }

  static func rowCenter(_ scores: [Float]) -> [Float] {
    let finiteScores = scores.filter { $0.isFinite }
    guard !finiteScores.isEmpty else { return scores }
    let mean = finiteScores.reduce(0, +) / Float(finiteScores.count)
    return scores.map { $0.isFinite ? $0 - mean : $0 }
  }

  static func optionProfiles(from results: [ReasonMatchResult], attributeCount: Int) -> [Int: [Float]] {
    let options = Set(results.map(\.reason.optionIndex))
    var profiles: [Int: [Float]] = [:]

    for option in options {
      let benefits = results.filter {
        $0.reason.optionIndex == option && $0.reason.polarity == .benefit
      }.map(\.centeredScores)
      let costs = results.filter {
        $0.reason.optionIndex == option && $0.reason.polarity == .cost
      }.map(\.centeredScores)

      let benefitMean = meanRows(benefits, width: attributeCount)
      let costMean = meanRows(costs, width: attributeCount)
      profiles[option] = zip(benefitMean, costMean).map { benefit, cost in
        benefit - cost
      }
    }

    return profiles
  }

  static func optionAttributeProfiles(
    from results: [ReasonMatchResult],
    store: AttributeEmbeddingStore
  ) -> [Int: [Float]] {
    let options = Set(results.map(\.reason.optionIndex))
    var profiles: [Int: [Float]] = [:]

    for option in options {
      let benefits = results.filter {
        $0.reason.optionIndex == option && $0.reason.polarity == .benefit
      }
      let costs = results.filter {
        $0.reason.optionIndex == option && $0.reason.polarity == .cost
      }

      let benefitMean = meanAttributeRows(benefits, store: store)
      let costMean = meanAttributeRows(costs, store: store)
      profiles[option] = zip(benefitMean, costMean).map { benefit, cost in
        benefit - cost
      }
    }

    return profiles
  }

  static func conflictDimensions(
    optionProfiles: [Int: [Float]],
    attributes: [AttributeDefinition],
    topK: Int
  ) -> [ConflictDimension] {
    guard
      let option1 = optionProfiles[1],
      let option2 = optionProfiles[2],
      option1.count == option2.count
    else {
      return []
    }

    return option1.indices
      .map { index in
        ConflictDimension(
          attributeName: attributes[index].name,
          option1Score: option1[index],
          option2Score: option2[index],
          difference: option1[index] - option2[index]
        )
      }
      .sorted { abs($0.difference) > abs($1.difference) }
      .prefix(topK)
      .map { $0 }
  }

  static func topAttributes(
    optionProfiles: [Int: [Float]],
    attributes: [AttributeDefinition],
    topK: Int
  ) -> [Int: [AttributeProfileScore]] {
    optionProfiles.mapValues { profile in
      profile.indices
        .map { index in
          AttributeProfileScore(attribute: attributes[index], score: profile[index])
        }
        .sorted { abs($0.score) > abs($1.score) }
        .prefix(topK)
        .map { $0 }
    }
  }

  static func dot(_ lhs: [Float], _ rhs: [Float]) -> Float {
    lhs.withUnsafeBufferPointer { lhsBuffer in
      rhs.withUnsafeBufferPointer { rhsBuffer in
        guard
          let lhsBase = lhsBuffer.baseAddress,
          let rhsBase = rhsBuffer.baseAddress
        else { return 0 }

        var total = Float(0)
        vDSP_dotpr(lhsBase, 1, rhsBase, 1, &total, vDSP_Length(Swift.min(lhs.count, rhs.count)))
        return total
      }
    }
  }

  static func normalize(_ vector: [Float]) -> [Float] {
    let norm = sqrt(vector.reduce(Float(0)) { $0 + $1 * $1 })
    guard norm > 0 else { return vector }
    return vector.map { $0 / norm }
  }

  private static func meanRows(_ rows: [[Float]], width: Int) -> [Float] {
    guard !rows.isEmpty else { return Array(repeating: 0, count: width) }
    var totals = Array(repeating: Float(0), count: width)
    var counts = Array(repeating: Float(0), count: width)

    for row in rows {
      for index in 0..<Swift.min(row.count, width) where row[index].isFinite {
        totals[index] += row[index]
        counts[index] += 1
      }
    }

    return totals.indices.map { index in
      counts[index] == 0 ? 0 : totals[index] / counts[index]
    }
  }

  private static func meanAttributeRows(
    _ results: [ReasonMatchResult],
    store: AttributeEmbeddingStore
  ) -> [Float] {
    guard !results.isEmpty else { return Array(repeating: 0, count: store.attributeCount) }
    var totals = Array(repeating: Float(0), count: store.attributeCount)
    var counts = Array(repeating: Float(0), count: store.attributeCount)

    for result in results {
      for rowIndex in 0..<Swift.min(result.centeredScores.count, store.metadata.attributes.count) {
        let score = result.centeredScores[rowIndex]
        guard score.isFinite, let attributeOrdinal = store.attributeOrdinal(forRowIndex: rowIndex) else {
          continue
        }
        totals[attributeOrdinal] += score
        counts[attributeOrdinal] += 1
      }
    }

    return totals.indices.map { index in
      counts[index] == 0 ? 0 : totals[index] / counts[index]
    }
  }
}
