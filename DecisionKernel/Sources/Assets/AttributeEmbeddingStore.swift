import Accelerate
import Foundation
import SQLite3

struct AttributeEmbeddingStore: Sendable {
  let metadata: AttributeAssetMetadata
  let attributeDefinitions: [AttributeDefinition]
  let clusters: [ClusterMetadata]
  let flatVectors: [Float]
  private let proIndices: [Int]
  private let conIndices: [Int]
  private let attributeOrdinalByRowIndex: [Int]
  private let clusterByID: [Int: ClusterMetadata]

  var dimension: Int { metadata.model.embeddingDimension }
  var assetVersion: Int { metadata.assetVersion }
  var sourceDOI: String { metadata.sourceDoi }
  var attributeCount: Int { attributeDefinitions.count }
  var vectors: [[Float]] { flatVectors.chunked(size: dimension) }

  init(metadata: AttributeAssetMetadata, vectors: [[Float]]) {
    self.init(metadata: metadata, flatVectors: vectors.flatMap { $0 })
  }

  private init(
    metadata: AttributeAssetMetadata,
    flatVectors: [Float],
    attributeDefinitions: [AttributeDefinition]? = nil,
    clusters: [ClusterMetadata] = []
  ) {
    self.metadata = metadata
    self.flatVectors = flatVectors
    self.attributeDefinitions = attributeDefinitions ?? Self.makeAttributeDefinitions(
      from: metadata.attributes
    )
    self.clusters = clusters
    self.proIndices = metadata.attributes.indices.filter {
      metadata.attributes[$0].direction == .pro
    }
    self.conIndices = metadata.attributes.indices.filter {
      metadata.attributes[$0].direction == .con
    }
    self.attributeOrdinalByRowIndex = Self.makeAttributeOrdinalMap(
      attributes: metadata.attributes,
      definitions: self.attributeDefinitions
    )
    self.clusterByID = Dictionary(uniqueKeysWithValues: clusters.map { ($0.clusterID, $0) })
  }

