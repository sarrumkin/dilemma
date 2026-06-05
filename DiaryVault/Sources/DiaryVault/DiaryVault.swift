import DecisionModels
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
    }
  }

  public func saveEntry(_ entry: DiaryEntry) throws {
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

  public func entries() throws -> [DiaryEntry] {
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

  public func snapshot() throws -> DiarySnapshot {
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
        return DiarySnapshot(entries: [], latestAnalyses: [:])
      }

      let entryIDs = try entryRows.map { try UUID.parse($0.string(0)) }
      let optionsByEntryID = try optionsByEntryID(for: entryIDs, database: database)
      let entries = try entryRows.map { row in
        let entryID = try UUID.parse(row.string(0))
        return DiaryEntry(
          id: entryID,
          rawText: try row.string(1),
          options: optionsByEntryID[entryID] ?? [],
          createdAt: Date(timeIntervalSince1970: try row.double(2)),
          updatedAt: Date(timeIntervalSince1970: try row.double(3))
        )
      }

      return DiarySnapshot(
        entries: entries,
        latestAnalyses: try latestAnalysesByEntryID(for: entryIDs, database: database)
      )
    }
  }

  public func entry(id: UUID) throws -> DiaryEntry {
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

  public func saveAnalysis(_ analysis: DiaryAnalysis) throws {
    try queue.sync {
      let database = try openDatabase()
      try database.transaction {
        try database.execute(
          """
          INSERT INTO analysis_result(id, entry_id, created_at, asset_version, model_id, source_doi)
          VALUES (?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            created_at = excluded.created_at,
            asset_version = excluded.asset_version,
            model_id = excluded.model_id,
            source_doi = excluded.source_doi
          """,
          [
            .text(analysis.id.uuidString),
            .text(analysis.entryID.uuidString),
            .real(analysis.createdAt.timeIntervalSince1970),
            .integer(analysis.assetVersion),
            .text(analysis.modelID),
            .text(analysis.sourceDOI),
          ]
        )
        try database.execute("DELETE FROM attribute_match WHERE analysis_id = ?", [.text(analysis.id.uuidString)])
        try database.execute("DELETE FROM attribute_profile WHERE analysis_id = ?", [.text(analysis.id.uuidString)])
        try database.execute("DELETE FROM cluster_profile WHERE analysis_id = ?", [.text(analysis.id.uuidString)])

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

        for profile in analysis.attributeProfiles {
          try database.execute(
            """
            INSERT INTO attribute_profile(id, analysis_id, option_index, attribute_id, attribute_name, score)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
              .text(profile.id.uuidString),
              .text(analysis.id.uuidString),
              .integer(profile.optionIndex),
              .integer(profile.attributeID),
              .text(profile.attributeName),
              .real(profile.score),
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
    }
  }

  public func analyses(entryID: UUID? = nil) throws -> [DiaryAnalysis] {
    try queue.sync {
      let database = try openDatabase()
      let sql: String
      let bindings: [SQLiteValue]
      if let entryID {
        sql = """
        SELECT id, entry_id, created_at, asset_version, model_id, source_doi
        FROM analysis_result
        WHERE entry_id = ?
        ORDER BY created_at DESC
        """
        bindings = [.text(entryID.uuidString)]
      } else {
        sql = """
        SELECT id, entry_id, created_at, asset_version, model_id, source_doi
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

  public func saveFeedback(_ feedback: Feedback) throws {
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

  public func feedback(entryID: UUID, analysisID: UUID?) throws -> Feedback? {
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

  public func feedback(entryID: UUID? = nil) throws -> [Feedback] {
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

  public func statistics() throws -> PreferenceStatistics {
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

      return PreferenceStatistics(
        entryCount: entryCount,
        feedbackCount: feedbackCount,
        acceptedConflictCount: accepted,
        rejectedConflictCount: rejected,
        mostFrequentClusters: try clusterRows.map {
          ClusterFrequency(
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

  public func exportData() throws -> DiaryExport {
    DiaryExport(
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

  private func optionsByEntryID(
    for entryIDs: [UUID],
    database: SQLiteDatabase
  ) throws -> [UUID: [DiaryOption]] {
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
    var optionsByEntryID: [UUID: [DiaryOption]] = [:]
    for row in optionRows {
      let optionID = try UUID.parse(row.string(0))
      let entryID = try UUID.parse(row.string(1))
      optionsByEntryID[entryID, default: []].append(
        DiaryOption(
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
  ) throws -> [UUID: [DiaryReason]] {
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

    var reasonsByOptionID: [UUID: [DiaryReason]] = [:]
    for row in reasonRows {
      let polarityRaw = try row.string(2)
      guard let polarity = DiaryReasonPolarity(rawValue: polarityRaw) else {
        throw DiaryVaultError.database("Unknown reason polarity \(polarityRaw)")
      }
      reasonsByOptionID[try UUID.parse(row.string(1)), default: []].append(
        DiaryReason(
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
  ) throws -> [UUID: DiaryAnalysis] {
    guard !entryIDs.isEmpty else { return [:] }
    let rows = try database.query(
      """
      SELECT id, entry_id, created_at, asset_version, model_id, source_doi
      FROM analysis_result
      WHERE entry_id IN (\(Self.placeholders(count: entryIDs.count)))
      ORDER BY entry_id, created_at DESC
      """,
      Self.bindings(for: entryIDs)
    )
    guard !rows.isEmpty else { return [:] }

    var latestRows = [SQLiteRow]()
    var seenEntryIDs = Set<UUID>()
    var analysisIDs = [UUID]()
    for row in rows {
      let entryID = try UUID.parse(row.string(1))
      guard !seenEntryIDs.contains(entryID) else { continue }
      seenEntryIDs.insert(entryID)
      latestRows.append(row)
      analysisIDs.append(try UUID.parse(row.string(0)))
    }

    let conflictsByAnalysisID = try attributeConflictsByAnalysisID(
      for: analysisIDs,
      database: database
    )
    let attributesByAnalysisID = try attributeProfilesByAnalysisID(
      for: analysisIDs,
      database: database
    )
    let clustersByAnalysisID = try clusterProfilesByAnalysisID(
      for: analysisIDs,
      database: database
    )

    var latestAnalyses: [UUID: DiaryAnalysis] = [:]
    for row in latestRows {
      let analysisID = try UUID.parse(row.string(0))
      let entryID = try UUID.parse(row.string(1))
      latestAnalyses[entryID] = DiaryAnalysis(
        id: analysisID,
        entryID: entryID,
        createdAt: Date(timeIntervalSince1970: try row.double(2)),
        assetVersion: try row.int(3),
        modelID: try row.string(4),
        sourceDOI: try row.string(5),
        attributeConflicts: conflictsByAnalysisID[analysisID] ?? [],
        attributeProfiles: attributesByAnalysisID[analysisID] ?? [],
        clusterProfiles: clustersByAnalysisID[analysisID] ?? []
      )
    }
    return latestAnalyses
  }

  private func attributeConflictsByAnalysisID(
    for analysisIDs: [UUID],
    database: SQLiteDatabase
  ) throws -> [UUID: [AttributeConflict]] {
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

    var conflictsByAnalysisID: [UUID: [AttributeConflict]] = [:]
    for row in rows {
      conflictsByAnalysisID[try UUID.parse(row.string(0)), default: []].append(
        AttributeConflict(
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
  ) throws -> [UUID: [ClusterProfile]] {
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

    var clustersByAnalysisID: [UUID: [ClusterProfile]] = [:]
    for row in rows {
      clustersByAnalysisID[try UUID.parse(row.string(0)), default: []].append(
        ClusterProfile(
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

  private func attributeProfilesByAnalysisID(
    for analysisIDs: [UUID],
    database: SQLiteDatabase
  ) throws -> [UUID: [AttributeProfile]] {
    guard !analysisIDs.isEmpty else { return [:] }
    let rows = try database.query(
      """
      SELECT analysis_id, id, option_index, attribute_id, attribute_name, score
      FROM attribute_profile
      WHERE analysis_id IN (\(Self.placeholders(count: analysisIDs.count)))
      ORDER BY analysis_id, option_index, ABS(score) DESC
      """,
      Self.bindings(for: analysisIDs)
    )

    var attributesByAnalysisID: [UUID: [AttributeProfile]] = [:]
    for row in rows {
      attributesByAnalysisID[try UUID.parse(row.string(0)), default: []].append(
        AttributeProfile(
          id: try UUID.parse(row.string(1)),
          optionIndex: try row.int(2),
          attributeID: try row.int(3),
          attributeName: try row.string(4),
          score: try row.double(5)
        )
      )
    }
    return attributesByAnalysisID
  }

  private static func placeholders(count: Int) -> String {
    Array(repeating: "?", count: count).joined(separator: ", ")
  }

  private static func bindings(for ids: [UUID]) -> [SQLiteValue] {
    ids.map { .text($0.uuidString) }
  }

  private func entry(from row: SQLiteRow, database: SQLiteDatabase) throws -> DiaryEntry {
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
      return DiaryOption(
        id: optionID,
        index: try optionRow.int(1),
        title: try optionRow.string(2),
        reasons: try reasonRows.map { reasonRow in
          let polarityRaw = try reasonRow.string(1)
          guard let polarity = DiaryReasonPolarity(rawValue: polarityRaw) else {
            throw DiaryVaultError.database("Unknown reason polarity \(polarityRaw)")
          }
          return DiaryReason(
            id: try UUID.parse(reasonRow.string(0)),
            text: try reasonRow.string(2),
            polarity: polarity
          )
        }
      )
    }

    return DiaryEntry(
      id: entryID,
      rawText: try row.string(1),
      options: options,
      createdAt: Date(timeIntervalSince1970: try row.double(2)),
      updatedAt: Date(timeIntervalSince1970: try row.double(3))
    )
  }

  private func analysis(from row: SQLiteRow, database: SQLiteDatabase) throws -> DiaryAnalysis {
    let analysisID = try UUID.parse(row.string(0))
    let attributeRows = try database.query(
      """
      SELECT id, attribute_name, option1_score, option2_score, difference, rank
      FROM attribute_match
      WHERE analysis_id = ?
      ORDER BY rank
      """,
      [.text(analysisID.uuidString)]
    )
    let attributeProfileRows = try database.query(
      """
      SELECT id, option_index, attribute_id, attribute_name, score
      FROM attribute_profile
      WHERE analysis_id = ?
      ORDER BY option_index, ABS(score) DESC
      """,
      [.text(analysisID.uuidString)]
    )
    let clusterRows = try database.query(
      """
      SELECT id, option_index, cluster_id, label, score
      FROM cluster_profile
      WHERE analysis_id = ?
      ORDER BY option_index, ABS(score) DESC
      """,
      [.text(analysisID.uuidString)]
    )

    return DiaryAnalysis(
      id: analysisID,
      entryID: try UUID.parse(row.string(1)),
      createdAt: Date(timeIntervalSince1970: try row.double(2)),
      assetVersion: try row.int(3),
      modelID: try row.string(4),
      sourceDOI: try row.string(5),
      attributeConflicts: try attributeRows.map {
        AttributeConflict(
          id: try UUID.parse($0.string(0)),
          attributeName: try $0.string(1),
          option1Score: try $0.double(2),
          option2Score: try $0.double(3),
          difference: try $0.double(4),
          rank: try $0.int(5)
        )
      },
      attributeProfiles: try attributeProfileRows.map {
        AttributeProfile(
          id: try UUID.parse($0.string(0)),
          optionIndex: try $0.int(1),
          attributeID: try $0.int(2),
          attributeName: try $0.string(3),
          score: try $0.double(4)
        )
      },
      clusterProfiles: try clusterRows.map {
        ClusterProfile(
          id: try UUID.parse($0.string(0)),
          optionIndex: try $0.int(1),
          clusterID: try $0.int(2),
          label: try $0.string(3),
          score: try $0.double(4)
        )
      }
    )
  }

  private func feedbackRecord(from row: SQLiteRow) throws -> Feedback {
    Feedback(
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
    PRAGMA user_version = 1;

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
      asset_version INTEGER NOT NULL,
      model_id TEXT NOT NULL,
      source_doi TEXT NOT NULL
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

    CREATE TABLE IF NOT EXISTS attribute_profile (
      id TEXT PRIMARY KEY,
      analysis_id TEXT NOT NULL REFERENCES analysis_result(id) ON DELETE CASCADE,
      option_index INTEGER NOT NULL,
      attribute_id INTEGER NOT NULL,
      attribute_name TEXT NOT NULL,
      score REAL NOT NULL
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
    CREATE INDEX IF NOT EXISTS feedback_entry_idx ON feedback(entry_id);
    CREATE UNIQUE INDEX IF NOT EXISTS feedback_entry_analysis_unique_idx
      ON feedback(entry_id, analysis_id)
      WHERE analysis_id IS NOT NULL;
  """
}
