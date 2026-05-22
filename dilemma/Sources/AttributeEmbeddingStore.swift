import Accelerate
import Foundation

struct AttributeEmbeddingStore: Sendable {
  let metadata: AttributeAssetMetadata
  let flatVectors: [Float]
  private let proIndices: [Int]
  private let conIndices: [Int]

  var dimension: Int { metadata.model.embeddingDimension }
  var vectors: [[Float]] { flatVectors.chunked(size: dimension) }

  init(metadata: AttributeAssetMetadata, vectors: [[Float]]) {
    self.init(metadata: metadata, flatVectors: vectors.flatMap { $0 })
  }

  private init(metadata: AttributeAssetMetadata, flatVectors: [Float]) {
    self.metadata = metadata
    self.flatVectors = flatVectors
    self.proIndices = metadata.attributes.indices.filter {
      metadata.attributes[$0].direction == .pro
    }
    self.conIndices = metadata.attributes.indices.filter {
      metadata.attributes[$0].direction == .con
    }
  }

  static func load(
    resourceName: String,
    bundle: Bundle = .main,
    subdirectory: String? = "Attributes"
  ) throws -> AttributeEmbeddingStore {
    guard let metadataURL = bundle.url(
      forResource: resourceName,
      withExtension: "json",
      subdirectory: subdirectory
    ) else {
      throw StoreError.missingResource("\(resourceName).json")
    }

    let metadata = try JSONDecoder.bhatia.decode(
      AttributeAssetMetadata.self,
      from: Data(contentsOf: metadataURL)
    )

    guard let vectorURL = bundle.url(
      forResource: metadata.vectors.file,
      withExtension: nil,
      subdirectory: subdirectory
    ) else {
      throw StoreError.missingResource(metadata.vectors.file)
    }

    let flat = try loadFloat16VectorFile(
      at: vectorURL,
      expectedCount: metadata.attributes.count * metadata.model.embeddingDimension
    )
    return AttributeEmbeddingStore(metadata: metadata, flatVectors: flat)
  }

  func directionIndices(for direction: AttributeDirection) -> [Int] {
    direction == .pro ? proIndices : conIndices
  }

  func dot(normalizedReasonVector: [Float], attributeIndex: Int) -> Float {
    let offset = attributeIndex * dimension
    return normalizedReasonVector.withUnsafeBufferPointer { reasonBuffer in
      flatVectors.withUnsafeBufferPointer { attributeBuffer in
        guard
          let reasonBase = reasonBuffer.baseAddress,
          let attributeBase = attributeBuffer.baseAddress
        else { return 0 }

        // Dot product is the scoring hot path: 12 reasons x 207
        // direction-filtered vectors. vDSP keeps Debug simulator
        // latency close to device-realistic expectations.
        var total = Float(0)
        vDSP_dotpr(
          reasonBase,
          1,
          attributeBase.advanced(by: offset),
          1,
          &total,
          vDSP_Length(dimension)
        )
        return total
      }
    }
  }

  enum StoreError: LocalizedError {
    case missingResource(String)
    case invalidVectorByteCount(actual: Int, expectedValues: Int)

    var errorDescription: String? {
      switch self {
      case .missingResource(let name):
        "Missing resource: \(name)"
      case .invalidVectorByteCount(let actual, let expectedValues):
        "Invalid F16 vector byte count \(actual), expected \(expectedValues * 2)"
      }
    }
  }
}

func loadFloat16VectorFile(at url: URL, expectedCount: Int) throws -> [Float] {
  let data = try Data(contentsOf: url)
  guard data.count == expectedCount * 2 else {
    throw AttributeEmbeddingStore.StoreError.invalidVectorByteCount(
      actual: data.count,
      expectedValues: expectedCount
    )
  }

  // The offline generator writes row-major Float16 values as little-endian
  // bytes. Reading manually avoids alignment assumptions for Data storage.
  var values = [Float]()
  values.reserveCapacity(expectedCount)
  for offset in stride(from: 0, to: data.count, by: 2) {
    let bits = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    values.append(Float(Float16(bitPattern: bits)))
  }
  return values
}

extension Array {
  func chunked(size: Int) -> [[Element]] {
    stride(from: 0, to: count, by: size).map { start in
      Array(self[start..<Swift.min(start + size, count)])
    }
  }
}

extension JSONDecoder {
  static var bhatia: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }
}
