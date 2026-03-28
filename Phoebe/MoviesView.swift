import SwiftUI
import AVKit
import Combine
#if os(macOS)
import AppKit
#endif

// MARK: - Constants

let PLEX_DOWNLOADS_STORAGE_KEY = "plex-electron-downloads-v1"
let WATCHLIST_STORAGE_KEY = "plex-watchlist-v1"
let PLAYBACK_HISTORY_STORAGE_KEY = "plex-playback-history-v1"
let PLEX_MEDIA_DEVICE_ID_KEY = "plex-media-device-id-v1"
let VIDEO_LISTS_STORAGE_KEY = "movies-video-lists-v1"

let RESUME_THRESHOLD_SECONDS: TimeInterval = 30
let WATCHED_THRESHOLD: Double = 0.92

// MARK: - Enums

enum AppView: String, Codable, CaseIterable {
    case library
    case downloads
}

enum LibraryFilter: String, Codable, CaseIterable, Identifiable {
    case all
    case `continue`
    case watchlist
    case downloaded
    case unwatched

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .continue: return "Continue"
        case .watchlist: return "Watchlist"
        case .downloaded: return "Downloaded"
        case .unwatched: return "Unwatched"
        }
    }
}

enum HeaderTab: String, Codable, CaseIterable, Identifiable {
    case home
    case movies
    case tv
    case podcasts
    case libraries
    case downloads

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Home"
        case .movies: return "Movies"
        case .tv: return "TV"
        case .podcasts: return "Podcasts"
        case .libraries: return "Libraries"
        case .downloads: return "Downloads"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house.fill"
        case .movies: return "film.fill"
        case .tv: return "tv.fill"
        case .podcasts: return "mic.fill"
        case .libraries: return "books.vertical.fill"
        case .downloads: return "arrow.down.circle.fill"
        }
    }
}

enum DownloadStatus: String, Codable, CaseIterable {
    case queued
    case downloading
    case completed
    case failed
    case cancelled
    case interrupted
}

enum LibraryViewMode: String, Codable {
    case grid
    case list
}

// MARK: - Models

struct VideoItem: Identifiable, Codable, Hashable {
    let path: String
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
    let isPlayableInApp: Bool
    let fileSizeBytes: Int?
    let subtitlePath: String?

    var id: String { path }

    init(
        path: String,
        title: String,
        year: String? = nil,
        duration: TimeInterval = 0,
        coverArt: String? = nil,
        streamUrl: String? = nil,
        addedAt: String? = nil,
        summary: String? = nil,
        type: String? = nil,
        grandparentTitle: String? = nil,
        parentTitle: String? = nil,
        index: String? = nil,
        localFilePath: String? = nil,
        isLocal: Bool? = nil,
        isPlayableInApp: Bool = true,
        fileSizeBytes: Int? = nil,
        subtitlePath: String? = nil
    ) {
        self.path = path
        self.title = title
        self.year = year
        self.duration = duration
        self.coverArt = coverArt
        self.streamUrl = streamUrl
        self.addedAt = addedAt
        self.summary = summary
        self.type = type
        self.grandparentTitle = grandparentTitle
        self.parentTitle = parentTitle
        self.index = index
        self.localFilePath = localFilePath
        self.isLocal = isLocal
        self.isPlayableInApp = isPlayableInApp
        self.fileSizeBytes = fileSizeBytes
        self.subtitlePath = subtitlePath
    }
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

struct PlaybackHistoryItem: Codable, Hashable, Identifiable {
    let path: String
    let title: String
    let progressSeconds: Double
    let progressPercent: Double
    let completed: Bool
    let updatedAt: String

    var id: String { path }
}

struct WatchlistItem: Codable, Hashable, Identifiable {
    let path: String
    let title: String
    let addedAt: String

    var id: String { path }
}

struct VideoList: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let paths: [String]
}

// MARK: - Utility Functions

func formatBytes(_ bytes: Int) -> String {
    if bytes <= 0 { return "0 B" }
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024 && unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    let formatted: String
    if value >= 10 || unitIndex == 0 {
        formatted = String(format: "%.0f", value)
    } else {
        formatted = String(format: "%.1f", value)
    }
    return "\(formatted) \(units[unitIndex])"
}

func progressBarWidth(_ value: Double) -> CGFloat {
    CGFloat(max(0, min(100, value * 100)))
}

func normalizeLibraryLabel(_ value: String?) -> String {
    (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let totalSeconds = Int(seconds.rounded(.down))
    let hrs = totalSeconds / 3600
    let mins = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    if hrs > 0 {
        return String(format: "%d:%02d:%02d", hrs, mins, secs)
    }
    return String(format: "%d:%02d", mins, secs)
}

func getDeviceId() -> String {
    let defaults = UserDefaults.standard
    if let existing = defaults.string(forKey: PLEX_MEDIA_DEVICE_ID_KEY), !existing.isEmpty {
        return existing
    }
    let generated = UUID().uuidString
    defaults.set(generated, forKey: PLEX_MEDIA_DEVICE_ID_KEY)
    return generated
}

// MARK: - Networking Client

struct TailscaleClient {
    let baseURL: String

    init(baseURL: String = UserDefaults.standard.string(forKey: "tailscale_base_url") ?? "http://100.64.0.1:8080") {
        self.baseURL = baseURL
    }

    func authHeaders() -> [String: String] {
        var headers: [String: String] = [:]
        if let auth = UserDefaults.standard.string(forKey: "tailscale_auth_header"), !auth.isEmpty {
            headers["Authorization"] = auth
        }
        if let device = UserDefaults.standard.string(forKey: "tailscale_device_id"), !device.isEmpty {
            headers["X-Device-Id"] = device
        } else {
            headers["X-Device-Id"] = getDeviceId()
        }
        return headers
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

        if components.path.isEmpty {
            components.path = endpoint
        } else if components.path.hasSuffix("/") {
            components.path = String(components.path.dropLast()) + endpoint
        } else {
            components.path += endpoint
        }

        components.queryItems = [
            URLQueryItem(name: "path", value: path)
        ]

        guard let url = components.url else {
            preconditionFailure("Failed to build URL for endpoint \(endpoint), path \(path)")
        }
        return url
    }
}

// MARK: - Visual Components

struct DownloadedBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
            Text("SAVED")
                .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                .tracking(1.3)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(Color(red: 0.18, green: 0.95, blue: 0.55).opacity(0.9))
        .overlay(
            Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 3)
    }
}

struct WatchedBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
            Text("WATCHED")
                .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
                .tracking(1.3)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(Color(red: 0.45, green: 0.84, blue: 1.0).opacity(0.9))
        .overlay(
            Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.45), radius: 8, x: 0, y: 3)
    }
}

struct MoviesPillPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.85 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct MoviesPillSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08))
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct MoviesPillGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(
                Circle().fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.12))
            )
            .overlay(
                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

func moviesGlassPanel(cornerRadius: CGFloat = 20) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
}

