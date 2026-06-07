import Foundation

/// One selectable side of a dilemma in diary data.
/// It owns the user-provided title and structured reasons used later by the analysis pipeline.
public struct DiaryOption: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var index: Int
  public var title: String
  public var reasons: [DiaryReason]

  public init(
    id: UUID = UUID(),
    index: Int,
    title: String,
    reasons: [DiaryReason]
  ) {
    self.id = id
    self.index = index
    self.title = title
    self.reasons = reasons
  }
}
