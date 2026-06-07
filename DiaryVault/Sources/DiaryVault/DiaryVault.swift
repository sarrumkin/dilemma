import Foundation
import SQLite3

public final class DiaryVault: @unchecked Sendable {
  public let databaseURL: URL
  // SQLite access and the cached handle are isolated through this serial queue.
  private let queue = DispatchQueue(label: "com.local.dilemma.diary-vault")
  private var database: SQLiteDatabase?

  public init(
    databaseURL: URL = DiaryVault.defaultDatabaseURL()
  ) {
    self.databaseURL = databaseURL
  }

  deinit {
    database?.close()
  }

  public static func defaultDatabaseURL() -> URL {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return support
      .appendingPathComponent("Dilemma", isDirectory: true)
      .appendingPathComponent("DiaryVault.sqlite")
  }

  public func prepare() throws {
    try queue.sync {
      let database = try openDatabase()
      try database.execute(Self.schemaSQL)
      try ensureAnalysisSchemaColumns(database: database)
    }
  }

  public func saveEntry(_ entry: StoredDiaryEntry) throws {
    try queue.sync {
      let database = try openDatabase()
      try database.transaction {
        try database.execute(
          """
          INSERT INTO diary_entry(id, raw_text, created_at, updated_at)
          VALUES (?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            raw_text = excluded.raw_text,
            updated_at = excluded.updated_at
          """,
          [
            .text(entry.id.uuidString),
            .text(entry.rawText),
            .real(entry.createdAt.timeIntervalSince1970),
            .real(entry.updatedAt.timeIntervalSince1970),
          ]
        )
        try database.execute("DELETE FROM decision_option WHERE entry_id = ?", [.text(entry.id.uuidString)])

        for option in entry.options.sorted(by: { $0.index < $1.index }) {
          try database.execute(
            """
            INSERT INTO decision_option(id, entry_id, option_index, title, sort_order)
            VALUES (?, ?, ?, ?, ?)
            """,
            [
              .text(option.id.uuidString),
              .text(entry.id.uuidString),
              .integer(option.index),
              .text(option.title),
              .integer(option.index),
            ]
          )

          for (reasonOffset, reason) in option.reasons.enumerated() {
            try database.execute(
              """
              INSERT INTO reason(id, option_id, entry_id, polarity, text, sort_order)
              VALUES (?, ?, ?, ?, ?, ?)
              """,
              [
                .text(reason.id.uuidString),
                .text(option.id.uuidString),
                .text(entry.id.uuidString),
                .text(reason.polarity.rawValue),
                .text(reason.text),
                .integer(reasonOffset),
              ]
            )
          }
        }
      }
    }
  }

  public func entries() throws -> [StoredDiaryEntry] {
    try queue.sync {
      let database = try openDatabase()
      let rows = try database.query(
        """
        SELECT id, raw_text, created_at, updated_at
        FROM diary_entry
        ORDER BY updated_at DESC
        """
      )
      return try rows.map { row in
        try entry(from: row, database: database)
      }
    }
  }

  public func snapshot() throws -> StoredDiarySnapshot {
    try queue.sync {
      let database = try openDatabase()
      let entryRows = try database.query(
        """
        SELECT id, raw_text, created_at, updated_at
        FROM diary_entry
        ORDER BY updated_at DESC
        """
      )
      guard !entryRows.isEmpty else {
        return StoredDiarySnapshot(entries: [], latestAnalyses: [:])
      }

      let entryIDs = try entryRows.map { try UUID.parse($0.string(0)) }
      let optionsByEntryID = try optionsByEntryID(for: entryIDs, database: database)
      let entries = try entryRows.map { row in
        let entryID = try UUID.parse(row.string(0))
        return StoredDiaryEntry(
          id: entryID,
          rawText: try row.string(1),
          options: optionsByEntryID[entryID] ?? [],
          createdAt: Date(timeIntervalSince1970: try row.double(2)),
          updatedAt: Date(timeIntervalSince1970: try row.double(3))
        )
      }

      return StoredDiarySnapshot(
        entries: entries,
        latestAnalyses: try latestAnalysesByEntryID(for: entryIDs, database: database)
      )
    }
  }

  public func entry(id: UUID) throws -> StoredDiaryEntry {
    try queue.sync {
      let database = try openDatabase()
      let rows = try database.query(
        """
        SELECT id, raw_text, created_at, updated_at
        FROM diary_entry
        WHERE id = ?
        """,
        [.text(id.uuidString)]
      )
      guard let row = rows.first else { throw DiaryVaultError.notFound }
      return try entry(from: row, database: database)
    }
  }

  public func deleteEntry(id: UUID) throws {
    try queue.sync {
      let database = try openDatabase()
      try database.execute(
        "DELETE FROM diary_entry WHERE id = ?",
        [.text(id.uuidString)]
      )
    }
  }

  public func saveAnalysis(_ analysis: StoredDecisionAnalysis) throws {
    try queue.sync {
      let database = try openDatabase()
      try database.transaction {
        try database.execute(
          """
          INSERT INTO analysis_result(
            id, entry_id, created_at, schema_version, asset_version, model_id, source_doi
          )
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            created_at = excluded.created_at,
            schema_version = excluded.schema_version,
            asset_version = excluded.asset_version,
            model_id = excluded.model_id,
            source_doi = excluded.source_doi
          """,
          [
            .text(analysis.id.uuidString),
            .text(analysis.entryID.uuidString),
            .real(analysis.createdAt.timeIntervalSince1970),
            .integer(analysis.schemaVersion),
            .integer(analysis.assetVersion),
            .text(analysis.modelID),
            .text(analysis.sourceDOI),
          ]
        )
        try deleteAnalysisChildren(analysisID: analysis.id, database: database)
        try saveAnalysisChildren(analysis, database: database)
      }
    }
  }

  public func analyses(entryID: UUID? = nil) throws -> [StoredDecisionAnalysis] {
    try queue.sync {
      let database = try openDatabase()
      let sql: String
      let bindings: [SQLiteValue]
      if let entryID {
        sql = """
        SELECT id, entry_id, created_at, schema_version, asset_version, model_id, source_doi
        FROM analysis_result
        WHERE entry_id = ?
        ORDER BY created_at DESC
        """
        bindings = [.text(entryID.uuidString)]
      } else {
        sql = """
        SELECT id, entry_id, created_at, schema_version, asset_version, model_id, source_doi
        FROM analysis_result
        ORDER BY created_at DESC
        """
        bindings = []
      }

      return try database.query(sql, bindings).map { row in
        try analysis(from: row, database: database)
      }
    }
  }