// MARK: - ViewModel

@MainActor
final class MoviesViewModel: ObservableObject {
    // Navigation state
    @Published var currentPath: String = "/"
    @Published var selectedTab: HeaderTab = .home
    @Published var libraryFilter: LibraryFilter = .all
    @Published var viewMode: LibraryViewMode = .grid
    @Published var searchText: String = ""

    // Library data
    @Published var files: [VideoItem] = []
    @Published var folders: [FolderItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var healthStatus: String = "Bridge: Checking..."

    // Playback
    @Published var selectedVideo: VideoItem?
    @Published var isPlayerPresented: Bool = false
    @Published var playlist: [VideoItem] = []
    @Published var playlistIndex: Int = 0
    @Published var playlistName: String = ""
    @Published var showQueue: Bool = false

    // Persistence
    @Published var watchlist: [WatchlistItem] = [] { didSet { persistWatchlist() } }
    @Published var playbackHistory: [PlaybackHistoryItem] = [] { didSet { persistPlaybackHistory() } }
    @Published var downloads: [DownloadRecord] = [] { didSet { persistDownloads() } }
    @Published var lists: [VideoList] = [] { didSet { persistLists() } }

    // Internal
    let client: TailscaleClient
    private var allFiles: [VideoItem] = []
    private var knownFilesByPath: [String: VideoItem] = [:]
    private var downloadTasks: [String: Task<Void, Never>] = [:]

    init(client: TailscaleClient = TailscaleClient()) {
        self.client = client
        self.watchlist = Self.load([WatchlistItem].self, key: WATCHLIST_STORAGE_KEY) ?? []
        self.playbackHistory = Self.load([PlaybackHistoryItem].self, key: PLAYBACK_HISTORY_STORAGE_KEY) ?? []
        self.downloads = Self.load([DownloadRecord].self, key: PLEX_DOWNLOADS_STORAGE_KEY) ?? []
        self.lists = Self.load([VideoList].self, key: VIDEO_LISTS_STORAGE_KEY) ?? []

        Task {
            await refreshLibrary()
        }
    }

    var continueWatchingItems: [PlaybackHistoryItem] {
        playbackHistory
            .filter { $0.progressPercent > 0 && $0.progressPercent < WATCHED_THRESHOLD }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func filteredFilesForSelectedTab() -> [VideoItem] {
        let tabFiltered: [VideoItem]
        switch selectedTab {
        case .movies:
            tabFiltered = allFiles.filter { item in
                let kind = normalizeLibraryLabel(item.type)
                return kind.contains("movie") || kind.isEmpty
            }
        case .tv:
            tabFiltered = allFiles.filter { item in
                let kind = normalizeLibraryLabel(item.type)
                return kind.contains("show") || kind.contains("episode") || kind.contains("tv")
            }
        case .podcasts:
            tabFiltered = allFiles.filter { item in
                let kind = normalizeLibraryLabel(item.type)
                return kind.contains("podcast") || kind.contains("audio") || kind.contains("track")
            }
        default:
            tabFiltered = allFiles
        }

        let filterApplied: [VideoItem]
        switch libraryFilter {
        case .all:
            filterApplied = tabFiltered
        case .continue:
            let continuing = Set(continueWatchingItems.map(\.path))
            filterApplied = tabFiltered.filter { continuing.contains($0.path) }
        case .watchlist:
            let saved = Set(watchlist.map(\.path))
            filterApplied = tabFiltered.filter { saved.contains($0.path) }
        case .downloaded:
            let downloaded = Set(downloads.filter { $0.status == .completed }.map(\.path))
            filterApplied = tabFiltered.filter { downloaded.contains($0.path) }
        case .unwatched:
            let seen = Set(playbackHistory.map(\.path))
            filterApplied = tabFiltered.filter { !seen.contains($0.path) }
        }

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return filterApplied
        }
        let q = normalizeLibraryLabel(searchText)
        return filterApplied.filter { item in
            normalizeLibraryLabel(item.title).contains(q) ||
            normalizeLibraryLabel(item.summary).contains(q) ||
            normalizeLibraryLabel(item.type).contains(q)
        }
    }

    func continueWatchingVideos() -> [(video: VideoItem, history: PlaybackHistoryItem)] {
        let byPath = Dictionary(uniqueKeysWithValues: allFiles.map { ($0.path, $0) })
        return continueWatchingItems.compactMap { history in
            guard let video = byPath[history.path] else { return nil }
            return (video, history)
        }
    }

    func play(_ video: VideoItem, resumeFrom seconds: Double? = nil) {
        if let idx = playlist.firstIndex(where: { $0.path == video.path }) {
            playlistIndex = idx
        } else {
            playlist = [video]
            playlistIndex = 0
            playlistName = "Queue"
        }

        selectedVideo = video
        isPlayerPresented = true

        if let seconds {
            savePlayback(path: video.path, seconds: seconds, duration: max(video.duration, seconds + 1))
        }
    }

    func jumpToPlaylist(index: Int) {
        guard playlist.indices.contains(index) else { return }
        playlistIndex = index
        selectedVideo = playlist[index]
        isPlayerPresented = true
    }

    func advanceToNextInPlaylist() {
        let next = playlistIndex + 1
        guard playlist.indices.contains(next) else { return }
        playlistIndex = next
        selectedVideo = playlist[next]
    }

    func refreshLibrary() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let url = client.filesURL(path: currentPath)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            for (key, value) in client.authHeaders() {
                request.setValue(value, forHTTPHeaderField: key)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw NSError(domain: "MoviesView", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Bridge returned HTTP \(http.statusCode)"])
            }

            let parsed = try parseFilesResponse(data)
            folders = parsed.folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            allFiles = parsed.files.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            files = filteredFilesForSelectedTab()
            mergeKnownFiles(allFiles)
            healthStatus = "Bridge: OK · \(currentPath)"
        } catch {
            errorMessage = error.localizedDescription
            healthStatus = "Bridge: Error · \(currentPath)"
        }
    }

    func navigateUp() {
        let path = currentPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path != "/", !path.isEmpty else { return }
        let nsPath = NSString(string: path)
        var parent = nsPath.deletingLastPathComponent
        if parent.isEmpty { parent = "/" }
        currentPath = parent
        Task {
            await refreshLibrary()
        }
    }

    func openFolder(_ folder: FolderItem) async {
        currentPath = folder.path
        await refreshLibrary()
    }

    func search(query: String) async {
        searchText = query
        if allFiles.isEmpty {
            await refreshLibrary()
        } else {
            files = filteredFilesForSelectedTab()
        }
    }

    func resumePosition(for path: String) -> Double {
        playbackHistory.first(where: { $0.path == path })?.progressSeconds ?? 0
    }

