import Foundation

/// All embeddings generated for one analysis.
/// It stores vectors for the dilemma text, option titles, and every pro/con reason so the analysis is complete.
public struct DecisionAnalysisEmbeddings: Codable, Equatable, Sendable {
  public var rawText: String
  public var dilemmaText: EmbeddingVector
  public var options: [OptionEmbedding]
  public var reasons: [ReasonEmbedding]

  public init(
    rawText: String,
    dilemmaText: EmbeddingVector,
    options: [OptionEmbedding],
    reasons: [ReasonEmbedding]
  ) {
    self.rawText = rawText
    self.dilemmaText = dilemmaText
    self.options = options
    self.reasons = reasons
  }
}

/// Embedding for an option title.
/// It lets downstream logic inspect how the option label itself was represented by the model.
public struct OptionEmbedding: Codable, Equatable, Sendable {
  public var optionIndex: Int
  public var title: String
  public var embedding: EmbeddingVector

  public init(optionIndex: Int, title: String, embedding: EmbeddingVector) {
    self.optionIndex = optionIndex
    self.title = title
    self.embedding = embedding
  }
}

/// Embedding for one pro or con reason.
/// It preserves the vector and reason context used to produce attribute matches.
public struct ReasonEmbedding: Codable, Equatable, Sendable {
  public var reasonID: UUID
  public var optionIndex: Int
  public var polarity: ReasonPolarity
  public var text: String
  public var embedding: EmbeddingVector

  public init(
    reasonID: UUID,
    optionIndex: Int,
    polarity: ReasonPolarity,
    text: String,
    embedding: EmbeddingVector
  ) {
    self.reasonID = reasonID
    self.optionIndex = optionIndex
    self.polarity = polarity
    self.text = text
    self.embedding = embedding
  }
}
