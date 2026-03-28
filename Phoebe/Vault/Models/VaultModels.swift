import Foundation

struct VaultFolder: Identifiable, Codable, Hashable {
    var id: String { path.isEmpty ? "/" : path }
    let name: String
    let path: String
}

struct VaultVideoRef: Identifiable, Codable, Hashable {
    let id: String
    let filename: String
    let relativePath: String
    let size: Int64
    let modifiedAt: Date
    let mimeType: String

    var isPlayableInApp: Bool {
        let ext = filename.split(separator: ".").last?.lowercased() ?? ""
        return ext == "mp4" || ext == "mov"
    }

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct VaultList: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
}

struct VaultListItem: Identifiable, Codable, Hashable {
    let id: UUID
    let listId: UUID
    let videoId: String
    let addedAt: Date
}

struct PlaybackState: Codable, Hashable {
    let videoId: String
    var lastPositionSeconds: Double
    var lastPlayedAt: Date
}

struct VaultDownloadRecord: Identifiable, Codable, Hashable {
    enum Status: String, Codable {
        case queued
        case running
        case completed
        case failed
    }

    let id: UUID
    let videoId: String
    let filename: String
    let startedAt: Date
    var progress: Double
    var status: Status
    var localFilePath: String?
    var errorMessage: String?
}

struct VaultSnapshot: Codable {
    var knownVideos: [VaultVideoRef]
    var lists: [VaultList]
    var listItems: [VaultListItem]
    var playback: [PlaybackState]
    var downloads: [VaultDownloadRecord]

    static let empty = VaultSnapshot(
        knownVideos: [],
        lists: [],
        listItems: [],
        playback: [],
        downloads: []
    )
}
