import Foundation
import LocalAuthentication
import Security

public protocol DatabaseKeyProvider: Sendable {
  func databaseKey() throws -> Data
  func deleteDatabaseKey() throws
}

public struct KeychainDatabaseKeyProvider: DatabaseKeyProvider {
  private let service: String
  private let account: String

  public init(service: String = "com.local.dilemma.diary-vault", account: String = "database-key") {
    self.service = service
    self.account = account
  }

  public func databaseKey() throws -> Data {
    if let existing = try readKey() {
      return existing
    }

    var bytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    guard status == errSecSuccess else {
      throw DiaryVaultError.keychain("Unable to generate database key: \(status)")
    }

    let key = Data(bytes)
    try saveKey(key)
    return key
  }

  public func deleteDatabaseKey() throws {
    let status = SecItemDelete(baseQuery() as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw DiaryVaultError.keychain("Unable to delete database key: \(status)")
    }
  }

  private func readKey() throws -> Data? {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw DiaryVaultError.keychain("Unable to read database key: \(status)")
    }
    return item as? Data
  }

  private func saveKey(_ key: Data) throws {
    var query = baseQuery()
    query[kSecValueData as String] = key
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw DiaryVaultError.keychain("Unable to save database key: \(status)")
    }
  }

  private func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

public protocol VaultAuthenticator: Sendable {
  func unlock(reason: String) async throws
}

public struct DeviceOwnerAuthenticator: VaultAuthenticator {
  public init() {}

  public func unlock(reason: String) async throws {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
      throw DiaryVaultError.authentication(error?.localizedDescription ?? "Authentication unavailable")
    }

    let accepted = try await context.evaluatePolicy(
      .deviceOwnerAuthentication,
      localizedReason: reason
    )
    guard accepted else {
      throw DiaryVaultError.authentication("Authentication was not accepted.")
    }
  }
}

public struct NoOpVaultAuthenticator: VaultAuthenticator {
  public init() {}

  public func unlock(reason: String) async throws {}
}

public enum DiaryVaultError: LocalizedError, Equatable, Sendable {
  case keychain(String)
  case authentication(String)
  case database(String)
  case notFound

  public var errorDescription: String? {
    switch self {
    case .keychain(let message):
      "Keychain error: \(message)"
    case .authentication(let message):
      "Authentication error: \(message)"
    case .database(let message):
      "Database error: \(message)"
    case .notFound:
      "Record not found."
    }
  }
}
