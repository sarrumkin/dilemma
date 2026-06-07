import Foundation

/// JSON DTO for importing or exporting one dilemma draft.
/// It is intentionally close to file format, then maps into `EntryDraftCommand` for validation and analysis.
public struct DilemmaDraftJSON: Codable, Equatable, Sendable {
  public var schemaVersion: Int?
  public var rawText: String
  public var options: [DilemmaDraftOptionJSON]
  public var analysis: DecisionAnalysis?

  public init(
    schemaVersion: Int? = 1,
    rawText: String,
    options: [DilemmaDraftOptionJSON],
    analysis: DecisionAnalysis? = nil
  ) {
    self.schemaVersion = schemaVersion
    self.rawText = rawText
    self.options = options
    self.analysis = analysis
  }

  public init(command: EntryDraftCommand) {
    self.init(
      rawText: command.rawText,
      options: [
        DilemmaDraftOptionJSON(
          title: command.option1Title,
          benefits: command.option1Benefits,
          costs: command.option1Costs
        ),
        DilemmaDraftOptionJSON(
          title: command.option2Title,
          benefits: command.option2Benefits,
          costs: command.option2Costs
        ),
      ]
    )
  }

  public init(entry: DiaryEntry, analysis: DecisionAnalysis? = nil) throws {
    let sortedOptions = entry.options.sorted { $0.index < $1.index }
    guard sortedOptions.count == 2 else {
      throw DilemmaDraftJSONValidationError.expectedTwoOptions(actual: sortedOptions.count)
    }

    self.init(
      rawText: entry.rawText,
      options: sortedOptions.map { option in
        DilemmaDraftOptionJSON(
          title: option.title,
          benefits: option.reasons.filter { $0.polarity == .benefit }.map(\.text),
          costs: option.reasons.filter { $0.polarity == .cost }.map(\.text)
        )
      },
      analysis: analysis
    )
  }

  public func validated() throws -> DilemmaDraftJSON {
    if let schemaVersion, schemaVersion != 1 {
      throw DilemmaDraftJSONValidationError.unsupportedSchemaVersion(schemaVersion)
    }
    guard !rawText.trimmed.isEmpty else {
      throw DilemmaDraftJSONValidationError.missingDilemmaText
    }
    guard options.count == 2 else {
      throw DilemmaDraftJSONValidationError.expectedTwoOptions(actual: options.count)
    }

    for (offset, option) in options.enumerated() {
      try option.validate(optionIndex: offset + 1)
    }

    return self
  }

  public func makeEntryDraftCommand() throws -> EntryDraftCommand {
    let draft = try validated()
    return EntryDraftCommand(
      rawText: draft.rawText.trimmed,
      option1Title: draft.options[0].title.trimmed,
      option2Title: draft.options[1].title.trimmed,
      option1Benefits: draft.options[0].benefits.trimmedNonEmptyValues(),
      option1Costs: draft.options[0].costs.trimmedNonEmptyValues(),
      option2Benefits: draft.options[1].benefits.trimmedNonEmptyValues(),
      option2Costs: draft.options[1].costs.trimmedNonEmptyValues()
    )
  }
}

/// JSON DTO for one option inside an imported or exported dilemma draft.
/// It keeps benefits and costs as separate arrays because that is the external file contract.
public struct DilemmaDraftOptionJSON: Codable, Equatable, Sendable {
  public var title: String
  public var benefits: [String]
  public var costs: [String]

  public init(title: String, benefits: [String], costs: [String]) {
    self.title = title
    self.benefits = benefits
    self.costs = costs
  }

  func validate(optionIndex: Int) throws {
    guard !title.trimmed.isEmpty else {
      throw DilemmaDraftJSONValidationError.missingOptionTitle(optionIndex: optionIndex)
    }
    let benefitCount = benefits.trimmedNonEmptyValues().count
    guard benefitCount >= 3 else {
      throw DilemmaDraftJSONValidationError.notEnoughReasons(
        optionIndex: optionIndex,
        polarity: .benefit,
        expected: 3,
        actual: benefitCount
      )
    }
    let costCount = costs.trimmedNonEmptyValues().count
    guard costCount >= 3 else {
      throw DilemmaDraftJSONValidationError.notEnoughReasons(
        optionIndex: optionIndex,
        polarity: .cost,
        expected: 3,
        actual: costCount
      )
    }
  }
}

/// Validation errors for the dilemma draft JSON contract.
/// They make import failures precise before any diary entry or analysis is saved.
public enum DilemmaDraftJSONValidationError: LocalizedError, Equatable, Sendable {
  case unsupportedSchemaVersion(Int)
  case missingDilemmaText
  case expectedTwoOptions(actual: Int)
  case missingOptionTitle(optionIndex: Int)
  case notEnoughReasons(
    optionIndex: Int,
    polarity: DiaryReasonPolarity,
    expected: Int,
    actual: Int
  )

  public var errorDescription: String? {
    switch self {
    case .unsupportedSchemaVersion(let version):
      "Unsupported dilemma draft JSON schema version \(version)."
    case .missingDilemmaText:
      "Dilemma text is required."
    case .expectedTwoOptions(let actual):
      "Exactly two options are required; got \(actual)."
    case .missingOptionTitle(let optionIndex):
      "Option \(optionIndex) title is required."
    case .notEnoughReasons(let optionIndex, let polarity, let expected, let actual):
      "Option \(optionIndex) needs at least \(expected) \(polarity.rawValue) reasons; got \(actual)."
    }
  }
}

private extension Array where Element == String {
  func trimmedNonEmptyValues() -> [String] {
    map(\.trimmed).filter { !$0.isEmpty }
  }
}
