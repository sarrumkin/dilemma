import Foundation

/// Numeric embedding vector with model identity.
///
/// The model fields travel with the values so vectors remain meaningful across model upgrades and
/// normalized storage can persist each vector as a self-described record.
public struct EmbeddingVector: Codable, Equatable, Sendable {
  public var modelID: String
  public var modelName: String
  public var dimension: Int
  public var values: [Float]

  public init(modelID: String, modelName: String, dimension: Int, values: [Float]) {
    self.modelID = modelID
    self.modelName = modelName
    self.dimension = dimension
    self.values = values
  }
}
