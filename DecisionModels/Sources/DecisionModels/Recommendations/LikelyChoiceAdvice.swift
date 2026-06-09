import Foundation

/// Previously decided analysis paired with the option the user actually chose.
/// Recommendation logic uses these records as evidence for mapping past preferences onto a current dilemma.
public struct SimilarDecidedChoice: Equatable, Sendable {
  public var analysis: DecisionAnalysis
  public var chosenOptionIndex: Int

  public init(analysis: DecisionAnalysis, chosenOptionIndex: Int) {
    self.analysis = analysis
    self.chosenOptionIndex = chosenOptionIndex
  }
}

/// Advice about which current option looks more likely based on similar past decisions.
/// This is an advisory aggregate, not a choice made by the app on the user's behalf.
/// It keeps support values and per-option weights so UI can show confidence instead of only a hard answer.
public struct LikelyChoiceAdvice: Equatable, Sendable {
  public var optionIndex: Int?
  public var support: Double
  public var decidedDilemmaCount: Int
  public var optionWeights: [Int: Double]
  public var supportByOption: [Int: Double]

  public init(
    optionIndex: Int?,
    support: Double,
    decidedDilemmaCount: Int,
    optionWeights: [Int: Double],
    supportByOption: [Int: Double]
  ) {
    self.optionIndex = optionIndex
    self.support = support
    self.decidedDilemmaCount = decidedDilemmaCount
    self.optionWeights = optionWeights
    self.supportByOption = supportByOption
  }
}
