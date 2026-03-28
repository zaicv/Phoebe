import Foundation
import Combine

@MainActor
final class VaultRepository: NSObject, ObservableObject {
    @Published var currentPath: String = ""
    @Published var folders: [VaultFolder] = []
    @Published var files: [VaultVideoRef] = []
    @Published var knownVideos: [VaultVideoRef] = []
    @Published var lists: [VaultList] = []
    @Published var listItems: [VaultListItem] = []
    @Published var playback: [PlaybackState] = []
    @Published var downloads: [VaultDownloadRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let settings: VaultSettingsStore
    private let persistence: VaultPersistence
    private var client: VaultBridgeClient

    private var activeUserId: String = "anonymous"
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()
    private var taskToDownloadId: [Int: UUID] = [:]
    private var taskDestinations: [Int: URL] = [:]

    init(settings: VaultSettingsStore, persistence: VaultPersistence) {
        self.settings = settings
        self.persistence = persistence
        self.client = VaultBridgeClient(settings: settings)
        super.init()
        loadSnapshot(for: activeUserId)
    }

    func configureUser(_ userId: String) {
        guard activeUserId != userId else { return }
        activeUserId = userId
        loadSnapshot(for: userId)
    }

    func refreshLibrary() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await client.library(path: currentPath)
            folders = response.folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            files = response.files.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
            mergeKnown(files)
            saveSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openFolder(_ folder: VaultFolder) async {
        currentPath = folder.path
        await refreshLibrary()
    }

    func navigateUp() async {
        guard !currentPath.isEmpty else { return }
        let components = currentPath.split(separator: "/")
        if components.count <= 1 {
            currentPath = ""
        } else {
            currentPath = components.dropLast().joined(separator: "/")
        }
        await refreshLibrary()
    }

    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            await refreshLibrary()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await client.search(query: trimmed, path: currentPath)
            files = response.files.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
            folders = []
            mergeKnown(files)
            saveSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bridgeHealth() async -> String {
        do {
            let health = try await client.health()
            return "\(health.status) (v\(health.version))"
        } catch {
            return "Unavailable"
        }
    }

    func createList(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !lists.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }

        lists.append(VaultList(id: UUID(), name: trimmed, createdAt: Date()))
        lists.sort { $0.createdAt < $1.createdAt }
        saveSnapshot()
    }

    func deleteList(_ list: VaultList) {
        listItems.removeAll { $0.listId == list.id }
        lists.removeAll { $0.id == list.id }
        saveSnapshot()
    }

    func add(_ video: VaultVideoRef, to list: VaultList) {
        guard !listItems.contains(where: { $0.listId == list.id && $0.videoId == video.id }) else { return }
        listItems.append(VaultListItem(id: UUID(), listId: list.id, videoId: video.id, addedAt: Date()))
        mergeKnown([video])
        saveSnapshot()
    }

    func remove(_ video: VaultVideoRef, from list: VaultList) {
        listItems.removeAll { $0.listId == list.id && $0.videoId == video.id }
        saveSnapshot()
    }

    func videos(for list: VaultList) -> [VaultVideoRef] {
        let set = Set(listItems.filter { $0.listId == list.id }.map(\.videoId))
        return knownVideos.filter { set.contains($0.id) }.sorted {
            $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending
        }
    }

    func playerURL(for video: VaultVideoRef) -> URL? {
        client.streamURL(videoId: video.id)
    }

    func download(_ video: VaultVideoRef) {
        guard let destinationRoot = persistence.downloadsDirectory(userId: activeUserId),
              let url = client.downloadURL(videoId: video.id) else {
            return
        }

        let record = VaultDownloadRecord(
            id: UUID(),
            videoId: video.id,
            filename: video.filename,
            startedAt: Date(),
            progress: 0,
            status: .queued,
            localFilePath: nil,
            errorMessage: nil
        )
        downloads.insert(record, at: 0)
        saveSnapshot()

        var request = URLRequest(url: url)
        client.authHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let task = session.downloadTask(with: request)
        taskToDownloadId[task.taskIdentifier] = record.id
        taskDestinations[task.taskIdentifier] = destinationRoot.appendingPathComponent(uniqueFilename(video.filename))
        updateDownload(id: record.id) {
            $0.status = .running
        }
        task.resume()
    }