    func savePlayback(path: String, seconds: Double, duration: Double) {
        let clampedDuration = max(duration, 0)
        let clampedSeconds = max(0, min(seconds, clampedDuration > 0 ? clampedDuration : seconds))
        let progressPercent = clampedDuration > 0 ? min(1, clampedSeconds / clampedDuration) : 0
        let completed = progressPercent >= WATCHED_THRESHOLD

        let title = knownFilesByPath[path]?.title ?? NSString(string: path).lastPathComponent
        let item = PlaybackHistoryItem(
            path: path,
            title: title,
            progressSeconds: completed ? clampedDuration : clampedSeconds,
            progressPercent: completed ? 1 : progressPercent,
            completed: completed,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        if let idx = playbackHistory.firstIndex(where: { $0.path == path }) {
            playbackHistory[idx] = item
        } else {
            playbackHistory.insert(item, at: 0)
        }
    }

    func isWatched(_ path: String) -> Bool {
        playbackHistory.first(where: { $0.path == path })?.completed ?? false
    }

    func isInWatchlist(_ path: String) -> Bool {
        watchlist.contains { $0.path == path }
    }

    func toggleWatchlist(_ video: VideoItem) {
        if let idx = watchlist.firstIndex(where: { $0.path == video.path }) {
            watchlist.remove(at: idx)
        } else {
            watchlist.insert(
                WatchlistItem(
                    path: video.path,
                    title: video.title,
                    addedAt: ISO8601DateFormatter().string(from: Date())
                ),
                at: 0
            )
        }
    }

    func download(_ video: VideoItem) {
        let id = "download-\(UUID().uuidString)"
        let filename = safeFilename(from: video.title, fallbackPath: video.path)

        let pending = DownloadRecord(
            id: id,
            path: video.path,
            filename: filename,
            progress: 0,
            status: .queued,
            localFilePath: nil,
            errorMessage: nil
        )
        downloads.insert(pending, at: 0)

        let task = Task {
            await updateDownload(id: id) { existing in
                DownloadRecord(
                    id: existing.id,
                    path: existing.path,
                    filename: existing.filename,
                    progress: 0.01,
                    status: .downloading,
                    localFilePath: existing.localFilePath,
                    errorMessage: nil
                )
            }

            do {
                var request = URLRequest(url: client.downloadURL(path: video.path))
                request.httpMethod = "GET"
                for (key, value) in client.authHeaders() {
                    request.setValue(value, forHTTPHeaderField: key)
                }

                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                let expected = max(0, Int(response.expectedContentLength))
                var data = Data()
                var received = 0

                for try await byte in bytes {
                    try Task.checkCancellation()
                    data.append(byte)
                    received += 1
                    if expected > 0 {
                        let p = min(0.99, Double(received) / Double(expected))
                        await updateDownload(id: id) { existing in
                            DownloadRecord(
                                id: existing.id,
                                path: existing.path,
                                filename: existing.filename,
                                progress: p,
                                status: .downloading,
                                localFilePath: existing.localFilePath,
                                errorMessage: nil
                            )
                        }
                    }
                }

                let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                    ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory
                let ext = URL(fileURLWithPath: video.path).pathExtension
                let fileURL = folder.appendingPathComponent(ext.isEmpty ? filename : "\(filename).\(ext)")
                try data.write(to: fileURL, options: .atomic)

                await updateDownload(id: id) { existing in
                    DownloadRecord(
                        id: existing.id,
                        path: existing.path,
                        filename: existing.filename,
                        progress: 1,
                        status: .completed,
                        localFilePath: fileURL.path,
                        errorMessage: nil
                    )
                }
            } catch is CancellationError {
                await updateDownload(id: id) { existing in
                    DownloadRecord(
                        id: existing.id,
                        path: existing.path,
                        filename: existing.filename,
                        progress: existing.progress,
                        status: .cancelled,
                        localFilePath: existing.localFilePath,
                        errorMessage: nil
                    )
                }
            } catch {
                await updateDownload(id: id) { existing in
                    DownloadRecord(
                        id: existing.id,
                        path: existing.path,
                        filename: existing.filename,
                        progress: existing.progress,
                        status: .failed,
                        localFilePath: existing.localFilePath,
                        errorMessage: error.localizedDescription
                    )
                }
            }

            downloadTasks[id] = nil
        }

        downloadTasks[id] = task
    }

    func cancelDownload(_ record: DownloadRecord) {
        downloadTasks[record.id]?.cancel()
        downloadTasks[record.id] = nil
        if let idx = downloads.firstIndex(where: { $0.id == record.id }) {
            downloads[idx] = DownloadRecord(
                id: downloads[idx].id,
                path: downloads[idx].path,
                filename: downloads[idx].filename,
                progress: downloads[idx].progress,
                status: .cancelled,
                localFilePath: downloads[idx].localFilePath,
                errorMessage: downloads[idx].errorMessage
            )
        }
    }

    func createList(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lists.append(VideoList(id: UUID().uuidString, name: trimmed, paths: []))
    }

    func deleteList(_ list: VideoList) {
        lists.removeAll { $0.id == list.id }
    }

    func add(_ video: VideoItem, to list: VideoList) {
        guard let idx = lists.firstIndex(where: { $0.id == list.id }) else { return }
        var paths = lists[idx].paths
        guard !paths.contains(video.path) else { return }
        paths.append(video.path)
        lists[idx] = VideoList(id: lists[idx].id, name: lists[idx].name, paths: paths)
    }

    func remove(_ video: VideoItem, from list: VideoList) {
        guard let idx = lists.firstIndex(where: { $0.id == list.id }) else { return }
        let paths = lists[idx].paths.filter { $0 != video.path }
        lists[idx] = VideoList(id: lists[idx].id, name: lists[idx].name, paths: paths)
    }

    func videos(for list: VideoList) -> [VideoItem] {
        list.paths.map { path in
            if let known = knownFilesByPath[path] {
                return known
            }
            let fallbackTitle = URL(fileURLWithPath: path).lastPathComponent
            return VideoItem(path: path, title: fallbackTitle, isPlayableInApp: false)
        }
    }

    func playerURL(for video: VideoItem) -> URL? {
        if let localPath = video.localFilePath, !localPath.isEmpty, FileManager.default.fileExists(atPath: localPath) {
            return URL(fileURLWithPath: localPath)
        }
        return client.streamURL(path: video.path)
    }

    private func mergeKnownFiles(_ videos: [VideoItem]) {
        for video in videos {
            knownFilesByPath[video.path] = video
        }
    }

    private func safeFilename(from title: String, fallbackPath: String) -> String {
        let sanitized = title
            .replacingOccurrences(of: "[^A-Za-z0-9 _.-]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.isEmpty {
            return URL(fileURLWithPath: fallbackPath).deletingPathExtension().lastPathComponent
        }
        return sanitized
    }

    private func updateDownload(id: String, mutate: (DownloadRecord) -> DownloadRecord) async {
        guard let idx = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[idx] = mutate(downloads[idx])
    }

    private func parseFilesResponse(_ data: Data) throws -> (files: [VideoItem], folders: [FolderItem]) {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let object = jsonObject as? [String: Any] else {
            throw NSError(domain: "MoviesView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from /files"])
        }

        let fileCandidates =
            (object["files"] as? [[String: Any]]) ??
            (object["videos"] as? [[String: Any]]) ??
            ((object["items"] as? [[String: Any]])?.filter { !isDirectoryEntry($0) }) ?? []

        let folderCandidates =
            (object["folders"] as? [[String: Any]]) ??
            (object["directories"] as? [[String: Any]]) ??
            ((object["items"] as? [[String: Any]])?.filter { isDirectoryEntry($0) }) ?? []

        let mappedFiles = fileCandidates.compactMap(mapVideo)
        let mappedFolders = folderCandidates.compactMap(mapFolder)

        return (mappedFiles, mappedFolders)
    }

