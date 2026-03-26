import Foundation
import LocalAuthentication
import Security

final class BiometricCredentialsStore {
    static let shared = BiometricCredentialsStore()

    private let service = "com.isaiah.Phoebe.credentials"
    private let account = "supabase-login"

    private init() {}

    var isBiometricsAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometryLabel: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        default: return "Biometrics"
        }
    }

    func saveCredentials(email: String, password: String) throws {
        let payload = SavedCredentials(email: email, password: password)
        let data = try JSONEncoder().encode(payload)

        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryAny,
            nil
        )

        guard let accessControl = access else {
            throw BiometricCredentialsError.unableToCreateAccessControl
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricCredentialsError.keychainError(status)
        }
    }

    func loadCredentials(reason: String) throws -> (email: String, password: String) {
        let context = LAContext()
        context.localizedReason = reason

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context,
            kSecUseOperationPrompt as String: reason,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            throw BiometricCredentialsError.noSavedCredentials
        }

        guard status == errSecSuccess else {
            throw BiometricCredentialsError.keychainError(status)
        }

        guard let data = item as? Data else {
            throw BiometricCredentialsError.invalidCredentialData
        }

        let saved = try JSONDecoder().decode(SavedCredentials.self, from: data)
        return (saved.email, saved.password)
    }
}

private struct SavedCredentials: Codable {
    let email: String
    let password: String
}

enum BiometricCredentialsError: LocalizedError {
    case unableToCreateAccessControl
    case noSavedCredentials
    case invalidCredentialData
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unableToCreateAccessControl:
            return "Unable to configure secure biometric storage."
        case .noSavedCredentials:
            return "No saved credentials found. Sign in once with email and password first."
        case .invalidCredentialData:
            return "Saved credentials are unreadable."
        case let .keychainError(status):
            return "Keychain error: \(status)"
        }
    }
}
