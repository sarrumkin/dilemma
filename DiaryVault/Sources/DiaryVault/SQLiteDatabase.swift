import Foundation
import SQLite3

enum SQLiteValue {
  case null
  case integer(Int)
  case real(Double)
  case text(String)
  case blob(Data)
}

struct SQLiteRow {
  let values: [SQLiteValue]

  func string(_ index: Int) throws -> String {
    guard case .text(let value) = values[index] else {
      throw DiaryVaultError.database("Expected text at column \(index).")
    }
    return value
  }

  func optionalString(_ index: Int) throws -> String? {
    if case .null = values[index] {
      return nil
    }
    return try string(index)
  }

  func int(_ index: Int) throws -> Int {
    guard case .integer(let value) = values[index] else {
      throw DiaryVaultError.database("Expected integer at column \(index).")
    }
    return value
  }

  func optionalInt(_ index: Int) throws -> Int? {
    if case .null = values[index] {
      return nil
    }
    return try int(index)
  }

  func double(_ index: Int) throws -> Double {
    switch values[index] {
    case .real(let value):
      return value
    case .integer(let value):
      return Double(value)
    default:
      throw DiaryVaultError.database("Expected real at column \(index).")
    }
  }

  func data(_ index: Int) throws -> Data {
    guard case .blob(let value) = values[index] else {
      throw DiaryVaultError.database("Expected blob at column \(index).")
    }
    return value
  }
}

final class SQLiteDatabase {
  private var handle: OpaquePointer?

  init(url: URL) throws {
    var database: OpaquePointer?
    let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK, let database else {
      let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
      if let database {
        sqlite3_close(database)
      }
      throw DiaryVaultError.database(message)
    }
    self.handle = database
    try execute("PRAGMA foreign_keys = ON")
  }

  deinit {
    close()
  }

  func close() {
    if let handle {
      sqlite3_close(handle)
      self.handle = nil
    }
  }

  func execute(_ sql: String, _ bindings: [SQLiteValue] = []) throws {
    guard !bindings.isEmpty || !sql.contains("?") else {
      throw DiaryVaultError.database("Missing bindings for SQL statement.")
    }
    if bindings.isEmpty {
      try exec(sql)
      return
    }

    let statement = try prepare(sql)
    defer { sqlite3_finalize(statement) }
    try bind(bindings, to: statement)
    let result = sqlite3_step(statement)
    guard result == SQLITE_DONE else {
      throw DiaryVaultError.database(lastErrorMessage)
    }
  }

  func query(_ sql: String, _ bindings: [SQLiteValue] = []) throws -> [SQLiteRow] {
    let statement = try prepare(sql)
    defer { sqlite3_finalize(statement) }
    try bind(bindings, to: statement)

    var rows = [SQLiteRow]()
    while true {
      let result = sqlite3_step(statement)
      if result == SQLITE_ROW {
        rows.append(SQLiteRow(values: values(from: statement)))
      } else if result == SQLITE_DONE {
        return rows
      } else {
        throw DiaryVaultError.database(lastErrorMessage)
      }
    }
  }

  func int(_ sql: String, _ bindings: [SQLiteValue] = []) throws -> Int {
    let rows = try query(sql, bindings)
    guard let first = rows.first else {
      throw DiaryVaultError.database("Expected scalar integer result.")
    }
    return try first.int(0)
  }

  func transaction(_ body: () throws -> Void) throws {
    try execute("BEGIN IMMEDIATE")
    do {
      try body()
      try execute("COMMIT")
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  private var databaseHandle: OpaquePointer {
    get throws {
      guard let handle else {
        throw DiaryVaultError.database("Database is closed.")
      }
      return handle
    }
  }

  private var lastErrorMessage: String {
    guard let handle else {
      return "Database is closed."
    }
    return String(cString: sqlite3_errmsg(handle))
  }

  private func exec(_ sql: String) throws {
    var errorMessage: UnsafeMutablePointer<Int8>?
    let result = sqlite3_exec(try databaseHandle, sql, nil, nil, &errorMessage)
    if result != SQLITE_OK {
      let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage
      sqlite3_free(errorMessage)
      throw DiaryVaultError.database(message)
    }
  }

  private func prepare(_ sql: String) throws -> OpaquePointer {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(try databaseHandle, sql, -1, &statement, nil) == SQLITE_OK,
          let statement else {
      throw DiaryVaultError.database(lastErrorMessage)
    }
    return statement
  }

  private func bind(_ bindings: [SQLiteValue], to statement: OpaquePointer) throws {
    for (offset, binding) in bindings.enumerated() {
      let index = Int32(offset + 1)
      let result: Int32
      switch binding {
      case .null:
        result = sqlite3_bind_null(statement, index)
      case .integer(let value):
        result = sqlite3_bind_int64(statement, index, sqlite3_int64(value))
      case .real(let value):
        result = sqlite3_bind_double(statement, index, value)
      case .text(let value):
        result = sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
      case .blob(let value):
        result = value.withUnsafeBytes { buffer in
          sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
        }
      }

      guard result == SQLITE_OK else {
        throw DiaryVaultError.database(lastErrorMessage)
      }
    }
  }

  private func values(from statement: OpaquePointer) -> [SQLiteValue] {
    (0..<sqlite3_column_count(statement)).map { index in
      switch sqlite3_column_type(statement, index) {
      case SQLITE_NULL:
        return .null
      case SQLITE_INTEGER:
        return .integer(Int(sqlite3_column_int64(statement, index)))
      case SQLITE_FLOAT:
        return .real(sqlite3_column_double(statement, index))
      case SQLITE_TEXT:
        guard let text = sqlite3_column_text(statement, index) else { return .text("") }
        return .text(String(cString: text))
      case SQLITE_BLOB:
        guard let bytes = sqlite3_column_blob(statement, index) else { return .blob(Data()) }
        let count = Int(sqlite3_column_bytes(statement, index))
        return .blob(Data(bytes: bytes, count: count))
      default:
        return .null
      }
    }
  }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension UUID {
  static func parse(_ string: String) throws -> UUID {
    guard let uuid = UUID(uuidString: string) else {
      throw DiaryVaultError.database("Invalid UUID: \(string)")
    }
    return uuid
  }
}
