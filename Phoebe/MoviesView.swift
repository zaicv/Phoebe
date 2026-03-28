import Foundation

// MARK: - Core Models

struct VideoItem: Identifiable, Codable, Hashable {
    // Path is the canonical media identifier in the Tailscale-backed app.
    let path: String

    // Kept from TS shape; in SwiftUI lists we use path-based identity.
    var id: String { path }

    let title: String
    let year: String?
    let duration: TimeInterval
    let coverArt: String?
    let streamUrl: String?
    let addedAt: String?
    let summary: String?
    let type: String?
    let grandparentTitle: String?
    let parentTitle: String?
    let index: String?
    let localFilePath: String?
    let isLocal: Bool?
}

struct FolderItem: Identifiable, Codable, Hashable {
    let path: String
    let name: String
    let isDirectory: Bool

    var id: String { path }
}

struct DownloadRecord: Identifiable, Codable, Hashable {
    let id: String
    let path: String
    let filename: String
    let progress: Double
    let status: DownloadStatus
    let localFilePath: String?
    let errorMessage: String?
}

struct PlaybackHistoryItem: Codable, Hashable {
    let path: String
    let title: String
    let progressSeconds: TimeInterval
    let progressPercent: Double
    let completed: Bool
    let updatedAt: String
}

struct WatchlistItem: Codable, Hashable {
    let path: String
    let title: String
    let addedAt: String
}

struct VideoList: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let paths: [String]
}

// MARK: - Enums

enum AppView: String, Codable, CaseIterable {
    case library
    case downloads
}

enum LibraryFilter: String, Codable, CaseIterable {
    case all
    case `continue`
    case watchlist
    case downloaded
    case unwatched
}

enum HeaderTab: String, Codable, CaseIterable {
    case home
    case movies
    case tv
    case podcasts
    case libraries
    case downloads
}

enum DownloadStatus: String, Codable, CaseIterable {
    case queued
    case downloading
    case completed
    case failed
    case cancelled
    case interrupted
}

// MARK: - Constants

let PLEX_DOWNLOADS_STORAGE_KEY = "plex-electron-downloads-v1"
let WATCHLIST_STORAGE_KEY = "plex-watchlist-v1"
let PLAYBACK_HISTORY_STORAGE_KEY = "plex-playback-history-v1"
let PLEX_MEDIA_DEVICE_ID_KEY = "plex-media-device-id-v1"

let RESUME_THRESHOLD_SECONDS: TimeInterval = 30
let WATCHED_THRESHOLD: Double = 0.92

// MARK: - Networking

struct TailscaleClient {
    let baseURL: String

    func authHeaders() -> [String: String] {
        // TODO: Inject real auth headers from secure config/session state.
        [:]
    }

    func streamURL(path: String) -> URL {
        buildURL(endpoint: "/stream", path: path)
    }

    func filesURL(path: String) -> URL {
        buildURL(endpoint: "/files", path: path)
    }

    func downloadURL(path: String) -> URL {
        buildURL(endpoint: "/download", path: path)
    }

    private func buildURL(endpoint: String, path: String) -> URL {
        guard var components = URLComponents(string: baseURL) else {
            preconditionFailure("Invalid baseURL: \(baseURL)")
        }

        let normalizedPath: String
        if components.path.hasSuffix("/") {
            normalizedPath = components.path.dropLast() + endpoint
        } else if components.path.isEmpty {
            normalizedPath = endpoint
        } else {
            normalizedPath = components.path + endpoint
        }

        components.path = normalizedPath
        components.queryItems = [URLQueryItem(name: "path", value: path)]

        guard let url = components.url else {
            preconditionFailure("Failed to build URL for endpoint \(endpoint) and path \(path)")
        }
        return url
    }
}
