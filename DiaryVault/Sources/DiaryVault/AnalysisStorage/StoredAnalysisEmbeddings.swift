import Foundation

/// Stored embedding vector with model identity and values.
public struct StoredEmbeddingVector: Codable, Equatable, Sendable {
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

/// Stored embeddings generated for one analysis.
public struct StoredDecisionAnalysisEmbeddings: Codable, Equatable, Sendable {
  public var rawText: String
  public var dilemmaText: StoredEmbeddingVector
  public var options: [StoredOptionEmbedding]
  public var reasons: [StoredReasonEmbedding]

  public init(
    rawText: String,
    dilemmaText: StoredEmbeddingVector,
    options: [StoredOptionEmbedding],
    reasons: [StoredReasonEmbedding]
  ) {
    self.rawText = rawText
    self.dilemmaText = dilemmaText
    self.options = options
    self.reasons = reasons
  }

  public static func empty(modelID: String, modelName: String) -> StoredDecisionAnalysisEmbeddings {
    StoredDecisionAnalysisEmbeddings(
      rawText: "",
      dilemmaText: StoredEmbeddingVector(modelID: modelID, modelName: modelName, dimension: 0, values: []),
      options: [],
      reasons: []
    )
  }

  public var hasStoredVectors: Bool {
    !dilemmaText.values.isEmpty
      || options.contains { !$0.embedding.values.isEmpty }
      || reasons.contains { !$0.embedding.values.isEmpty }
  }
}

/// Stored embedding for an option title.
public struct StoredOptionEmbedding: Codable, Equatable, Sendable {
  public var optionIndex: Int
  public var title: String
  public var embedding: StoredEmbeddingVector

  public init(optionIndex: Int, title: String, embedding: StoredEmbeddingVector) {
    self.optionIndex = optionIndex
    self.title = title
    self.embedding = embedding
  }
}

/// Stored embedding for one analyzed pro or con reason.
public struct StoredReasonEmbedding: Codable, Equatable, Sendable {
  public var reasonID: UUID
  public var optionIndex: Int
  public var polarity: StoredDiaryReasonPolarity
  public var text: String
  public var embedding: StoredEmbeddingVector

  public init(
    reasonID: UUID,
    optionIndex: Int,
    polarity: StoredDiaryReasonPolarity,
    text: String,
    embedding: StoredEmbeddingVector
  ) {
    self.reasonID = reasonID
    self.optionIndex = optionIndex
    self.polarity = polarity
    self.text = text
    self.embedding = embedding
  }
}

