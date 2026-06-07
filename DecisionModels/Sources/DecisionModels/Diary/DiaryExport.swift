import Foundation

/// Portable export payload for the whole diary.
/// It preserves entries, full analyses, and feedback so local data can be shared or restored without vault internals.
public struct DiaryExport: Codable, Equatable, Sendable {
  public var schemaVersion: Int
  public var exportedAt: Date
  public var entries: [DiaryEntry]
  public var analyses: [DecisionAnalysis]
  public var feedback: [Feedback]

  public init(
    schemaVersion: Int = 1,
    exportedAt: Date = Date(),
    entries: [DiaryEntry],
    analyses: [DecisionAnalysis],
    feedback: [Feedback]
  ) {
    self.schemaVersion = schemaVersion
    self.exportedAt = exportedAt
    self.entries = entries
    self.analyses = analyses
    self.feedback = feedback
  }
}
