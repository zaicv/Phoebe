import Foundation

struct VaultLibraryResponse: Decodable {
    let path: String
    let folders: [VaultFolder]
    let files: [VaultVideoRef]
}

struct VaultSearchResponse: Decodable {
    let files: [VaultVideoRef]
}

struct VaultHealthResponse: Decodable {
    let status: String
    let version: String
}

enum VaultBridgeError: LocalizedError {
    case invalidBaseURL
    case unauthorized
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Bridge URL is invalid."
        case .unauthorized:
            return "Bridge rejected credentials."
        case .http(let code):
            return "Bridge request failed (\(code))."
        }
    }
}

final class VaultBridgeClient {
    private let settings: VaultSettingsStore

    init(settings: VaultSettingsStore) {
        self.settings = settings
    }

    func health() async throws -> VaultHealthResponse {
        try await get(path: "health", queryItems: [])
    }

    func library(path: String) async throws -> VaultLibraryResponse {
        let item = URLQueryItem(name: "path", value: path)
        return try await get(path: "library", queryItems: [item])
    }

    func search(query: String, path: String?) async throws -> VaultSearchResponse {
        var items = [URLQueryItem(name: "q", value: query)]
        if let path, !path.isEmpty {
            items.append(URLQueryItem(name: "path", value: path))
        }
        return try await get(path: "search", queryItems: items)
    }

    func streamURL(videoId: String) -> URL? {
        endpointURL(path: "video/\(videoId)/stream", queryItems: [])
    }

    func downloadURL(videoId: String) -> URL? {
        endpointURL(path: "video/\(videoId)/download", queryItems: [])
    }

    func authHeaders() -> [String: String] {
        guard !settings.apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [:]
        }
        return ["Authorization": "Bearer \(settings.apiToken)"]
    }

    private func get<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        guard let url = endpointURL(path: path, queryItems: queryItems) else {
            throw VaultBridgeError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        authHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 401 {
            throw VaultBridgeError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw VaultBridgeError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func endpointURL(path: String, queryItems: [URLQueryItem]) -> URL? {
        let raw = settings.bridgeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var base = URL(string: raw), !raw.isEmpty else {
            return nil
        }
        if base.path.hasSuffix("/") {
            base.deleteLastPathComponent()
        }

        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if basePath.isEmpty {
            components.path = "/\(path)"
        } else {
            components.path = "/\(basePath)/\(path)"
        }
        components.queryItems = queryItems
        return components.url
    }
}