    private func mapFolder(_ raw: [String: Any]) -> FolderItem? {
        let path = (raw["path"] as? String) ?? (raw["fullPath"] as? String)
        guard let path, !path.isEmpty else { return nil }
        let name =
            (raw["name"] as? String) ??
            (raw["title"] as? String) ??
            URL(fileURLWithPath: path).lastPathComponent
        return FolderItem(path: path, name: name, isDirectory: true)
    }

    private func mapVideo(_ raw: [String: Any]) -> VideoItem? {
        let path = (raw["path"] as? String) ?? (raw["fullPath"] as? String)
        guard let path, !path.isEmpty else { return nil }

        let title =
            (raw["title"] as? String) ??
            (raw["name"] as? String) ??
            URL(fileURLWithPath: path).lastPathComponent

        let yearValue = raw["year"]
        let year: String?
        if let y = yearValue as? String {
            year = y
        } else if let y = yearValue as? Int {
            year = String(y)
        } else {
            year = nil
        }

        let duration =
            (raw["duration"] as? Double) ??
            (raw["durationSeconds"] as? Double) ??
            (raw["duration"] as? Int).map(Double.init) ?? 0

        let fileSize = (raw["size"] as? Int) ?? (raw["bytes"] as? Int)

        let isPlayable: Bool = {
            if let explicit = raw["isPlayableInApp"] as? Bool {
                return explicit
            }
            let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
            let supported = ["mp4", "mov", "m4v", "mkv", "avi", "webm"]
            return supported.contains(ext)
        }()

        return VideoItem(
            path: path,
            title: title,
            year: year,
            duration: duration,
            coverArt: (raw["coverArt"] as? String) ?? (raw["thumbnail"] as? String),
            streamUrl: raw["streamUrl"] as? String,
            addedAt: raw["addedAt"] as? String,
            summary: (raw["summary"] as? String) ?? (raw["description"] as? String),
            type: raw["type"] as? String,
            grandparentTitle: raw["grandparentTitle"] as? String,
            parentTitle: raw["parentTitle"] as? String,
            index: raw["index"] as? String,
            localFilePath: raw["localFilePath"] as? String,
            isLocal: raw["isLocal"] as? Bool,
            isPlayableInApp: isPlayable,
            fileSizeBytes: fileSize,
            subtitlePath: raw["subtitlePath"] as? String
        )
    }

    private func isDirectoryEntry(_ raw: [String: Any]) -> Bool {
        if let dir = raw["isDirectory"] as? Bool { return dir }
        if let dir = raw["isFolder"] as? Bool { return dir }
        let type = normalizeLibraryLabel(raw["type"] as? String)
        return type == "folder" || type == "directory"
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func persistWatchlist() {
        if let data = try? JSONEncoder().encode(watchlist) {
            UserDefaults.standard.set(data, forKey: WATCHLIST_STORAGE_KEY)
        }
    }

    private func persistPlaybackHistory() {
        if let data = try? JSONEncoder().encode(playbackHistory) {
            UserDefaults.standard.set(data, forKey: PLAYBACK_HISTORY_STORAGE_KEY)
        }
    }

    private func persistDownloads() {
        if let data = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(data, forKey: PLEX_DOWNLOADS_STORAGE_KEY)
        }
    }

    private func persistLists() {
        if let data = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(data, forKey: VIDEO_LISTS_STORAGE_KEY)
        }
    }
}

// MARK: - UI Helpers

