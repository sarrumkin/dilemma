import Foundation

/// Current diary read model returned to the app.
/// It combines entries with their latest analyses so list, detail, and statistics screens share one state shape.
public struct DiarySnapshot: Equatable, Sendable {
  public var entries: [DiaryEntry]
  public var latestAnalyses: [UUID: DecisionAnalysis]
  public var latestFeedback: [UUID: Feedback]

  public init(
    entries: [DiaryEntry],
    latestAnalyses: [UUID: DecisionAnalysis],
    latestFeedback: [UUID: Feedback] = [:]
  ) {
    self.entries = entries
    self.latestAnalyses = latestAnalyses
    self.latestFeedback = latestFeedback
  }
}