    func resumePosition(for videoId: String) -> Double {
        playback.first(where: { $0.videoId == videoId })?.lastPositionSeconds ?? 0
    }

    func savePlayback(videoId: String, seconds: Double) {
        guard seconds.isFinite, seconds >= 0 else { return }
        if let idx = playback.firstIndex(where: { $0.videoId == videoId }) {
            playback[idx].lastPositionSeconds = seconds
            playback[idx].lastPlayedAt = Date()
        } else {
            playback.append(PlaybackState(videoId: videoId, lastPositionSeconds: seconds, lastPlayedAt: Date()))
        }
        saveSnapshot()
    }

    private func loadSnapshot(for userId: String) {
        let snapshot = persistence.loadSnapshot(userId: userId)
        knownVideos = snapshot.knownVideos
        lists = snapshot.lists
        listItems = snapshot.listItems
        playback = snapshot.playback
        downloads = snapshot.downloads

        if lists.isEmpty {
            lists = [
                VaultList(id: UUID(), name: "Favorites", createdAt: Date()),
                VaultList(id: UUID(), name: "Watch Later", createdAt: Date().addingTimeInterval(1))
            ]
            saveSnapshot()
        }
    }

    private func mergeKnown(_ incoming: [VaultVideoRef]) {
        var byId = Dictionary(uniqueKeysWithValues: knownVideos.map { ($0.id, $0) })
        incoming.forEach { byId[$0.id] = $0 }
        knownVideos = Array(byId.values)
    }

    private func updateDownload(id: UUID, mutate: (inout VaultDownloadRecord) -> Void) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        var copy = downloads[index]
        mutate(&copy)
        downloads[index] = copy
        saveSnapshot()
    }

    private func findDownloadId(for task: URLSessionTask) -> UUID? {
        taskToDownloadId[task.taskIdentifier]
    }

    private func saveSnapshot() {
        let snapshot = VaultSnapshot(
            knownVideos: knownVideos,
            lists: lists,
            listItems: listItems,
            playback: playback,
            downloads: downloads
        )
        persistence.saveSnapshot(snapshot, userId: activeUserId)
    }

    private func uniqueFilename(_ name: String) -> String {
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        if ext.isEmpty {
            return "\(stem)-\(timestamp)"
        }
        return "\(stem)-\(timestamp).\(ext)"
    }
}

extension VaultRepository: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1)
        Task { @MainActor in
            guard let id = self.findDownloadId(for: downloadTask) else { return }
            self.updateDownload(id: id) { $0.progress = progress }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in
            guard let id = self.findDownloadId(for: downloadTask),
                  let destination = self.taskDestinations[downloadTask.taskIdentifier] else {
                return
            }

            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try fm.moveItem(at: location, to: destination)
                self.updateDownload(id: id) {
                    $0.status = .completed
                    $0.progress = 1
                    $0.localFilePath = destination.path
                    $0.errorMessage = nil
                }
            } catch {
                self.updateDownload(id: id) {
                    $0.status = .failed
                    $0.errorMessage = error.localizedDescription
                }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else {
            Task { @MainActor in
                self.taskToDownloadId.removeValue(forKey: task.taskIdentifier)
                self.taskDestinations.removeValue(forKey: task.taskIdentifier)
            }
            return
        }

        Task { @MainActor in
            if let id = self.findDownloadId(for: task) {
                self.updateDownload(id: id) {
                    $0.status = .failed
                    $0.errorMessage = error.localizedDescription
                }
            }
            self.taskToDownloadId.removeValue(forKey: task.taskIdentifier)
            self.taskDestinations.removeValue(forKey: task.taskIdentifier)
        }
    }
}