struct ShimmerPlaceholder: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.22),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(12))
                .offset(x: phase * 280)
                .mask(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                )
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct AsyncCoverImage: View {
    let coverArt: String?

    var body: some View {
        Group {
            if let coverArt,
               let url = URL(string: coverArt),
               !coverArt.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ShimmerPlaceholder()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
            Image(systemName: "film")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }
}

enum VideoCardVariant {
    case grid
    case list
}

struct VideoCard: View {
    @ObservedObject var viewModel: MoviesViewModel
    let video: VideoItem
    let variant: VideoCardVariant
    let onPlay: () -> Void
    let onQueue: () -> Void

    var body: some View {
        Group {
            switch variant {
            case .grid:
                gridCard
            case .list:
                listCard
            }
        }
        .disabled(!video.isPlayableInApp)
        .opacity(video.isPlayableInApp ? 1 : 0.5)
    }

    private var gridCard: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncCoverImage(coverArt: video.coverArt)
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay(alignment: .bottom) {
                    if let history = viewModel.playbackHistory.first(where: { $0.path == video.path }),
                       history.progressPercent > 0,
                       history.progressPercent < 1 {
                        progressOverlay(progress: history.progressPercent)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if viewModel.downloads.contains(where: { $0.path == video.path && $0.status == .completed }) {
                        DownloadedBadge(compact: true)
                            .padding(8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    VStack(alignment: .trailing, spacing: 6) {
                        if viewModel.isWatched(video.path) {
                            WatchedBadge(compact: true)
                        }

                        Button {
                            viewModel.toggleWatchlist(video)
                        } label: {
                            Image(systemName: viewModel.isInWatchlist(video.path) ? "heart.fill" : "heart")
                        }
                        .buttonStyle(MoviesPillGhostButtonStyle())

                        Menu {
                            if viewModel.lists.isEmpty {
                                Text("No lists yet")
                            }
                            ForEach(viewModel.lists) { list in
                                Button("Add to \(list.name)") {
                                    viewModel.add(video, to: list)
                                }
                            }
                            Divider()
                            Button("Download") { viewModel.download(video) }
                            Button(viewModel.isInWatchlist(video.path) ? "Remove from Watchlist" : "Add to Watchlist") {
                                viewModel.toggleWatchlist(video)
                            }
                            Button("Add to Queue") { onQueue() }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .buttonStyle(MoviesPillGhostButtonStyle())
                    }
                    .padding(8)
                }
                .overlay(alignment: .center) {
                    if !video.isPlayableInApp {
                        Text("Unsupported format")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7), in: Capsule())
                    }
                }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(metadataText(video))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }
            .padding(10)
        }
        .background(moviesGlassPanel(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            guard video.isPlayableInApp else { return }
            onPlay()
        }
        .contextMenu {
            ForEach(viewModel.lists) { list in
                Button("Add to \(list.name)") { viewModel.add(video, to: list) }
            }
            Button("Download") { viewModel.download(video) }
            Button(viewModel.isInWatchlist(video.path) ? "Remove from Watchlist" : "Add to Watchlist") {
                viewModel.toggleWatchlist(video)
            }
            Button("Add to Queue") { onQueue() }
        }
    }

    private var listCard: some View {
        HStack(spacing: 12) {
            AsyncCoverImage(coverArt: video.coverArt)
                .frame(width: 80, height: 120)
                .overlay(alignment: .topLeading) {
                    if viewModel.downloads.contains(where: { $0.path == video.path && $0.status == .completed }) {
                        DownloadedBadge(compact: true)
                            .padding(4)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if viewModel.isWatched(video.path) {
                        WatchedBadge(compact: true)
                            .padding(4)
                    }
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(metadataText(video))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                if let history = viewModel.playbackHistory.first(where: { $0.path == video.path }),
                   history.progressPercent > 0,
                   history.progressPercent < 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: history.progressPercent)
                            .tint(Color.white)
                        Text("Resume at \(formatTime(history.progressSeconds))")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }

                if !video.isPlayableInApp {
                    Text("Unsupported format")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6), in: Capsule())
                }
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Button("Play") {
                    onPlay()
                }
                .buttonStyle(MoviesPillPrimaryButtonStyle())
                .disabled(!video.isPlayableInApp)

                Button("Download") {
                    viewModel.download(video)
                }
                .buttonStyle(MoviesPillSecondaryButtonStyle())

                Button {
                    viewModel.toggleWatchlist(video)
                } label: {
                    Image(systemName: viewModel.isInWatchlist(video.path) ? "heart.fill" : "heart")
                }
                .buttonStyle(MoviesPillGhostButtonStyle())

                Menu {
                    ForEach(viewModel.lists) { list in
                        Button("Add to \(list.name)") { viewModel.add(video, to: list) }
                    }
                    Button("Add to Queue") { onQueue() }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(MoviesPillGhostButtonStyle())
            }
        }
        .padding(10)
        .background(moviesGlassPanel(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            guard video.isPlayableInApp else { return }
            onPlay()
        }
        .contextMenu {
            ForEach(viewModel.lists) { list in
                Button("Add to \(list.name)") { viewModel.add(video, to: list) }
            }
            Button("Download") { viewModel.download(video) }
            Button(viewModel.isInWatchlist(video.path) ? "Remove from Watchlist" : "Add to Watchlist") {
                viewModel.toggleWatchlist(video)
            }
            Button("Add to Queue") { onQueue() }
        }
    }

    private func metadataText(_ video: VideoItem) -> String {
        let pieces = [
            video.year,
            video.type,
            video.fileSizeBytes.map { formatBytes($0) }
        ].compactMap { $0 }
        return pieces.isEmpty ? "Media" : pieces.joined(separator: " • ")
    }

    private func progressOverlay(progress: Double) -> some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.black.opacity(0.55))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.white)
                    .frame(width: progressBarWidth(progress), height: 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Header + Tabs

struct MoviesHeaderChrome: View {
    @ObservedObject var viewModel: MoviesViewModel
    let commandInputOpen: Bool
    let aiMode: Bool
    let onRefresh: () -> Void
    let onOpenCommand: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phoebe")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Movies")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer(minLength: 8)

                Text(viewModel.healthStatus)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(moviesGlassPanel(cornerRadius: 999))

                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(MoviesPillGhostButtonStyle())

                Button {
                    onOpenCommand()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(MoviesPillGhostButtonStyle())

                Button {
                    onOpenCommand()
                } label: {
                    Image(systemName: aiMode ? "brain.head.profile" : "sparkles")
                }
                .buttonStyle(MoviesPillGhostButtonStyle())
                .overlay(alignment: .bottomTrailing) {
                    if commandInputOpen {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.73, blue: 0.2))
                            .frame(width: 8, height: 8)
                            .offset(x: -1, y: -1)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HeaderTab.allCases) { tab in
                        Button {
                            viewModel.selectedTab = tab
                            if tab == .downloads {
                                viewModel.libraryFilter = .all
                            }
                        } label: {
                            VStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.symbol)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(tab.label)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                Rectangle()
                                    .fill(viewModel.selectedTab == tab ? Color(red: 1.0, green: 0.73, blue: 0.2) : Color.clear)
                                    .frame(height: 2)
                            }
                            .foregroundStyle(viewModel.selectedTab == tab ? .white : .white.opacity(0.72))
                            .padding(.horizontal, 10)
                            .padding(.top, 7)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct LibraryFilterBar: View {
    @ObservedObject var viewModel: MoviesViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases) { filter in
                    Button {
                        viewModel.libraryFilter = filter
                        Task {
                            await viewModel.search(query: viewModel.searchText)
                        }
                    } label: {
                        Text(filter.label)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(viewModel.libraryFilter == filter ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(viewModel.libraryFilter == filter ? Color(red: 1.0, green: 0.73, blue: 0.2) : Color.white.opacity(0.08))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(viewModel.libraryFilter == filter ? 0 : 0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Continue Watching

struct ContinueWatchingRow: View {
    @ObservedObject var viewModel: MoviesViewModel

    var body: some View {
        let entries = viewModel.continueWatchingVideos()
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Continue Watching")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(entries.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(entries, id: \.video.path) { entry in
                            Button {
                                viewModel.play(entry.video, resumeFrom: entry.history.progressSeconds)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.video.title)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)

                                    ProgressView(value: entry.history.progressPercent)
                                        .tint(.white)

                                    Text("\(formatTime(entry.history.progressSeconds)) remaining")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .frame(width: 220, alignment: .leading)
                                .padding(12)
                                .background(moviesGlassPanel(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Library Browser

struct LibraryBrowserView: View {
    @ObservedObject var viewModel: MoviesViewModel
    let includeContinueWatching: Bool

    @State private var localSearchText: String = ""

    private var displayedFiles: [VideoItem] {
        viewModel.filteredFilesForSelectedTab()
    }

    private var featured: VideoItem? {
        displayedFiles.first
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 190, maximum: 260), spacing: 12)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if includeContinueWatching {
                ContinueWatchingRow(viewModel: viewModel)
            }

            if let featured {
                featuredHero(featured)
            }

            HStack(spacing: 8) {
                TextField("Search videos", text: $localSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(moviesGlassPanel(cornerRadius: 12))

                Button("Find") {
                    Task {
                        await viewModel.search(query: localSearchText)
                    }
                }
                .buttonStyle(MoviesPillPrimaryButtonStyle())
            }

            HStack(spacing: 8) {
                Button("Up") {
                    viewModel.navigateUp()
                }
                .buttonStyle(MoviesPillSecondaryButtonStyle())
                .disabled(viewModel.currentPath == "/")

                Text(viewModel.currentPath)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                Button {
                    viewModel.viewMode = (viewModel.viewMode == .grid ? .list : .grid)
                } label: {
                    Image(systemName: viewModel.viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                }
                .buttonStyle(MoviesPillGhostButtonStyle())
            }

            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            }

            if let message = viewModel.errorMessage, !message.isEmpty {
                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.red.opacity(0.92))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(moviesGlassPanel(cornerRadius: 12))
            }

            if !viewModel.folders.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.folders) { folder in
                        Button {
                            Task { await viewModel.openFolder(folder) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(Color(red: 1.0, green: 0.73, blue: 0.2))
                                Text(folder.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(moviesGlassPanel(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if displayedFiles.isEmpty, !viewModel.isLoading {
                Text("No videos found")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 10)
            } else {
                if viewModel.viewMode == .grid {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(displayedFiles) { video in
                            VideoCard(
                                viewModel: viewModel,
                                video: video,
                                variant: .grid,
                                onPlay: { viewModel.play(video) },
                                onQueue: { enqueue(video) }
                            )
                        }
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(displayedFiles) { video in
                            VideoCard(
                                viewModel: viewModel,
                                video: video,
                                variant: .list,
                                onPlay: { viewModel.play(video) },
                                onQueue: { enqueue(video) }
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            localSearchText = viewModel.searchText
        }
    }

    private func enqueue(_ video: VideoItem) {
        if !viewModel.playlist.contains(where: { $0.path == video.path }) {
            viewModel.playlist.append(video)
        }
        if viewModel.playlistName.isEmpty {
            viewModel.playlistName = "Queue"
        }
    }

    private func featuredHero(_ video: VideoItem) -> some View {
        HStack(spacing: 12) {
            AsyncCoverImage(coverArt: video.coverArt)
                .frame(width: 150, height: 210)

            VStack(alignment: .leading, spacing: 10) {
                Text(video.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text([
                    video.year,
                    video.type,
                    video.fileSizeBytes.map(formatBytes)
                ].compactMap { $0 }.joined(separator: " • "))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))

                if let summary = video.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    Button("Play") {
                        viewModel.play(video)
                    }
                    .buttonStyle(MoviesPillPrimaryButtonStyle())
                    .disabled(!video.isPlayableInApp)

                    Button("Download") {
                        viewModel.download(video)
                    }
                    .buttonStyle(MoviesPillSecondaryButtonStyle())
                }
            }
            Spacer()
        }
        .padding(14)
        .background(moviesGlassPanel(cornerRadius: 16))
    }
}

// MARK: - Lists Tab

struct ListsTabView: View {
    @ObservedObject var viewModel: MoviesViewModel
    @State private var newListName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                TextField("New list name", text: $newListName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(moviesGlassPanel(cornerRadius: 12))

                Button("Create") {
                    viewModel.createList(name: newListName)
                    newListName = ""
                }
                .buttonStyle(MoviesPillPrimaryButtonStyle())
            }

            if viewModel.lists.isEmpty {
                Text("No lists yet")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.top, 10)
            }

            ForEach(viewModel.lists) { list in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(list.name)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            viewModel.deleteList(list)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }

                    let videos = viewModel.videos(for: list)
                    if videos.isEmpty {
                        Text("No videos yet")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    } else {
                        ForEach(Array(videos.enumerated()), id: \.element.path) { index, video in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(video.title)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(video.fileSizeBytes.map(formatBytes) ?? "Unknown size")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.62))
                                }

                                Spacer()

                                Button("Play") {
                                    viewModel.play(video)
                                }
                                .buttonStyle(MoviesPillPrimaryButtonStyle())
                                .disabled(!video.isPlayableInApp)

                                Button {
                                    viewModel.remove(video, from: list)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(MoviesPillGhostButtonStyle())
                            }

                            if index != videos.count - 1 {
                                Divider().background(Color.white.opacity(0.2))
                            }
                        }
                    }
                }
                .padding(12)
                .background(moviesGlassPanel(cornerRadius: 14))
            }
        }
    }
}

// MARK: - Downloads Tab

struct DownloadsTabView: View {
    @ObservedObject var viewModel: MoviesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.downloads.isEmpty {
                VStack(spacing: 8) {
                    Text("No downloads yet")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(moviesGlassPanel(cornerRadius: 14))
            } else {
                ForEach(viewModel.downloads) { download in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(download.filename)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        ProgressView(value: download.progress)
                            .tint(.white)

                        Text(download.status.rawValue.capitalized)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))

                        if let localPath = download.localFilePath, !localPath.isEmpty {
                            Text(localPath)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        }

                        if let error = download.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.red)
                        }

                        if download.status == .queued || download.status == .downloading {
                            Button("Cancel") {
                                viewModel.cancelDownload(download)
                            }
                            .buttonStyle(MoviesPillSecondaryButtonStyle())
                        }
                    }
                    .padding(12)
                    .background(moviesGlassPanel(cornerRadius: 14))
                }
            }
        }
    }
}

