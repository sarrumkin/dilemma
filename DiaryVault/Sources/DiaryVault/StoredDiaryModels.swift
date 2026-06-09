import Foundation

public struct StoredDiarySnapshot: Equatable, Sendable {
  public var entries: [StoredDiaryEntry]
  public var latestAnalyses: [UUID: StoredDecisionAnalysis]
  public var latestFeedback: [UUID: StoredFeedback]

  public init(
    entries: [StoredDiaryEntry],
    latestAnalyses: [UUID: StoredDecisionAnalysis],
    latestFeedback: [UUID: StoredFeedback] = [:]
  ) {
    self.entries = entries
    self.latestAnalyses = latestAnalyses
    self.latestFeedback = latestFeedback
  }
}

public enum StoredDiaryReasonPolarity: String, Codable, Sendable, CaseIterable {
  case benefit
  case cost
}

public struct StoredDiaryReason: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var text: String
  public var polarity: StoredDiaryReasonPolarity

  public init(id: UUID = UUID(), text: String, polarity: StoredDiaryReasonPolarity) {
    self.id = id
    self.text = text
    self.polarity = polarity
  }
}

public struct StoredDiaryOption: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var index: Int
  public var title: String
  public var reasons: [StoredDiaryReason]

  public init(
    id: UUID = UUID(),
    index: Int,
    title: String,
    reasons: [StoredDiaryReason]
  ) {
    self.id = id
    self.index = index
    self.title = title
    self.reasons = reasons
  }
}

public struct StoredDiaryEntry: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var rawText: String
  public var options: [StoredDiaryOption]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    rawText: String,
    options: [StoredDiaryOption],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.rawText = rawText
    self.options = options
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