  static func load(
    resourceName: String,
    bundle: Bundle = DecisionKernelResourceBundle.bundle,
    subdirectory: String? = "Attributes"
  ) throws -> AttributeEmbeddingStore {
    guard let metadataURL = bundle.url(
      forResource: resourceName,
      withExtension: "json",
      subdirectory: subdirectory
    ) else {
      throw StoreError.missingResource("\(resourceName).json")
    }

    let metadata = try JSONDecoder.attributeAsset.decode(
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

  static func loadSQLite(
    resourceName: String = "DilemmaAssets",
    bundle: Bundle = DecisionKernelResourceBundle.bundle,
    subdirectory: String? = "Attributes"
  ) throws -> AttributeEmbeddingStore {
    guard let sqliteURL = bundle.url(
      forResource: resourceName,
      withExtension: "sqlite",
      subdirectory: subdirectory
    ) else {
      throw StoreError.missingResource("\(resourceName).sqlite")
    }

    let database = try SQLiteReadOnlyDatabase(url: sqliteURL)
    let metadataRows = try database.metadataRows()
    let dimension = try metadataRows.requiredInt("embedding_dimension")
    let modelID = try metadataRows.requiredString("model_id")
    let modelShortName = try metadataRows.requiredString("model_short_name")
    let assetVersion = try metadataRows.requiredInt("asset_version")
    let sourceDOI = try metadataRows.requiredString("source_doi")
    let clusters = try database.clusters()
    let attributeDefinitions = try database.attributeDefinitions()
    let directionRows = try database.attributeDirections()
    let flatVectors = try database.embeddingVectors(expectedDimension: dimension).flatMap { $0 }

    let metadata = AttributeAssetMetadata(
      assetVersion: assetVersion,
      sourceDoi: sourceDOI,
      model: AttributeAssetModel(
        id: modelID,
        shortName: modelShortName,
        embeddingDimension: dimension
      ),
      vectors: AttributeVectorFile(
        file: "\(resourceName).sqlite",
        dtype: "float32",
        layout: "sqlite-row-major",
        normalized: true
      ),
      attributes: directionRows
    )

    return AttributeEmbeddingStore(
      metadata: metadata,
      flatVectors: flatVectors,
      attributeDefinitions: attributeDefinitions,
      clusters: clusters
    )
  }

  func directionIndices(for direction: AttributeDirection) -> [Int] {
    direction == .pro ? proIndices : conIndices
  }

  func attributeOrdinal(forRowIndex rowIndex: Int) -> Int? {
    guard rowIndex >= 0 && rowIndex < attributeOrdinalByRowIndex.count else { return nil }
    return attributeOrdinalByRowIndex[rowIndex]
  }

  func cluster(for clusterID: Int?) -> ClusterMetadata? {
    guard let clusterID else { return nil }
    return clusterByID[clusterID]
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
    case invalidSQLiteAsset(String)

    var errorDescription: String? {
      switch self {
      case .missingResource(let name):
        "Missing resource: \(name)"
      case .invalidVectorByteCount(let actual, let expectedValues):
        "Invalid F16 vector byte count \(actual), expected \(expectedValues * 2)"
      case .invalidSQLiteAsset(let message):
        "Invalid SQLite asset: \(message)"
      }
    }
  }

  private static func makeAttributeDefinitions(
    from attributes: [AttributeMetadata]
  ) -> [AttributeDefinition] {
    var seen: [String: Int] = [:]
    var definitions = [AttributeDefinition]()
    for attribute in attributes {
      if seen[attribute.name] == nil {
        let attributeID = attribute.attributeID ?? definitions.count + 1
        seen[attribute.name] = attributeID
        definitions.append(
          AttributeDefinition(
            attributeID: attributeID,
            name: attribute.name,
            source: attribute.source.trimmingCharacters(in: .whitespacesAndNewlines),
            clusterID: attribute.clusterID
          )
        )
      }
    }
    return definitions.sorted { $0.attributeID < $1.attributeID }
  }

  private static func makeAttributeOrdinalMap(
    attributes: [AttributeMetadata],
    definitions: [AttributeDefinition]
  ) -> [Int] {
    let ordinalByID = Dictionary(uniqueKeysWithValues: definitions.enumerated().map {
      ($0.element.attributeID, $0.offset)
    })
    var ordinalByName: [String: Int] = [:]
    for (offset, definition) in definitions.enumerated() {
      ordinalByName[definition.name] = offset
    }

    return attributes.map { attribute in
      if let attributeID = attribute.attributeID, let ordinal = ordinalByID[attributeID] {
        return ordinal
      }
      return ordinalByName[attribute.name] ?? 0
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
  static var attributeAsset: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }
}

private final class SQLiteReadOnlyDatabase {
  private let handle: OpaquePointer

  init(url: URL) throws {
    var database: OpaquePointer?
    let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
    guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK, let database else {
      let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
      if let database {
        sqlite3_close(database)
      }
      throw AttributeEmbeddingStore.StoreError.invalidSQLiteAsset(message)
    }
    self.handle = database
  }

  deinit {
    sqlite3_close(handle)
  }

  func metadataRows() throws -> [String: String] {
    try query("SELECT key, value FROM asset_metadata") { statement in
      (
        String(cString: sqlite3_column_text(statement, 0)),
        String(cString: sqlite3_column_text(statement, 1))
      )
    }.reduce(into: [:]) { output, row in
      output[row.0] = row.1
    }
  }

  func clusters() throws -> [ClusterMetadata] {
    try query(
      """
      SELECT cluster_id, label, representative_attribute_name, sort_order
      FROM clusters
      ORDER BY sort_order
      """
    ) { statement in
      ClusterMetadata(
        clusterID: Int(sqlite3_column_int(statement, 0)),
        label: String(cString: sqlite3_column_text(statement, 1)),
        representativeAttributeName: String(cString: sqlite3_column_text(statement, 2)),
        sortOrder: Int(sqlite3_column_int(statement, 3))
      )
    }
  }

  func attributeDefinitions() throws -> [AttributeDefinition] {
    try query(
      """
      SELECT a.attribute_id, a.name, a.source, ac.cluster_id
      FROM attributes a
      LEFT JOIN attribute_cluster ac ON ac.attribute_id = a.attribute_id
      ORDER BY a.attribute_id
      """
    ) { statement in
      AttributeDefinition(
        attributeID: Int(sqlite3_column_int(statement, 0)),
        name: String(cString: sqlite3_column_text(statement, 1)),
        source: String(cString: sqlite3_column_text(statement, 2)),
        clusterID: sqlite3_column_type(statement, 3) == SQLITE_NULL
          ? nil
          : Int(sqlite3_column_int(statement, 3))
      )
    }
  }

  func attributeDirections() throws -> [AttributeMetadata] {
    try query(
      """
      SELECT
        ad.row_index,
        a.attribute_id,
        a.name,
        a.source,
        ad.direction,
        ad.vector_offset,
        ac.cluster_id
      FROM attribute_directions ad
      INNER JOIN attributes a ON a.attribute_id = ad.attribute_id
      LEFT JOIN attribute_cluster ac ON ac.attribute_id = a.attribute_id
      ORDER BY ad.row_index
      """
    ) { statement in
      let direction = String(cString: sqlite3_column_text(statement, 4))
      guard let attributeDirection = AttributeDirection(rawValue: direction) else {
        throw AttributeEmbeddingStore.StoreError.invalidSQLiteAsset(
          "Unknown attribute direction \(direction)"
        )
      }

      return AttributeMetadata(
        attributeID: Int(sqlite3_column_int(statement, 1)),
        rowIndex: Int(sqlite3_column_int(statement, 0)),
        name: String(cString: sqlite3_column_text(statement, 2)),
        source: String(cString: sqlite3_column_text(statement, 3)),
        direction: attributeDirection,
        vectorOffset: Int(sqlite3_column_int(statement, 5)),
        clusterID: sqlite3_column_type(statement, 6) == SQLITE_NULL
          ? nil
          : Int(sqlite3_column_int(statement, 6))
      )
    }
  }

  func embeddingVectors(expectedDimension: Int) throws -> [[Float]] {
    try query(
      """
      SELECT ae.embedding
      FROM attribute_embeddings ae
      INNER JOIN attribute_directions ad ON ad.direction_id = ae.direction_id
      ORDER BY ad.row_index
      """
    ) { statement in
      guard let bytes = sqlite3_column_blob(statement, 0) else {
        throw AttributeEmbeddingStore.StoreError.invalidSQLiteAsset("Missing embedding blob")
      }
      let byteCount = Int(sqlite3_column_bytes(statement, 0))
      guard byteCount == expectedDimension * 4 else {
        throw AttributeEmbeddingStore.StoreError.invalidSQLiteAsset(
          "Embedding blob has \(byteCount) bytes, expected \(expectedDimension * 4)"
        )
      }
      let data = Data(bytes: bytes, count: byteCount)
      return data.littleEndianFloat32Values()
    }
  }

  private func query<T>(
    _ sql: String,
    map: (OpaquePointer) throws -> T
  ) throws -> [T] {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      throw AttributeEmbeddingStore.StoreError.invalidSQLiteAsset(
        String(cString: sqlite3_errmsg(handle))
      )
    }
    defer { sqlite3_finalize(statement) }

    var rows = [T]()
    while true {
      let result = sqlite3_step(statement)
      if result == SQLITE_ROW {
        rows.append(try map(statement))
      } else if result == SQLITE_DONE {
        return rows
      } else {
        throw AttributeEmbeddingStore.StoreError.invalidSQLiteAsset(
          String(cString: sqlite3_errmsg(handle))
        )
      }
    }
  }
}

private extension Dictionary where Key == String, Value == String {
  func requiredString(_ key: String) throws -> String {
    guard let value = self[key] else {
      throw AttributeEmbeddingStore.StoreError.invalidSQLiteAsset("Missing metadata \(key)")
    }
    return value
  }

  func requiredInt(_ key: String) throws -> Int {
    let value = try requiredString(key)
    guard let intValue = Int(value) else {
      throw AttributeEmbeddingStore.StoreError.invalidSQLiteAsset(
        "Metadata \(key) is not an integer: \(value)"
      )
    }
    return intValue
  }
}

private extension Data {
  func littleEndianFloat32Values() -> [Float] {
    var values = [Float]()
    values.reserveCapacity(count / 4)
    for offset in stride(from: 0, to: count, by: 4) {
      let bits = UInt32(self[offset])
        | (UInt32(self[offset + 1]) << 8)
        | (UInt32(self[offset + 2]) << 16)
        | (UInt32(self[offset + 3]) << 24)
      values.append(Float(bitPattern: bits))
    }
    return values
  }
}