// MARK: - Queue Panel

struct QueuePanelView: View {
    @ObservedObject var viewModel: MoviesViewModel

    var body: some View {
        if viewModel.showQueue && !viewModel.playlist.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(Color(red: 1.0, green: 0.73, blue: 0.2))
                    Text(viewModel.playlistName.isEmpty ? "Queue" : viewModel.playlistName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(viewModel.playlist.count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Button {
                        viewModel.playlist = []
                        viewModel.playlistIndex = 0
                        viewModel.showQueue = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(MoviesPillGhostButtonStyle())
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.playlist.enumerated()), id: \.element.path) { index, video in
                            let isNowPlaying = index == viewModel.playlistIndex
                            let isPast = index < viewModel.playlistIndex

                            Button {
                                viewModel.jumpToPlaylist(index: index)
                            } label: {
                                HStack(spacing: 10) {
                                    ZStack {
                                        AsyncCoverImage(coverArt: video.coverArt)
                                            .frame(width: 56, height: 76)
                                        if isNowPlaying {
                                            Color(red: 1.0, green: 0.73, blue: 0.2).opacity(0.32)
                                            Image(systemName: "play.fill")
                                                .foregroundStyle(.black)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(video.title)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(isNowPlaying ? Color(red: 1.0, green: 0.73, blue: 0.2) : .white)
                                            .lineLimit(1)
                                        Text("\(video.year ?? "") \(isNowPlaying ? "• Now Playing" : "• Up Next")")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.65))
                                    }

                                    Spacer()

                                    Text(String(format: "%02d", index + 1))
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(isNowPlaying ? 0.12 : 0.05))
                                )
                                .opacity(isPast ? 0.5 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if viewModel.playlistIndex < viewModel.playlist.count - 1 {
                    let nextTitle = viewModel.playlist[viewModel.playlistIndex + 1].title
                    Button("Play Next: \(nextTitle)") {
                        viewModel.advanceToNextInPlaylist()
                    }
                    .buttonStyle(MoviesPillSecondaryButtonStyle())
                }
            }
            .padding(12)
            .frame(width: 320)
            .background(moviesGlassPanel(cornerRadius: 16))
            .padding(.trailing, 12)
        } else if !viewModel.showQueue && !viewModel.playlist.isEmpty {
            Button {
                viewModel.showQueue = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                    Text("\(viewModel.playlist.count) in queue")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color(red: 1.0, green: 0.73, blue: 0.2))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(moviesGlassPanel(cornerRadius: 999))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
    }
}

// MARK: - Command Bar

struct CommandBarView: View {
    @ObservedObject var viewModel: MoviesViewModel
    @Binding var isOpen: Bool
    @Binding var useAIMode: Bool
    @Binding var commandText: String
    @Binding var aiResponse: String
    @Binding var aiLoading: Bool
    let onSubmit: () -> Void

