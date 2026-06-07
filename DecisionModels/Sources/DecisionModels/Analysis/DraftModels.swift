import Foundation

/// Kernel-facing polarity for a reason before scoring.
/// It tells the analysis whether the text supports an option as a benefit or counts against it as a cost.
public enum ReasonPolarity: String, Codable, Equatable, Sendable {
  case benefit
  case cost

  public var targetDirection: AttributeDirection {
    switch self {
    case .benefit: .pro
    case .cost: .con
    }
  }
}

/// Validated input shape consumed by the decision analysis kernel.
/// It is separate from diary models so analysis can run on structured input without depending on persistence.
public struct DecisionDraft: Identifiable, Sendable {
  public let id: UUID
  public let rawText: String
  public let options: [DecisionOption]

  public init(id: UUID = UUID(), rawText: String, options: [DecisionOption]) {
    self.id = id
    self.rawText = rawText
    self.options = options
  }

  public func validated(requiredReasonsPerPolarity: Int = 3) throws -> DecisionDraft {
    guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw DecisionDraftValidationError.missingDilemmaText
    }
    guard options.count == 2 else {
      throw DecisionDraftValidationError.expectedTwoOptions
    }

    for option in options {
      guard !option.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw DecisionDraftValidationError.missingOptionTitle(optionIndex: option.index)
      }

      for polarity in [ReasonPolarity.benefit, .cost] {
        let count = option.reasons.filter {
          $0.polarity == polarity && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        guard count >= requiredReasonsPerPolarity else {
          throw DecisionDraftValidationError.notEnoughReasons(
            optionIndex: option.index,
            polarity: polarity,
            expected: requiredReasonsPerPolarity,
            actual: count
          )
        }
      }
    }

    return self
  }

  public var reasonInputs: [ReasonInput] {
    options
      .sorted { $0.index < $1.index }
      .flatMap { option in
        option.reasons.map {
          ReasonInput(
            id: $0.id,
            text: $0.text,
            optionIndex: option.index,
            polarity: $0.polarity
          )
        }
      }
  }
}

/// One option inside a kernel decision draft.
/// It carries the option title and reasons in the exact structure required by scoring.
public struct DecisionOption: Identifiable, Sendable {
  public let id: UUID
  public let index: Int
  public let title: String
  public let reasons: [Reason]

  public init(id: UUID = UUID(), index: Int, title: String, reasons: [Reason]) {
    self.id = id
    self.index = index
    self.title = title
    self.reasons = reasons
  }
}

/// One normalized reason used by the kernel.
/// It is intentionally small because scoring only needs text and polarity at this stage.
public struct Reason: Identifiable, Sendable {
  public let id: UUID
  public let text: String
  public let polarity: ReasonPolarity

  public init(id: UUID = UUID(), text: String, polarity: ReasonPolarity) {
    self.id = id
    self.text = text
    self.polarity = polarity
  }
}

/// Validation failures for a decision draft.
/// Use cases and tests use these errors to reject incomplete analysis input before running the model.
public enum DecisionDraftValidationError: LocalizedError, Equatable, Sendable {
  case missingDilemmaText
  case expectedTwoOptions
  case missingOptionTitle(optionIndex: Int)
  case notEnoughReasons(optionIndex: Int, polarity: ReasonPolarity, expected: Int, actual: Int)

  public var errorDescription: String? {
    switch self {
    case .missingDilemmaText:
      "Dilemma text is required."
    case .expectedTwoOptions:
      "Exactly two options are required."
    case .missingOptionTitle(let optionIndex):
      "Option \(optionIndex) title is required."
    case .notEnoughReasons(let optionIndex, let polarity, let expected, let actual):
      "Option \(optionIndex) needs \(expected) \(polarity.rawValue) reasons; got \(actual)."
    }
  }
}

/// Flattened reason plus its option context.
/// Scoring uses it to keep each embedding and match tied back to the option and polarity that produced it.
public struct ReasonInput: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let text: String
  public let optionIndex: Int
  public let polarity: ReasonPolarity

  public init(
    id: UUID = UUID(),
    text: String,
    optionIndex: Int,
    polarity: ReasonPolarity
  ) {
    self.id = id
    self.text = text
    self.optionIndex = optionIndex
    self.polarity = polarity
  }
}
