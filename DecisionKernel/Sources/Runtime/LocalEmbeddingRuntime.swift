import CoreML
import Embeddings
import Foundation

struct LocalEmbeddingRuntime {
  let bundle: Bundle
  let modelResourceName: String

  /// Loads a bundled BERT-compatible sentence embedding model without network fallback.
  func loadModel() async throws -> LoadedEmbeddingModel {
    // Runtime is deliberately bundled-only: no hubRepoId fallback, no
    // network fetch, and no API call from the app path.
    guard let url = bundle.url(
      forResource: modelResourceName,
      withExtension: nil,
      subdirectory: "Models"
    ) else {
      throw RuntimeError.missingBundledModel(modelResourceName)
    }

    return LoadedEmbeddingModel(
      modelBundle: try await Bert.loadModelBundle(
        from: url,
        loadConfig: LoadConfig(tokenizerConfig: TokenizerConfig())
      )
    )
  }

  enum RuntimeError: LocalizedError {
    case missingBundledModel(String)

    /// Human-readable runtime loading error description.
    var errorDescription: String? {
      switch self {
      case .missingBundledModel(let name):
        "Missing bundled model folder: \(name)"
      }
    }
  }
}

struct LoadedEmbeddingModel {
  fileprivate let modelBundle: Bert.ModelBundle

  /// Embeds texts with masked mean pooling and returns L2-normalized sentence vectors.
  func embed(texts: [String]) async throws -> [[Float]] {
    let tokenized = try modelBundle.tokenizer.tokenizeTextsPaddingToLongest(
      texts,
      padTokenId: 0,
      maxLength: 512
    )
    let inputIds = MLTensor(shape: tokenized.shape, scalars: tokenized.tokens)
    let attentionMask = MLTensor(shape: tokenized.shape, scalars: tokenized.attentionMask)
    let output = modelBundle.model(inputIds: inputIds, attentionMask: attentionMask)

    // SentenceTransformers MiniLM uses masked mean pooling over token
    // embeddings. swift-embeddings' convenience encode currently returns
    // CLS, so the prototype pools explicitly for parity with Python assets.
    let expandedMask = attentionMask.expandingShape(at: 2)
    let masked = output.sequenceOutput * expandedMask
    let sums = masked.sum(alongAxes: 1, keepRank: false)
    let counts = attentionMask.sum(alongAxes: 1, keepRank: true)
    let pooled = sums / counts
    let flat = await pooled.cast(to: Float.self).shapedArray(of: Float.self).scalars

    guard !texts.isEmpty else { return [] }
    let dimension = flat.count / texts.count
    return stride(from: 0, to: flat.count, by: dimension).map { start in
      AttributeScoring.normalize(Array(flat[start..<start + dimension]))
    }
  }
}
