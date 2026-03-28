import Foundation
import Combine

final class VaultSettingsStore: ObservableObject {
    @Published var bridgeURL: String {
        didSet { defaults.set(bridgeURL, forKey: Keys.bridgeURL) }
    }

    @Published var apiToken: String {
        didSet { defaults.set(apiToken, forKey: Keys.apiToken) }
    }

    @Published var rootLabel: String {
        didSet { defaults.set(rootLabel, forKey: Keys.rootLabel) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let bridgeURL = "vault.bridgeURL"
        static let apiToken = "vault.apiToken"
        static let rootLabel = "vault.rootLabel"
    }

    init() {
        bridgeURL = defaults.string(forKey: Keys.bridgeURL) ?? ""
        apiToken = defaults.string(forKey: Keys.apiToken) ?? ""
        rootLabel = defaults.string(forKey: Keys.rootLabel) ?? "Vault"
    }
}