    @FocusState private var inputFocused: Bool

    var body: some View {
        if isOpen {
            VStack(spacing: 10) {
                if !aiResponse.isEmpty {
                    ScrollView {
                        Text(aiResponse)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 140)
                    .padding(10)
                    .background(moviesGlassPanel(cornerRadius: 12))
                }

                HStack(spacing: 8) {
                    Button {
                        useAIMode.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: useAIMode ? "brain.head.profile" : "sparkles")
                            Text(useAIMode ? "AI" : "CMD")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(useAIMode ? Color.purple : Color(red: 1.0, green: 0.73, blue: 0.2))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(moviesGlassPanel(cornerRadius: 999))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        TextField(useAIMode ? "Ask Phoebe..." : "Type a command...", text: $commandText)
                            .textFieldStyle(.plain)
                            .focused($inputFocused)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)

                        if !commandText.isEmpty {
                            Button {
                                commandText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(moviesGlassPanel(cornerRadius: 12))

                    Button {
                        onSubmit()
                    } label: {
                        if aiLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(MoviesPillGhostButtonStyle())
                    .disabled(commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiLoading)
                    .tint(useAIMode ? .purple : Color(red: 1.0, green: 0.73, blue: 0.2))

                    Button {
                        isOpen = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(MoviesPillGhostButtonStyle())
                }

                HStack {
                    Text(useAIMode ? "AI mode: sends your question to the AI endpoint." : "CMD mode: filters library and supports commands like play/show.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Text(useAIMode ? "AI" : "CMD")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(useAIMode ? .purple : Color(red: 1.0, green: 0.73, blue: 0.2))
                }
            }
            .padding(12)
            .background(moviesGlassPanel(cornerRadius: 16))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    inputFocused = true
                }
            }
        }
    }
}

// MARK: - Player

struct MoviesPlayerView: View {
    @ObservedObject var viewModel: MoviesViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var controlsVisible: Bool = true
    @State private var controlsHideTask: Task<Void, Never>?
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var isSeeking: Bool = false
    @State private var playbackRate: Float = 1
    @State private var isMuted: Bool = false
    @State private var volume: Float = 1
    @State private var captionsEnabled: Bool = true
    @State private var timeObserver: Any?

    private let playbackRates: [Float] = [0.5, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        controlsVisible.toggle()
                        scheduleControlsAutoHide()
                    }
            } else {
                ProgressView().tint(.white)
            }

            if controlsVisible {
                controlsOverlay
                    .transition(.opacity)
            }

            Button {
                closePlayer()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(MoviesPillGhostButtonStyle())
            .padding(18)
        }
        .onAppear {
            configurePlayerForSelection()
            scheduleControlsAutoHide()
        }
        .onDisappear {
            persistPlayback()
            cleanupPlayer()
        }
        .onChange(of: viewModel.selectedVideo?.path) { _, _ in
            persistPlayback()
            configurePlayerForSelection()
        }
    }

    private var controlsOverlay: some View {
        VStack {
            Spacer()

            HStack(spacing: 24) {
                Button {
                    seekBy(-10)
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 24, weight: .bold))
                }
                .buttonStyle(MoviesPillGhostButtonStyle())

                Button {
                    togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34, weight: .bold))
                }
                .buttonStyle(MoviesPillGhostButtonStyle())

