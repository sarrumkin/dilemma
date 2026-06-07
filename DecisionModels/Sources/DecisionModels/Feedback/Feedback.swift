import Foundation

/// Canonical app model for feedback and final choice on a dilemma.
/// It connects user judgement to an analysis so statistics can learn from accepted, rejected, or chosen outcomes.
public struct Feedback: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var entryID: UUID
  public var analysisID: UUID?
  public var conflictWasUseful: Bool
  public var correctedClusterID: Int?
  public var correctedAttributeName: String?
  public var chosenOptionIndex: Int?
  public var note: String
  public var createdAt: Date

  public init(
    id: UUID = UUID(),
    entryID: UUID,
    analysisID: UUID?,
    conflictWasUseful: Bool,
    correctedClusterID: Int? = nil,
    correctedAttributeName: String? = nil,
    chosenOptionIndex: Int? = nil,
    note: String = "",
    createdAt: Date = Date()
  ) {
    self.id = id
    self.entryID = entryID
    self.analysisID = analysisID
    self.conflictWasUseful = conflictWasUseful
    self.correctedClusterID = correctedClusterID
    self.correctedAttributeName = correctedAttributeName
    self.chosenOptionIndex = chosenOptionIndex
    self.note = note
    self.createdAt = createdAt
  }
}
