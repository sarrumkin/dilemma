/// User-facing command for creating a new dilemma before it becomes a persisted diary entry.
/// It keeps the raw form input together so use cases can validate, save, and analyze one request.
public struct EntryDraftCommand: Equatable, Sendable {
  public var rawText: String
  public var option1Title: String
  public var option2Title: String
  public var option1Benefits: [String]
  public var option1Costs: [String]
  public var option2Benefits: [String]
  public var option2Costs: [String]

  public init(
    rawText: String = "",
    option1Title: String = "",
    option2Title: String = "",
    option1Benefits: [String] = Array(repeating: "", count: 3),
    option1Costs: [String] = Array(repeating: "", count: 3),
    option2Benefits: [String] = Array(repeating: "", count: 3),
    option2Costs: [String] = Array(repeating: "", count: 3)
  ) {
    self.rawText = rawText
    self.option1Title = option1Title
    self.option2Title = option2Title
    self.option1Benefits = option1Benefits
    self.option1Costs = option1Costs
    self.option2Benefits = option2Benefits
    self.option2Costs = option2Costs
  }

  public var isValid: Bool {
    !rawText.trimmed.isEmpty
      && !option1Title.trimmed.isEmpty
      && !option2Title.trimmed.isEmpty
      && option1Benefits.count >= 3
      && option1Costs.count >= 3
      && option2Benefits.count >= 3
      && option2Costs.count >= 3
      && option1Benefits.allSatisfy { !$0.trimmed.isEmpty }
      && option1Costs.allSatisfy { !$0.trimmed.isEmpty }
      && option2Benefits.allSatisfy { !$0.trimmed.isEmpty }
      && option2Costs.allSatisfy { !$0.trimmed.isEmpty }
  }
}
