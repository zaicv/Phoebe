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
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricCredentialsError.keychainError(status)
        }
    }

    func loadCredentials(reason: String) async throws -> (email: String, password: String) {
        try await authenticate(reason: reason)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
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

    var hasSavedCredentials: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func authenticate(reason: String) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? BiometricCredentialsError.biometricsUnavailable
        }

        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evalError in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: evalError ?? BiometricCredentialsError.authenticationFailed)
                }
            }
        }
    }
}

private struct SavedCredentials: Codable {
    let email: String
    let password: String
}

enum BiometricCredentialsError: LocalizedError {
    case noSavedCredentials
    case invalidCredentialData
    case biometricsUnavailable
    case authenticationFailed
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noSavedCredentials:
            return "No saved credentials found. Sign in once with email and password first."
        case .invalidCredentialData:
            return "Saved credentials are unreadable."
        case .biometricsUnavailable:
            return "Biometric authentication is not available on this device."
        case .authenticationFailed:
            return "Biometric authentication failed."
        case let .keychainError(status):
            if status == -34018 {
                return "Keychain access failed (-34018). In Xcode, set a valid Signing Team for the Phoebe target and add the Keychain Sharing capability, then run again."
            }
            return "Keychain error: \(status)"
        }
    }
}