  public func saveFeedback(_ feedback: StoredFeedback) throws {
    try queue.sync {
      let database = try openDatabase()
      try database.transaction {
        guard let chosenOptionIndex = feedback.chosenOptionIndex else {
          try deleteFeedback(
            entryID: feedback.entryID,
            analysisID: feedback.analysisID,
            database: database
          )
          return
        }

        let existingID = try existingFeedbackID(
          entryID: feedback.entryID,
          analysisID: feedback.analysisID,
          database: database
        )

        if let existingID {
          try database.execute(
            """
            UPDATE feedback
            SET conflict_was_useful = ?,
                corrected_cluster_id = ?,
                corrected_attribute_name = ?,
                chosen_option_index = ?,
                note = ?,
                created_at = ?
            WHERE id = ?
            """,
            [
              .integer(feedback.conflictWasUseful ? 1 : 0),
              feedback.correctedClusterID.map(SQLiteValue.integer) ?? .null,
              feedback.correctedAttributeName.map(SQLiteValue.text) ?? .null,
              .integer(chosenOptionIndex),
              .text(feedback.note),
              .real(feedback.createdAt.timeIntervalSince1970),
              .text(existingID.uuidString),
            ]
          )
        } else {
          try database.execute(
            """
            INSERT INTO feedback(
              id, entry_id, analysis_id, conflict_was_useful, corrected_cluster_id,
              corrected_attribute_name, chosen_option_index, note, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [
              .text(feedback.id.uuidString),
              .text(feedback.entryID.uuidString),
              feedback.analysisID.map { .text($0.uuidString) } ?? .null,
              .integer(feedback.conflictWasUseful ? 1 : 0),
              feedback.correctedClusterID.map(SQLiteValue.integer) ?? .null,
              feedback.correctedAttributeName.map(SQLiteValue.text) ?? .null,
              .integer(chosenOptionIndex),
              .text(feedback.note),
              .real(feedback.createdAt.timeIntervalSince1970),
            ]
          )
        }
      }
    }
  }

  public func feedback(entryID: UUID, analysisID: UUID?) throws -> StoredFeedback? {
    try queue.sync {
      let database = try openDatabase()
      let sql: String
      let bindings: [SQLiteValue]
      if let analysisID {
        sql = """
        SELECT id, entry_id, analysis_id, conflict_was_useful, corrected_cluster_id,
               corrected_attribute_name, chosen_option_index, note, created_at
        FROM feedback
        WHERE entry_id = ? AND analysis_id = ?
          AND chosen_option_index IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 1
        """
        bindings = [.text(entryID.uuidString), .text(analysisID.uuidString)]
      } else {
        sql = """
        SELECT id, entry_id, analysis_id, conflict_was_useful, corrected_cluster_id,
               corrected_attribute_name, chosen_option_index, note, created_at
        FROM feedback
        WHERE entry_id = ? AND analysis_id IS NULL
          AND chosen_option_index IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 1
        """
        bindings = [.text(entryID.uuidString)]
      }

      return try database.query(sql, bindings).first.map { try feedbackRecord(from: $0) }
    }
  }

  public func feedback(entryID: UUID? = nil) throws -> [StoredFeedback] {
    try queue.sync {
      let database = try openDatabase()
      let sql: String
      let bindings: [SQLiteValue]
      if let entryID {
        sql = """
        SELECT id, entry_id, analysis_id, conflict_was_useful, corrected_cluster_id,
               corrected_attribute_name, chosen_option_index, note, created_at
        FROM feedback
        WHERE entry_id = ?
          AND chosen_option_index IS NOT NULL
        ORDER BY created_at DESC
        """
        bindings = [.text(entryID.uuidString)]
      } else {
        sql = """
        SELECT id, entry_id, analysis_id, conflict_was_useful, corrected_cluster_id,
               corrected_attribute_name, chosen_option_index, note, created_at
        FROM feedback
        WHERE chosen_option_index IS NOT NULL
        ORDER BY created_at DESC
        """
        bindings = []
      }

      return try database.query(sql, bindings).map { try feedbackRecord(from: $0) }
    }
  }

  public func statistics() throws -> StoredPreferenceStatistics {
    try queue.sync {
      let database = try openDatabase()
      let entryCount = try database.int("SELECT COUNT(*) FROM diary_entry")
      let feedbackCount = try database.int("SELECT COUNT(*) FROM feedback WHERE chosen_option_index IS NOT NULL")
      let accepted = try database.int(
        "SELECT COUNT(*) FROM feedback WHERE conflict_was_useful = 1 AND chosen_option_index IS NOT NULL"
      )
      let rejected = try database.int(
        "SELECT COUNT(*) FROM feedback WHERE conflict_was_useful = 0 AND chosen_option_index IS NOT NULL"
      )
      let chosenClusterDilemmaCount = try database.int(
        """
        SELECT COUNT(DISTINCT f.id)
        FROM feedback f
        JOIN cluster_profile chosen
          ON chosen.analysis_id = f.analysis_id
         AND chosen.option_index = f.chosen_option_index
        WHERE f.chosen_option_index IS NOT NULL
        """
      )
      let clusterRows = try database.query(
        """
        SELECT chosen.cluster_id, chosen.label, COUNT(*) AS count
        FROM feedback f
        JOIN cluster_profile chosen
          ON chosen.analysis_id = f.analysis_id
         AND chosen.option_index = f.chosen_option_index
        LEFT JOIN cluster_profile other
          ON other.analysis_id = chosen.analysis_id
         AND other.cluster_id = chosen.cluster_id
         AND other.option_index != chosen.option_index
        WHERE f.chosen_option_index IS NOT NULL
          AND chosen.score > 0
          AND chosen.score - COALESCE(other.score, 0) > 0
          AND NOT EXISTS (
            SELECT 1
            FROM cluster_profile challenger
            LEFT JOIN cluster_profile challenger_other
              ON challenger_other.analysis_id = challenger.analysis_id
             AND challenger_other.cluster_id = challenger.cluster_id
             AND challenger_other.option_index != challenger.option_index
            WHERE challenger.analysis_id = chosen.analysis_id
              AND challenger.option_index = chosen.option_index
              AND challenger.score > 0
              AND challenger.score - COALESCE(challenger_other.score, 0) > 0
              AND (
                challenger.score - COALESCE(challenger_other.score, 0)
                  > chosen.score - COALESCE(other.score, 0)
                OR (
                  challenger.score - COALESCE(challenger_other.score, 0)
                    = chosen.score - COALESCE(other.score, 0)
                  AND (
                    challenger.score > chosen.score
                    OR (
                      challenger.score = chosen.score
                      AND challenger.cluster_id < chosen.cluster_id
                    )
                  )
                )
              )
          )
        GROUP BY chosen.cluster_id, chosen.label
        ORDER BY count DESC, chosen.cluster_id ASC
        LIMIT 10
        """
      )
      let chosenRows = try database.query(
        """
        SELECT chosen_option_index, COUNT(*)
        FROM feedback
        WHERE chosen_option_index IS NOT NULL
        GROUP BY chosen_option_index
        ORDER BY chosen_option_index
        """
      )

      return StoredPreferenceStatistics(
        entryCount: entryCount,
        feedbackCount: feedbackCount,
        acceptedConflictCount: accepted,
        rejectedConflictCount: rejected,
        mostFrequentClusters: try clusterRows.map {
          StoredClusterFrequency(
            clusterID: try $0.int(0),
            label: try $0.string(1),
            count: try $0.int(2)
          )
        },
        chosenOptionCounts: Dictionary(uniqueKeysWithValues: try chosenRows.map {
          (try $0.int(0), try $0.int(1))
        }),
        chosenClusterDilemmaCount: chosenClusterDilemmaCount
      )
    }
  }

  public func exportData() throws -> StoredDiaryExport {
    StoredDiaryExport(
      entries: try entries(),
      analyses: try analyses(),
      feedback: try feedback()
    )
  }

  public func exportJSONData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(exportData())
  }

  public func deleteAllData(removeDatabaseFile: Bool = true) throws {
    try queue.sync {
      if let database {
        try database.execute(
          """
          DELETE FROM feedback;
          DELETE FROM cluster_profile;
          DELETE FROM attribute_match;
          DELETE FROM analysis_warning;
          DELETE FROM analysis_metrics;
          DELETE FROM analysis_option_cluster_score;
          DELETE FROM analysis_option_attribute_score;
          DELETE FROM analysis_reason_top_match;
          DELETE FROM analysis_reason_match;
          DELETE FROM analysis_embedding;
          DELETE FROM analysis_embedding_input;
          DELETE FROM analysis_cluster_method_metadata;
          DELETE FROM analysis_asset_metadata;
          DELETE FROM analysis_model_metadata;
          DELETE FROM analysis_result;
          DELETE FROM reason;
          DELETE FROM decision_option;
          DELETE FROM diary_entry;
          """
        )
        database.close()
        self.database = nil
      }
      if removeDatabaseFile, FileManager.default.fileExists(atPath: databaseURL.path) {
        try FileManager.default.removeItem(at: databaseURL)
      }
    }
  }

  private func openDatabase() throws -> SQLiteDatabase {
    if let database {
      return database
    }
    try FileManager.default.createDirectory(
      at: databaseURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let database = try SQLiteDatabase(url: databaseURL)
    self.database = database
    return database
  }

  private func ensureAnalysisSchemaColumns(database: SQLiteDatabase) throws {
    let rows = try database.query("PRAGMA table_info(analysis_result)")
    let columnNames = try Set(rows.map { try $0.string(1) })
    if !columnNames.contains("schema_version") {
      try database.execute("ALTER TABLE analysis_result ADD COLUMN schema_version INTEGER NOT NULL DEFAULT 1")
    }
  }

  private func optionsByEntryID(
    for entryIDs: [UUID],
    database: SQLiteDatabase
  ) throws -> [UUID: [StoredDiaryOption]] {
    guard !entryIDs.isEmpty else { return [:] }
    let optionRows = try database.query(
      """
      SELECT id, entry_id, option_index, title
      FROM decision_option
      WHERE entry_id IN (\(Self.placeholders(count: entryIDs.count)))
      ORDER BY entry_id, sort_order
      """,
      Self.bindings(for: entryIDs)
    )
    guard !optionRows.isEmpty else { return [:] }

    let optionIDs = try optionRows.map { try UUID.parse($0.string(0)) }
    let reasonsByOptionID = try reasonsByOptionID(for: optionIDs, database: database)
    var optionsByEntryID: [UUID: [StoredDiaryOption]] = [:]
    for row in optionRows {
      let optionID = try UUID.parse(row.string(0))
      let entryID = try UUID.parse(row.string(1))
      optionsByEntryID[entryID, default: []].append(
        StoredDiaryOption(
          id: optionID,
          index: try row.int(2),
          title: try row.string(3),
          reasons: reasonsByOptionID[optionID] ?? []
        )
      )
    }
    return optionsByEntryID
  }

  private func reasonsByOptionID(
    for optionIDs: [UUID],
    database: SQLiteDatabase
  ) throws -> [UUID: [StoredDiaryReason]] {
    guard !optionIDs.isEmpty else { return [:] }
    let reasonRows = try database.query(
      """
      SELECT id, option_id, polarity, text
      FROM reason
      WHERE option_id IN (\(Self.placeholders(count: optionIDs.count)))
      ORDER BY option_id, sort_order
      """,
      Self.bindings(for: optionIDs)
    )

    var reasonsByOptionID: [UUID: [StoredDiaryReason]] = [:]
    for row in reasonRows {
      let polarityRaw = try row.string(2)
      guard let polarity = StoredDiaryReasonPolarity(rawValue: polarityRaw) else {
        throw DiaryVaultError.database("Unknown reason polarity \(polarityRaw)")
      }
      reasonsByOptionID[try UUID.parse(row.string(1)), default: []].append(
        StoredDiaryReason(
          id: try UUID.parse(row.string(0)),
          text: try row.string(3),
          polarity: polarity
        )
      )
    }
    return reasonsByOptionID
  }

  private func latestAnalysesByEntryID(
    for entryIDs: [UUID],
    database: SQLiteDatabase
  ) throws -> [UUID: StoredDecisionAnalysis] {
    guard !entryIDs.isEmpty else { return [:] }
    let rows = try database.query(
      """
      SELECT id, entry_id, created_at, schema_version, asset_version, model_id, source_doi
      FROM analysis_result
      WHERE entry_id IN (\(Self.placeholders(count: entryIDs.count)))
      ORDER BY entry_id, created_at DESC
      """,
      Self.bindings(for: entryIDs)
    )
    guard !rows.isEmpty else { return [:] }

    var latestRows = [SQLiteRow]()
    var seenEntryIDs = Set<UUID>()
    for row in rows {
      let entryID = try UUID.parse(row.string(1))
      guard !seenEntryIDs.contains(entryID) else { continue }
      seenEntryIDs.insert(entryID)
      latestRows.append(row)
    }

    var latestAnalyses: [UUID: StoredDecisionAnalysis] = [:]
    for row in latestRows {
      let entryID = try UUID.parse(row.string(1))
      latestAnalyses[entryID] = try analysis(from: row, database: database)
    }
    return latestAnalyses
  }

  private func attributeConflictsByAnalysisID(
    for analysisIDs: [UUID],
    database: SQLiteDatabase
  ) throws -> [UUID: [StoredAttributeConflict]] {
    guard !analysisIDs.isEmpty else { return [:] }
    let rows = try database.query(
      """
      SELECT analysis_id, id, attribute_name, option1_score, option2_score, difference, rank
      FROM attribute_match
      WHERE analysis_id IN (\(Self.placeholders(count: analysisIDs.count)))
      ORDER BY analysis_id, rank
      """,
      Self.bindings(for: analysisIDs)
    )

    var conflictsByAnalysisID: [UUID: [StoredAttributeConflict]] = [:]
    for row in rows {
      conflictsByAnalysisID[try UUID.parse(row.string(0)), default: []].append(
        StoredAttributeConflict(
          id: try UUID.parse(row.string(1)),
          attributeName: try row.string(2),
          option1Score: try row.double(3),
          option2Score: try row.double(4),
          difference: try row.double(5),
          rank: try row.int(6)
        )
      )
    }
    return conflictsByAnalysisID
  }

  private func clusterProfilesByAnalysisID(
    for analysisIDs: [UUID],
    database: SQLiteDatabase
  ) throws -> [UUID: [StoredClusterProfile]] {
    guard !analysisIDs.isEmpty else { return [:] }
    let rows = try database.query(
      """
      SELECT analysis_id, id, option_index, cluster_id, label, score
      FROM cluster_profile
      WHERE analysis_id IN (\(Self.placeholders(count: analysisIDs.count)))
      ORDER BY analysis_id, option_index, ABS(score) DESC
      """,
      Self.bindings(for: analysisIDs)
    )

    var clustersByAnalysisID: [UUID: [StoredClusterProfile]] = [:]
    for row in rows {
      clustersByAnalysisID[try UUID.parse(row.string(0)), default: []].append(
        StoredClusterProfile(
          id: try UUID.parse(row.string(1)),
          optionIndex: try row.int(2),
          clusterID: try row.int(3),
          label: try row.string(4),
          score: try row.double(5)
        )
      )
    }
    return clustersByAnalysisID
  }

  private static func placeholders(count: Int) -> String {
    Array(repeating: "?", count: count).joined(separator: ", ")
  }

  private static func bindings(for ids: [UUID]) -> [SQLiteValue] {
    ids.map { .text($0.uuidString) }
  }

  private static func floatBlob(_ values: [Float]) -> Data {
    var data = Data()
    data.reserveCapacity(values.count * MemoryLayout<UInt32>.size)
    for value in values {
      var bitPattern = value.bitPattern.littleEndian
      withUnsafeBytes(of: &bitPattern) { data.append(contentsOf: $0) }
    }
    return data
  }

  private static func floats(from data: Data) throws -> [Float] {
    guard data.count % MemoryLayout<UInt32>.size == 0 else {
      throw DiaryVaultError.database("Invalid Float32 blob byte count \(data.count).")
    }
    return try stride(from: 0, to: data.count, by: MemoryLayout<UInt32>.size).map { offset in
      let end = offset + MemoryLayout<UInt32>.size
      var bitPattern: UInt32 = 0
      withUnsafeMutableBytes(of: &bitPattern) { buffer in
        data.copyBytes(to: buffer, from: offset..<end)
      }
      return Float(bitPattern: UInt32(littleEndian: bitPattern))
    }
  }

  private func entry(from row: SQLiteRow, database: SQLiteDatabase) throws -> StoredDiaryEntry {
    let entryID = try UUID.parse(row.string(0))
    let optionRows = try database.query(
      """
      SELECT id, option_index, title
      FROM decision_option
      WHERE entry_id = ?
      ORDER BY sort_order
      """,
      [.text(entryID.uuidString)]
    )

    let options = try optionRows.map { optionRow in
      let optionID = try UUID.parse(optionRow.string(0))
      let reasonRows = try database.query(
        """
        SELECT id, polarity, text
        FROM reason
        WHERE option_id = ?
        ORDER BY sort_order
        """,
        [.text(optionID.uuidString)]
      )
      return StoredDiaryOption(
        id: optionID,
        index: try optionRow.int(1),
        title: try optionRow.string(2),
        reasons: try reasonRows.map { reasonRow in
          let polarityRaw = try reasonRow.string(1)
          guard let polarity = StoredDiaryReasonPolarity(rawValue: polarityRaw) else {
            throw DiaryVaultError.database("Unknown reason polarity \(polarityRaw)")
          }
          return StoredDiaryReason(
            id: try UUID.parse(reasonRow.string(0)),
            text: try reasonRow.string(2),
            polarity: polarity
          )
        }
      )
    }

    return StoredDiaryEntry(
      id: entryID,
      rawText: try row.string(1),
      options: options,
      createdAt: Date(timeIntervalSince1970: try row.double(2)),
      updatedAt: Date(timeIntervalSince1970: try row.double(3))
    )
  }

  private func analysis(from row: SQLiteRow, database: SQLiteDatabase) throws -> StoredDecisionAnalysis {
    let analysisID = try UUID.parse(row.string(0))
    let model = try analysisModelMetadata(analysisID: analysisID, fallbackModelID: try row.string(5), database: database)
    let asset = try analysisAssetMetadata(
      analysisID: analysisID,
      fallbackVersion: try row.int(4),
      fallbackSourceDOI: try row.string(6),
      database: database
    )
    return StoredDecisionAnalysis(
      id: analysisID,
      entryID: try UUID.parse(row.string(1)),
      createdAt: Date(timeIntervalSince1970: try row.double(2)),
      schemaVersion: try row.int(3),
      model: model,
      asset: asset,
      clusterMethod: try analysisClusterMethodMetadata(analysisID: analysisID, database: database),
      embeddings: try analysisEmbeddings(analysisID: analysisID, fallbackModel: model, database: database),
      reasonMatches: try reasonMatches(analysisID: analysisID, database: database),
      optionAttributeProfiles: try optionAttributeProfiles(analysisID: analysisID, database: database),
      optionClusterProfiles: try optionClusterProfiles(analysisID: analysisID, database: database),
      metrics: try analysisMetrics(analysisID: analysisID, database: database),
      warnings: try analysisWarnings(analysisID: analysisID, database: database),
      attributeConflicts: try attributeConflicts(analysisID: analysisID, database: database),
      clusterProfiles: try clusterProfiles(analysisID: analysisID, database: database)
    )
  }

  private func deleteAnalysisChildren(analysisID: UUID, database: SQLiteDatabase) throws {
    let binding: [SQLiteValue] = [.text(analysisID.uuidString)]
    try database.execute("DELETE FROM attribute_match WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM cluster_profile WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM analysis_warning WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM analysis_metrics WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM analysis_option_cluster_score WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM analysis_option_attribute_score WHERE analysis_id = ?", binding)
    try database.execute(
      """
      DELETE FROM analysis_reason_top_match
      WHERE reason_match_id IN (
        SELECT id FROM analysis_reason_match WHERE analysis_id = ?
      )
      """,
      binding
    )
    try database.execute("DELETE FROM analysis_reason_match WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM analysis_embedding WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM analysis_embedding_input WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM analysis_cluster_method_metadata WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM analysis_asset_metadata WHERE analysis_id = ?", binding)
    try database.execute("DELETE FROM analysis_model_metadata WHERE analysis_id = ?", binding)
  }

  private func saveAnalysisChildren(_ analysis: StoredDecisionAnalysis, database: SQLiteDatabase) throws {
    try saveAnalysisMetadata(analysis, database: database)
    try saveAnalysisEmbeddings(analysis, database: database)
    try saveReasonMatches(analysis, database: database)
    try saveOptionAttributeProfiles(analysis, database: database)
    try saveOptionClusterProfiles(analysis, database: database)
    try saveAnalysisMetrics(analysis, database: database)
    try saveAnalysisWarnings(analysis, database: database)
    try saveProjectionRows(analysis, database: database)
  }

  private func saveAnalysisMetadata(_ analysis: StoredDecisionAnalysis, database: SQLiteDatabase) throws {
    let analysisID = analysis.id.uuidString
    try database.execute(
      """
      INSERT INTO analysis_model_metadata(analysis_id, model_id, model_name, embedding_dimension)
      VALUES (?, ?, ?, ?)
      """,
      [
        .text(analysisID),
        .text(analysis.model.id),
        .text(analysis.model.name),
        .integer(analysis.model.embeddingDimension),
      ]
    )
    try database.execute(
      """
      INSERT INTO analysis_asset_metadata(analysis_id, asset_version, resource_name, source_doi)
      VALUES (?, ?, ?, ?)
      """,
      [
        .text(analysisID),
        .integer(analysis.asset.version),
        .text(analysis.asset.resourceName),
        .text(analysis.asset.sourceDOI),
      ]
    )
    try database.execute(
      """
      INSERT INTO analysis_cluster_method_metadata(analysis_id, method_id, label)
      VALUES (?, ?, ?)
      """,
      [
        .text(analysisID),
        .text(analysis.clusterMethod.id),
        .text(analysis.clusterMethod.label),
      ]
    )
  }

  private func saveAnalysisEmbeddings(_ analysis: StoredDecisionAnalysis, database: SQLiteDatabase) throws {
    let analysisID = analysis.id.uuidString
    try database.execute(
      "INSERT INTO analysis_embedding_input(analysis_id, raw_text) VALUES (?, ?)",
      [.text(analysisID), .text(analysis.embeddings.rawText)]
    )
    try insertEmbedding(
      analysisID: analysis.id,
      ownerType: "question",
      optionIndex: nil,
      reasonID: nil,
      polarity: nil,
      text: nil,
      vector: analysis.embeddings.dilemmaText,
      sortOrder: 0,
      database: database
    )
    for (offset, option) in analysis.embeddings.options.sorted(by: { $0.optionIndex < $1.optionIndex }).enumerated() {
      try insertEmbedding(
        analysisID: analysis.id,
        ownerType: "option",
        optionIndex: option.optionIndex,
        reasonID: nil,
        polarity: nil,
        text: option.title,
        vector: option.embedding,
        sortOrder: offset,
        database: database
      )
    }
    for (offset, reason) in analysis.embeddings.reasons.enumerated() {
      try insertEmbedding(
        analysisID: analysis.id,
        ownerType: "reason",
        optionIndex: reason.optionIndex,
        reasonID: reason.reasonID,
        polarity: reason.polarity,
        text: reason.text,
        vector: reason.embedding,
        sortOrder: offset,
        database: database
      )
    }
  }

  private func insertEmbedding(
    analysisID: UUID,
    ownerType: String,
    optionIndex: Int?,
    reasonID: UUID?,
    polarity: StoredDiaryReasonPolarity?,
    text: String?,
    vector: StoredEmbeddingVector,
    sortOrder: Int,
    database: SQLiteDatabase
  ) throws {
    try database.execute(
      """
      INSERT INTO analysis_embedding(
        id, analysis_id, owner_type, option_index, reason_id, polarity, text,
        model_id, model_name, dimension, values_blob, sort_order
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      """,
      [
        .text(UUID().uuidString),
        .text(analysisID.uuidString),
        .text(ownerType),
        optionIndex.map(SQLiteValue.integer) ?? .null,
        reasonID.map { .text($0.uuidString) } ?? .null,
        polarity.map { .text($0.rawValue) } ?? .null,
        text.map(SQLiteValue.text) ?? .null,
        .text(vector.modelID),
        .text(vector.modelName),
        .integer(vector.dimension),
        .blob(Self.floatBlob(vector.values)),
        .integer(sortOrder),
      ]
    )
  }

  private func saveReasonMatches(_ analysis: StoredDecisionAnalysis, database: SQLiteDatabase) throws {
    for (offset, match) in analysis.reasonMatches.enumerated() {
      try database.execute(
        """
        INSERT INTO analysis_reason_match(
          id, analysis_id, reason_id, option_index, polarity, text,
          raw_scores_blob, centered_scores_blob, sort_order
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
          .text(match.id.uuidString),
          .text(analysis.id.uuidString),
          .text(match.reason.id.uuidString),
          .integer(match.reason.optionIndex),
          .text(match.reason.polarity.rawValue),
          .text(match.reason.text),
          .blob(Self.floatBlob(match.rawScores)),
          .blob(Self.floatBlob(match.centeredScores)),
          .integer(offset),
        ]
      )

      for (matchOffset, score) in match.topMatches.enumerated() {
        try database.execute(
          """
          INSERT INTO analysis_reason_top_match(
            id, reason_match_id, attribute_id, row_index, attribute_name, source,
            direction, vector_offset, cluster_id, score, sort_order
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          """,
          [
            .text(score.id.uuidString),
            .text(match.id.uuidString),
            score.attribute.attributeID.map(SQLiteValue.integer) ?? .null,
            .integer(score.attribute.rowIndex),
            .text(score.attribute.name),
            .text(score.attribute.source),
            .text(score.attribute.direction.rawValue),
            .integer(score.attribute.vectorOffset),
            score.attribute.clusterID.map(SQLiteValue.integer) ?? .null,
            .real(Double(score.score)),
            .integer(matchOffset),
          ]
        )
      }
    }
  }

  private func saveOptionAttributeProfiles(_ analysis: StoredDecisionAnalysis, database: SQLiteDatabase) throws {
    for profile in analysis.optionAttributeProfiles {
      for (offset, score) in profile.scores.enumerated() {
        try database.execute(
          """
          INSERT INTO analysis_option_attribute_score(
            id, analysis_id, option_index, attribute_id, attribute_name,
            source, cluster_id, score, sort_order
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          """,
          [
            .text(score.id.uuidString),
            .text(analysis.id.uuidString),
            .integer(profile.optionIndex),
            .integer(score.attribute.attributeID),
            .text(score.attribute.name),
            .text(score.attribute.source),
            score.attribute.clusterID.map(SQLiteValue.integer) ?? .null,
            .real(Double(score.score)),
            .integer(offset),
          ]
        )
      }
    }
  }

  private func saveOptionClusterProfiles(_ analysis: StoredDecisionAnalysis, database: SQLiteDatabase) throws {
    for profile in analysis.optionClusterProfiles {
      for (offset, score) in profile.scores.enumerated() {
        try database.execute(
          """
          INSERT INTO analysis_option_cluster_score(
            id, analysis_id, option_index, cluster_id, label,
            representative_attribute_name, cluster_sort_order, score, sort_order
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          """,
          [
            .text(score.id.uuidString),
            .text(analysis.id.uuidString),
            .integer(profile.optionIndex),
            .integer(score.cluster.clusterID),
            .text(score.cluster.label),
            .text(score.cluster.representativeAttributeName),
            .integer(score.cluster.sortOrder),
            .real(score.score),
            .integer(offset),
          ]
        )
      }
    }
  }

  private func saveAnalysisMetrics(_ analysis: StoredDecisionAnalysis, database: SQLiteDatabase) throws {
    try database.execute(
      """
      INSERT INTO analysis_metrics(
        analysis_id, model_load_ms, embedding_ms, scoring_ms, memory_mb
      )
      VALUES (?, ?, ?, ?, ?)
      """,
      [
        .text(analysis.id.uuidString),
        .real(analysis.metrics.modelLoadMilliseconds),
        .real(analysis.metrics.embeddingMilliseconds),
        .real(analysis.metrics.scoringMilliseconds),
        .real(analysis.metrics.approximateMemoryMegabytes),
      ]
    )
  }

  private func saveAnalysisWarnings(_ analysis: StoredDecisionAnalysis, database: SQLiteDatabase) throws {
    for (offset, warning) in analysis.warnings.enumerated() {
      try database.execute(
        "INSERT INTO analysis_warning(id, analysis_id, message, sort_order) VALUES (?, ?, ?, ?)",
        [
          .text(UUID().uuidString),
          .text(analysis.id.uuidString),
          .text(warning),
          .integer(offset),
        ]
      )
    }
  }

  private func saveProjectionRows(_ analysis: StoredDecisionAnalysis, database: SQLiteDatabase) throws {
    for conflict in analysis.attributeConflicts.sorted(by: { $0.rank < $1.rank }) {
      try database.execute(
        """
        INSERT INTO attribute_match(
          id, analysis_id, attribute_name, option1_score, option2_score, difference, rank
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        [
          .text(conflict.id.uuidString),
          .text(analysis.id.uuidString),
          .text(conflict.attributeName),
          .real(conflict.option1Score),
          .real(conflict.option2Score),
          .real(conflict.difference),
          .integer(conflict.rank),
        ]
      )
    }

    for profile in analysis.clusterProfiles {
      try database.execute(
        """
        INSERT INTO cluster_profile(id, analysis_id, option_index, cluster_id, label, score)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        [
          .text(profile.id.uuidString),
          .text(analysis.id.uuidString),
          .integer(profile.optionIndex),
          .integer(profile.clusterID),
          .text(profile.label),
          .real(profile.score),
        ]
      )
    }
  }

  private func analysisModelMetadata(
    analysisID: UUID,
    fallbackModelID: String,
    database: SQLiteDatabase
  ) throws -> StoredAnalysisModelMetadata {
    let rows = try database.query(
      """
      SELECT model_id, model_name, embedding_dimension
      FROM analysis_model_metadata
      WHERE analysis_id = ?
      """,
      [.text(analysisID.uuidString)]
    )
    guard let row = rows.first else {
      return StoredAnalysisModelMetadata(id: fallbackModelID, name: fallbackModelID, embeddingDimension: 0)
    }
    return StoredAnalysisModelMetadata(
      id: try row.string(0),
      name: try row.string(1),
      embeddingDimension: try row.int(2)
    )
  }

  private func analysisAssetMetadata(
    analysisID: UUID,
    fallbackVersion: Int,
    fallbackSourceDOI: String,
    database: SQLiteDatabase
  ) throws -> StoredAnalysisAssetMetadata {
    let rows = try database.query(
      """
      SELECT asset_version, resource_name, source_doi
      FROM analysis_asset_metadata
      WHERE analysis_id = ?
      """,
      [.text(analysisID.uuidString)]
    )
    guard let row = rows.first else {
      return StoredAnalysisAssetMetadata(
        version: fallbackVersion,
        resourceName: "",
        sourceDOI: fallbackSourceDOI
      )
    }
    return StoredAnalysisAssetMetadata(
      version: try row.int(0),
      resourceName: try row.string(1),
      sourceDOI: try row.string(2)
    )
  }

  private func analysisClusterMethodMetadata(
    analysisID: UUID,
    database: SQLiteDatabase
  ) throws -> StoredAnalysisClusterMethodMetadata {
    let rows = try database.query(
      """
      SELECT method_id, label
      FROM analysis_cluster_method_metadata
      WHERE analysis_id = ?
      """,
      [.text(analysisID.uuidString)]
    )
    guard let row = rows.first else {
      return StoredAnalysisClusterMethodMetadata(id: "", label: "")
    }
    return StoredAnalysisClusterMethodMetadata(id: try row.string(0), label: try row.string(1))
  }

  private func analysisEmbeddings(
    analysisID: UUID,
    fallbackModel: StoredAnalysisModelMetadata,
    database: SQLiteDatabase
  ) throws -> StoredDecisionAnalysisEmbeddings {
    let rawText = try database.query(
      "SELECT raw_text FROM analysis_embedding_input WHERE analysis_id = ?",
      [.text(analysisID.uuidString)]
    ).first?.string(0) ?? ""
    let rows = try database.query(
      """
      SELECT owner_type, option_index, reason_id, polarity, text,
             model_id, model_name, dimension, values_blob
      FROM analysis_embedding
      WHERE analysis_id = ?
      ORDER BY owner_type, sort_order
      """,
      [.text(analysisID.uuidString)]
    )

    var dilemmaText = StoredEmbeddingVector(
      modelID: fallbackModel.id,
      modelName: fallbackModel.name,
      dimension: fallbackModel.embeddingDimension,
      values: []
    )
    var options: [StoredOptionEmbedding] = []
    var reasons: [StoredReasonEmbedding] = []

    for row in rows {
      let vector = try StoredEmbeddingVector(
        modelID: row.string(5),
        modelName: row.string(6),
        dimension: row.int(7),
        values: Self.floats(from: row.data(8))
      )
      switch try row.string(0) {
      case "question":
        dilemmaText = vector
      case "option":
        options.append(
          StoredOptionEmbedding(
            optionIndex: try row.int(1),
            title: try row.optionalString(4) ?? "",
            embedding: vector
          )
        )
      case "reason":
        let polarityRaw = try row.optionalString(3) ?? StoredDiaryReasonPolarity.benefit.rawValue
        guard let polarity = StoredDiaryReasonPolarity(rawValue: polarityRaw) else {
          throw DiaryVaultError.database("Unknown analysis reason polarity \(polarityRaw)")
        }
        guard let reasonIDString = try row.optionalString(2) else {
          throw DiaryVaultError.database("Missing reason id for reason embedding.")
        }
        reasons.append(
          StoredReasonEmbedding(
            reasonID: try UUID.parse(reasonIDString),
            optionIndex: try row.int(1),
            polarity: polarity,
            text: try row.optionalString(4) ?? "",
            embedding: vector
          )
        )
      default:
        break
      }
    }

    return StoredDecisionAnalysisEmbeddings(
      rawText: rawText,
      dilemmaText: dilemmaText,
      options: options,
      reasons: reasons
    )
  }

  private func reasonMatches(analysisID: UUID, database: SQLiteDatabase) throws -> [StoredReasonMatchResult] {
    let rows = try database.query(
      """
      SELECT id, reason_id, option_index, polarity, text, raw_scores_blob, centered_scores_blob
      FROM analysis_reason_match
      WHERE analysis_id = ?
      ORDER BY sort_order
      """,
      [.text(analysisID.uuidString)]
    )
    return try rows.map { row in
      let matchID = try UUID.parse(row.string(0))
      let polarityRaw = try row.string(3)
      guard let polarity = StoredDiaryReasonPolarity(rawValue: polarityRaw) else {
        throw DiaryVaultError.database("Unknown analysis reason polarity \(polarityRaw)")
      }
      return StoredReasonMatchResult(
        id: matchID,
        reason: StoredReasonInput(
          id: try UUID.parse(row.string(1)),
          text: try row.string(4),
          optionIndex: try row.int(2),
          polarity: polarity
        ),
        rawScores: try Self.floats(from: row.data(5)),
        centeredScores: try Self.floats(from: row.data(6)),
        topMatches: try topMatches(reasonMatchID: matchID, database: database)
      )
    }
  }

  private func topMatches(reasonMatchID: UUID, database: SQLiteDatabase) throws -> [StoredAttributeScore] {
    let rows = try database.query(
      """
      SELECT id, attribute_id, row_index, attribute_name, source,
             direction, vector_offset, cluster_id, score
      FROM analysis_reason_top_match
      WHERE reason_match_id = ?
      ORDER BY sort_order
      """,
      [.text(reasonMatchID.uuidString)]
    )
    return try rows.map { row in
      let directionRaw = try row.string(5)
      guard let direction = StoredAttributeDirection(rawValue: directionRaw) else {
        throw DiaryVaultError.database("Unknown attribute direction \(directionRaw)")
      }
      return StoredAttributeScore(
        id: try UUID.parse(row.string(0)),
        attribute: StoredAttributeMetadata(
          attributeID: try row.optionalInt(1),
          rowIndex: try row.int(2),
          name: try row.string(3),
          source: try row.string(4),
          direction: direction,
          vectorOffset: try row.int(6),
          clusterID: try row.optionalInt(7)
        ),
        score: Float(try row.double(8))
      )
    }
  }

  private func optionAttributeProfiles(
    analysisID: UUID,
    database: SQLiteDatabase
  ) throws -> [StoredOptionAttributeProfile] {
    let rows = try database.query(
      """
      SELECT option_index, id, attribute_id, attribute_name, source, cluster_id, score
      FROM analysis_option_attribute_score
      WHERE analysis_id = ?
      ORDER BY option_index, sort_order
      """,
      [.text(analysisID.uuidString)]
    )
    var grouped: [Int: [StoredAttributeProfileScore]] = [:]
    for row in rows {
      grouped[try row.int(0), default: []].append(
        StoredAttributeProfileScore(
          id: try UUID.parse(row.string(1)),
          attribute: StoredAttributeDefinition(
            attributeID: try row.int(2),
            name: try row.string(3),
            source: try row.string(4),
            clusterID: try row.optionalInt(5)
          ),
          score: Float(try row.double(6))
        )
      )
    }
    return grouped.keys.sorted().map {
      StoredOptionAttributeProfile(optionIndex: $0, scores: grouped[$0] ?? [])
    }
  }

  private func optionClusterProfiles(
    analysisID: UUID,
    database: SQLiteDatabase
  ) throws -> [StoredOptionClusterProfile] {
    let rows = try database.query(
      """
      SELECT option_index, id, cluster_id, label, representative_attribute_name,
             cluster_sort_order, score
      FROM analysis_option_cluster_score
      WHERE analysis_id = ?
      ORDER BY option_index, sort_order
      """,
      [.text(analysisID.uuidString)]
    )
    var grouped: [Int: [StoredClusterScore]] = [:]
    for row in rows {
      grouped[try row.int(0), default: []].append(
        StoredClusterScore(
          id: try UUID.parse(row.string(1)),
          cluster: StoredClusterMetadata(
            clusterID: try row.int(2),
            label: try row.string(3),
            representativeAttributeName: try row.string(4),
            sortOrder: try row.int(5)
          ),
          score: try row.double(6)
        )
      )
    }
    return grouped.keys.sorted().map {
      StoredOptionClusterProfile(optionIndex: $0, scores: grouped[$0] ?? [])
    }
  }

  private func analysisMetrics(analysisID: UUID, database: SQLiteDatabase) throws -> StoredAnalysisMetrics {
    let rows = try database.query(
      """
      SELECT model_load_ms, embedding_ms, scoring_ms, memory_mb
      FROM analysis_metrics
      WHERE analysis_id = ?
      """,
      [.text(analysisID.uuidString)]
    )
    guard let row = rows.first else { return StoredAnalysisMetrics() }
    return StoredAnalysisMetrics(
      modelLoadMilliseconds: try row.double(0),
      embeddingMilliseconds: try row.double(1),
      scoringMilliseconds: try row.double(2),
      approximateMemoryMegabytes: try row.double(3)
    )
  }

  private func analysisWarnings(analysisID: UUID, database: SQLiteDatabase) throws -> [String] {
    try database.query(
      """
      SELECT message
      FROM analysis_warning
      WHERE analysis_id = ?
      ORDER BY sort_order
      """,
      [.text(analysisID.uuidString)]
    ).map { try $0.string(0) }
  }

  private func attributeConflicts(analysisID: UUID, database: SQLiteDatabase) throws -> [StoredAttributeConflict] {
    let rows = try database.query(
      """
      SELECT id, attribute_name, option1_score, option2_score, difference, rank
      FROM attribute_match
      WHERE analysis_id = ?
      ORDER BY rank
      """,
      [.text(analysisID.uuidString)]
    )
    return try rows.map {
      StoredAttributeConflict(
        id: try UUID.parse($0.string(0)),
        attributeName: try $0.string(1),
        option1Score: try $0.double(2),
        option2Score: try $0.double(3),
        difference: try $0.double(4),
        rank: try $0.int(5)
      )
    }
  }

  private func clusterProfiles(analysisID: UUID, database: SQLiteDatabase) throws -> [StoredClusterProfile] {
    let rows = try database.query(
      """
      SELECT id, option_index, cluster_id, label, score
      FROM cluster_profile
      WHERE analysis_id = ?
      ORDER BY option_index, ABS(score) DESC
      """,
      [.text(analysisID.uuidString)]
    )
    return try rows.map {
      StoredClusterProfile(
        id: try UUID.parse($0.string(0)),
        optionIndex: try $0.int(1),
        clusterID: try $0.int(2),
        label: try $0.string(3),
        score: try $0.double(4)
      )
    }
  }

  private func feedbackRecord(from row: SQLiteRow) throws -> StoredFeedback {
    StoredFeedback(
      id: try UUID.parse(row.string(0)),
      entryID: try UUID.parse(row.string(1)),
      analysisID: try row.optionalString(2).map(UUID.parse),
      conflictWasUseful: try row.int(3) == 1,
      correctedClusterID: try row.optionalInt(4),
      correctedAttributeName: try row.optionalString(5),
      chosenOptionIndex: try row.optionalInt(6),
      note: try row.string(7),
      createdAt: Date(timeIntervalSince1970: try row.double(8))
    )
  }

  private func existingFeedbackID(
    entryID: UUID,
    analysisID: UUID?,
    database: SQLiteDatabase
  ) throws -> UUID? {
    let sql: String
    let bindings: [SQLiteValue]
    if let analysisID {
      sql = """
      SELECT id
      FROM feedback
      WHERE entry_id = ? AND analysis_id = ?
      ORDER BY created_at DESC
      LIMIT 1
      """
      bindings = [.text(entryID.uuidString), .text(analysisID.uuidString)]
    } else {
      sql = """
      SELECT id
      FROM feedback
      WHERE entry_id = ? AND analysis_id IS NULL
      ORDER BY created_at DESC
      LIMIT 1
      """
      bindings = [.text(entryID.uuidString)]
    }

    return try database.query(sql, bindings).first
      .map { try UUID.parse($0.string(0)) }
  }

  private func deleteFeedback(
    entryID: UUID,
    analysisID: UUID?,
    database: SQLiteDatabase
  ) throws {
    if let analysisID {
      try database.execute(
        "DELETE FROM feedback WHERE entry_id = ? AND analysis_id = ?",
        [.text(entryID.uuidString), .text(analysisID.uuidString)]
      )
    } else {
      try database.execute(
        "DELETE FROM feedback WHERE entry_id = ? AND analysis_id IS NULL",
        [.text(entryID.uuidString)]
      )
    }
  }

  private static let schemaSQL = """
    PRAGMA foreign_keys = ON;
    PRAGMA journal_mode = WAL;
    PRAGMA user_version = 2;

    CREATE TABLE IF NOT EXISTS diary_entry (
      id TEXT PRIMARY KEY,
      raw_text TEXT NOT NULL,
      created_at REAL NOT NULL,
      updated_at REAL NOT NULL
    );

    CREATE TABLE IF NOT EXISTS decision_option (
      id TEXT PRIMARY KEY,
      entry_id TEXT NOT NULL REFERENCES diary_entry(id) ON DELETE CASCADE,
      option_index INTEGER NOT NULL,
      title TEXT NOT NULL,
      sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS reason (
      id TEXT PRIMARY KEY,
      option_id TEXT NOT NULL REFERENCES decision_option(id) ON DELETE CASCADE,
      entry_id TEXT NOT NULL REFERENCES diary_entry(id) ON DELETE CASCADE,
      polarity TEXT NOT NULL CHECK (polarity IN ('benefit', 'cost')),
      text TEXT NOT NULL,
      sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_result (
      id TEXT PRIMARY KEY,
      entry_id TEXT NOT NULL REFERENCES diary_entry(id) ON DELETE CASCADE,
      created_at REAL NOT NULL,
      schema_version INTEGER NOT NULL DEFAULT 1,
      asset_version INTEGER NOT NULL,
      model_id TEXT NOT NULL,
      source_doi TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_model_metadata (
      analysis_id TEXT PRIMARY KEY REFERENCES analysis_result(id) ON DELETE CASCADE,
      model_id TEXT NOT NULL,
      model_name TEXT NOT NULL,
      embedding_dimension INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_asset_metadata (
      analysis_id TEXT PRIMARY KEY REFERENCES analysis_result(id) ON DELETE CASCADE,
      asset_version INTEGER NOT NULL,
      resource_name TEXT NOT NULL,
      source_doi TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_cluster_method_metadata (
      analysis_id TEXT PRIMARY KEY REFERENCES analysis_result(id) ON DELETE CASCADE,
      method_id TEXT NOT NULL,
      label TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_embedding_input (
      analysis_id TEXT PRIMARY KEY REFERENCES analysis_result(id) ON DELETE CASCADE,
      raw_text TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_embedding (
      id TEXT PRIMARY KEY,
      analysis_id TEXT NOT NULL REFERENCES analysis_result(id) ON DELETE CASCADE,
      owner_type TEXT NOT NULL CHECK (owner_type IN ('question', 'option', 'reason')),
      option_index INTEGER,
      reason_id TEXT,
      polarity TEXT CHECK (polarity IN ('benefit', 'cost')),
      text TEXT,
      model_id TEXT NOT NULL,
      model_name TEXT NOT NULL,
      dimension INTEGER NOT NULL,
      values_blob BLOB NOT NULL,
      sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_reason_match (
      id TEXT PRIMARY KEY,
      analysis_id TEXT NOT NULL REFERENCES analysis_result(id) ON DELETE CASCADE,
      reason_id TEXT NOT NULL,
      option_index INTEGER NOT NULL,
      polarity TEXT NOT NULL CHECK (polarity IN ('benefit', 'cost')),
      text TEXT NOT NULL,
      raw_scores_blob BLOB NOT NULL,
      centered_scores_blob BLOB NOT NULL,
      sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_reason_top_match (
      id TEXT PRIMARY KEY,
      reason_match_id TEXT NOT NULL REFERENCES analysis_reason_match(id) ON DELETE CASCADE,
      attribute_id INTEGER,
      row_index INTEGER NOT NULL,
      attribute_name TEXT NOT NULL,
      source TEXT NOT NULL,
      direction TEXT NOT NULL CHECK (direction IN ('pro', 'con')),
      vector_offset INTEGER NOT NULL,
      cluster_id INTEGER,
      score REAL NOT NULL,
      sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_option_attribute_score (
      id TEXT PRIMARY KEY,
      analysis_id TEXT NOT NULL REFERENCES analysis_result(id) ON DELETE CASCADE,
      option_index INTEGER NOT NULL,
      attribute_id INTEGER NOT NULL,
      attribute_name TEXT NOT NULL,
      source TEXT NOT NULL,
      cluster_id INTEGER,
      score REAL NOT NULL,
      sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_option_cluster_score (
      id TEXT PRIMARY KEY,
      analysis_id TEXT NOT NULL REFERENCES analysis_result(id) ON DELETE CASCADE,
      option_index INTEGER NOT NULL,
      cluster_id INTEGER NOT NULL,
      label TEXT NOT NULL,
      representative_attribute_name TEXT NOT NULL,
      cluster_sort_order INTEGER NOT NULL,
      score REAL NOT NULL,
      sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_metrics (
      analysis_id TEXT PRIMARY KEY REFERENCES analysis_result(id) ON DELETE CASCADE,
      model_load_ms REAL NOT NULL,
      embedding_ms REAL NOT NULL,
      scoring_ms REAL NOT NULL,
      memory_mb REAL NOT NULL
    );

    CREATE TABLE IF NOT EXISTS analysis_warning (
      id TEXT PRIMARY KEY,
      analysis_id TEXT NOT NULL REFERENCES analysis_result(id) ON DELETE CASCADE,
      message TEXT NOT NULL,
      sort_order INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS attribute_match (
      id TEXT PRIMARY KEY,
      analysis_id TEXT NOT NULL REFERENCES analysis_result(id) ON DELETE CASCADE,
      attribute_name TEXT NOT NULL,
      option1_score REAL NOT NULL,
      option2_score REAL NOT NULL,
      difference REAL NOT NULL,
      rank INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS cluster_profile (
      id TEXT PRIMARY KEY,
      analysis_id TEXT NOT NULL REFERENCES analysis_result(id) ON DELETE CASCADE,
      option_index INTEGER NOT NULL,
      cluster_id INTEGER NOT NULL,
      label TEXT NOT NULL,
      score REAL NOT NULL
    );

    CREATE TABLE IF NOT EXISTS feedback (
      id TEXT PRIMARY KEY,
      entry_id TEXT NOT NULL REFERENCES diary_entry(id) ON DELETE CASCADE,
      analysis_id TEXT REFERENCES analysis_result(id) ON DELETE SET NULL,
      conflict_was_useful INTEGER NOT NULL CHECK (conflict_was_useful IN (0, 1)),
      corrected_cluster_id INTEGER,
      corrected_attribute_name TEXT,
      chosen_option_index INTEGER,
      note TEXT NOT NULL,
      created_at REAL NOT NULL
    );

    DELETE FROM feedback
    WHERE chosen_option_index IS NULL;

    DELETE FROM feedback
    WHERE id NOT IN (
      SELECT kept.id
      FROM feedback kept
      WHERE NOT EXISTS (
        SELECT 1
        FROM feedback newer
        WHERE newer.entry_id = kept.entry_id
          AND (
            newer.analysis_id = kept.analysis_id
            OR (newer.analysis_id IS NULL AND kept.analysis_id IS NULL)
          )
          AND (
            newer.created_at > kept.created_at
            OR (newer.created_at = kept.created_at AND newer.id > kept.id)
          )
      )
    );

    CREATE INDEX IF NOT EXISTS decision_option_entry_idx ON decision_option(entry_id);
    CREATE INDEX IF NOT EXISTS reason_entry_idx ON reason(entry_id);
    CREATE INDEX IF NOT EXISTS analysis_result_entry_idx ON analysis_result(entry_id);
    CREATE INDEX IF NOT EXISTS analysis_embedding_analysis_idx ON analysis_embedding(analysis_id);
    CREATE INDEX IF NOT EXISTS analysis_reason_match_analysis_idx ON analysis_reason_match(analysis_id);
    CREATE INDEX IF NOT EXISTS analysis_reason_top_match_reason_idx ON analysis_reason_top_match(reason_match_id);
    CREATE INDEX IF NOT EXISTS analysis_option_attribute_score_analysis_idx
      ON analysis_option_attribute_score(analysis_id, option_index);
    CREATE INDEX IF NOT EXISTS analysis_option_cluster_score_analysis_idx
      ON analysis_option_cluster_score(analysis_id, option_index);
    CREATE INDEX IF NOT EXISTS feedback_entry_idx ON feedback(entry_id);
    CREATE UNIQUE INDEX IF NOT EXISTS feedback_entry_analysis_unique_idx
      ON feedback(entry_id, analysis_id)
      WHERE analysis_id IS NOT NULL;
  """
}
