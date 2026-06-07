import Foundation

/// Diary-level polarity for a user reason.
/// It separates benefits from costs without exposing kernel-specific scoring directions.
public enum DiaryReasonPolarity: String, Codable, Sendable, CaseIterable {
  case benefit
  case cost
}

/// One user-written reason attached to a diary option.
/// The app keeps it as canonical diary data and maps it to kernel reason input only inside use cases.
public struct DiaryReason: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var text: String
  public var polarity: DiaryReasonPolarity

  public init(id: UUID = UUID(), text: String, polarity: DiaryReasonPolarity) {
    self.id = id
    self.text = text
    self.polarity = polarity
  }
}
