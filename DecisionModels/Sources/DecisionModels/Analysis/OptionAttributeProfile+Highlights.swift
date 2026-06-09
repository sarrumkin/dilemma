public extension OptionAttributeProfile {
  func strongestSignedAttributes(
    positiveLimit: Int = 3,
    negativeLimit: Int = 3
  ) -> [AttributeProfileScore] {
    let nonZeroScores = scores.filter { $0.score != 0 }

    let positives = nonZeroScores
      .filter { $0.score > 0 }
      .sorted { left, right in
        if left.score == right.score {
          return left.attribute.attributeID < right.attribute.attributeID
        }
        return left.score > right.score
      }
      .prefix(max(positiveLimit, 0))

    let negatives = nonZeroScores
      .filter { $0.score < 0 }
      .sorted { left, right in
        if left.score == right.score {
          return left.attribute.attributeID < right.attribute.attributeID
        }
        return left.score < right.score
      }
      .prefix(max(negativeLimit, 0))

    return Array(positives) + Array(negatives)
  }
}
