import Foundation

/// Canonical app model for one saved dilemma.
/// It stores the original question, both options, and timestamps independently from analysis results.
public struct DiaryEntry: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var rawText: String
  public var options: [DiaryOption]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    rawText: String,
    options: [DiaryOption],
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