                Button {
                    seekBy(10)
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 24, weight: .bold))
                }
                .buttonStyle(MoviesPillGhostButtonStyle())
            }
            .padding(.bottom, 16)

            VStack(spacing: 10) {
                HStack {
                    Text(formatTime(currentTime))
                    Spacer()
                    Text(formatTime(duration))
                }
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.78))

                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { newValue in
                            isSeeking = true
                            currentTime = min(max(0, newValue), duration)
                        }
                    ),
                    in: 0...max(duration, 1),
                    onEditingChanged: { editing in
                        if !editing {
                            seekTo(currentTime)
                            isSeeking = false
                        }
                    }
                )
                .tint(.white)

                HStack(spacing: 8) {
                    Button {
                        isMuted.toggle()
                        player?.isMuted = isMuted
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }
                    .buttonStyle(MoviesPillGhostButtonStyle())

                    Slider(value: Binding(
                        get: { Double(volume) },
                        set: { volume = Float($0); player?.volume = Float($0) }
                    ), in: 0...1)
                    .tint(.white)
                    .frame(maxWidth: 110)

                    if viewModel.selectedVideo?.subtitlePath != nil {
                        Button {
                            captionsEnabled.toggle()
                            applyCaptionPreference()
                        } label: {
                            Image(systemName: captionsEnabled ? "captions.bubble.fill" : "captions.bubble")
                        }
                        .buttonStyle(MoviesPillGhostButtonStyle())
                    }

                    Menu {
                        ForEach(playbackRates, id: \.self) { rate in
                            Button("\(String(format: "%.2gx", rate))") {
                                playbackRate = rate
                                player?.rate = isPlaying ? rate : 0
                            }
                        }
                    } label: {
                        Text("\(String(format: "%.2gx", playbackRate))")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(MoviesPillSecondaryButtonStyle())

                    Button("Queue") {
                        viewModel.showQueue.toggle()
                    }
                    .buttonStyle(MoviesPillSecondaryButtonStyle())

                    #if os(iOS) || targetEnvironment(macCatalyst)
                    AirPlayRouteButton()
                        .frame(width: 34, height: 34)
                    #endif

                    Button {
                        toggleSystemFullscreen()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(MoviesPillGhostButtonStyle())
                }
            }
            .padding(12)
            .background(moviesGlassPanel(cornerRadius: 14))
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .animation(.easeInOut(duration: 0.2), value: controlsVisible)
    }

    private func configurePlayerForSelection() {
        guard let video = viewModel.selectedVideo,
              let url = viewModel.playerURL(for: video) else { return }

        cleanupPlayer()

        var options: [String: Any] = [:]
        let headers = viewModel.client.authHeaders()
        if !headers.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = headers
        }

        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        newPlayer.volume = volume
        newPlayer.isMuted = isMuted
        player = newPlayer

        let resume = viewModel.resumePosition(for: video.path)
        if resume > RESUME_THRESHOLD_SECONDS {
            newPlayer.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
        }

        observePlayer(newPlayer)
        newPlayer.play()
        isPlaying = true
        newPlayer.rate = playbackRate
    }

    private func observePlayer(_ player: AVPlayer) {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard !isSeeking else { return }
            currentTime = max(0, time.seconds)
            duration = max(durationFromCurrentItem(player), 0)
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if let video = viewModel.selectedVideo {
                    viewModel.savePlayback(path: video.path, seconds: max(video.duration, duration), duration: max(video.duration, duration))
                }
                if viewModel.playlistIndex < viewModel.playlist.count - 1 {
                    viewModel.advanceToNextInPlaylist()
                }
            }
        }
    }

    private func durationFromCurrentItem(_ player: AVPlayer) -> Double {
        player.currentItem?.duration.seconds.isFinite == true ? (player.currentItem?.duration.seconds ?? 0) : 0
    }

    private func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
            player.rate = playbackRate
        }
        isPlaying.toggle()
        scheduleControlsAutoHide()
    }

    private func seekBy(_ seconds: Double) {
        seekTo(currentTime + seconds)
        scheduleControlsAutoHide()
    }

    private func seekTo(_ seconds: Double) {
        guard let player else { return }
        let target = CMTime(seconds: max(0, min(seconds, duration)), preferredTimescale: 600)
        player.seek(to: target)
        currentTime = max(0, min(seconds, duration))
    }

    private func applyCaptionPreference() {
        guard let item = player?.currentItem else { return }
        guard let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
        if captionsEnabled {
            item.select(group.options.first, in: group)
        } else {
            item.select(nil, in: group)
        }
    }

    private func scheduleControlsAutoHide() {
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            controlsVisible = false
        }
    }

    private func persistPlayback() {
        guard let video = viewModel.selectedVideo else { return }
        let total = max(duration, video.duration)
        viewModel.savePlayback(path: video.path, seconds: currentTime, duration: total)
    }

    private func cleanupPlayer() {
        controlsHideTask?.cancel()
        if let player, let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
    }

    private func closePlayer() {
        persistPlayback()
        dismiss()
    }

    private func toggleSystemFullscreen() {
        #if os(macOS)
        NSApp.keyWindow?.toggleFullScreen(nil)
        #endif
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = .white
        view.tintColor = UIColor.white.withAlphaComponent(0.8)
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#endif

// MARK: - Root View

struct MoviesView: View {
    @StateObject var viewModel = MoviesViewModel()

    @State private var commandInputOpen: Bool = false
    @State private var useAIMode: Bool = false
    @State private var commandText: String = ""
    @State private var aiResponse: String = ""
    @State private var aiLoading: Bool = false

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 12) {
                MoviesHeaderChrome(
                    viewModel: viewModel,
                    commandInputOpen: commandInputOpen,
                    aiMode: useAIMode,
                    onRefresh: {
                        Task { await viewModel.refreshLibrary() }
                    },
                    onOpenCommand: {
                        commandInputOpen = true
                    }
                )

                if viewModel.selectedTab != .downloads {
                    LibraryFilterBar(viewModel: viewModel)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        tabContent
                    }
                    .padding(.bottom, 80)
                }
            }
            .padding(16)

            VStack {
                Spacer()
                CommandBarView(
                    viewModel: viewModel,
                    isOpen: $commandInputOpen,
                    useAIMode: $useAIMode,
                    commandText: $commandText,
                    aiResponse: $aiResponse,
                    aiLoading: $aiLoading,
                    onSubmit: handleCommandSubmit
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            HStack {
                Spacer()
                VStack {
                    Spacer()
                    QueuePanelView(viewModel: viewModel)
                        .padding(.bottom, commandInputOpen ? 196 : 24)
                }
            }
        }
        #if os(macOS)
        .sheet(isPresented: $viewModel.isPlayerPresented) {
            MoviesPlayerView(viewModel: viewModel)
                .frame(minWidth: 960, minHeight: 540)
        }
        #else
        .fullScreenCover(isPresented: $viewModel.isPlayerPresented) {
            MoviesPlayerView(viewModel: viewModel)
        }
        #endif
        .onChange(of: viewModel.selectedVideo?.path) { _, _ in
            viewModel.isPlayerPresented = viewModel.selectedVideo != nil
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .home:
            LibraryBrowserView(viewModel: viewModel, includeContinueWatching: true)
        case .movies:
            LibraryBrowserView(viewModel: viewModel, includeContinueWatching: false)
        case .tv:
            LibraryBrowserView(viewModel: viewModel, includeContinueWatching: false)
        case .podcasts:
            LibraryBrowserView(viewModel: viewModel, includeContinueWatching: false)
        case .libraries:
            LibraryBrowserView(viewModel: viewModel, includeContinueWatching: false)
            ListsTabView(viewModel: viewModel)
        case .downloads:
            DownloadsTabView(viewModel: viewModel)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: -240, y: -300)

            Circle()
                .fill(Color.cyan.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 130)
                .offset(x: 240, y: -280)
        }
    }

    private func handleCommandSubmit() {
        let trimmed = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if useAIMode {
            Task {
                aiLoading = true
                defer { aiLoading = false }

                do {
                    let response = try await sendAICommand(trimmed)
                    aiResponse = response
                } catch {
                    aiResponse = "AI request failed: \(error.localizedDescription)"
                }
            }
            return
        }

        let lower = normalizeLibraryLabel(trimmed)

        if lower.hasPrefix("play ") {
            let title = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let match = viewModel.filteredFilesForSelectedTab().first(where: {
                normalizeLibraryLabel($0.title).contains(normalizeLibraryLabel(title))
            }) {
                viewModel.play(match)
                commandInputOpen = false
            }
            return
        }

        if lower.hasPrefix("show me all ") {
            let suffix = String(trimmed.dropFirst("show me all ".count))
            Task { await viewModel.search(query: suffix) }
            return
        }

        Task {
            await viewModel.search(query: trimmed)
        }
    }

    private func sendAICommand(_ text: String) async throws -> String {
        guard let url = URL(string: viewModel.client.baseURL + "/ai") else {
            throw NSError(domain: "MoviesView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid AI endpoint"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in viewModel.client.authHeaders() {
            request.setValue(v, forHTTPHeaderField: k)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": text])
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "MoviesView", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "AI endpoint returned \(http.statusCode)"])
        }

        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let reply = obj["response"] as? String { return reply }
            if let reply = obj["answer"] as? String { return reply }
            if let reply = obj["text"] as? String { return reply }
        }

        return String(data: data, encoding: .utf8) ?? "No response"
    }
}
