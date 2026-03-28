import Foundation

final class VaultPersistence {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSnapshot(userId: String) -> VaultSnapshot {
        guard let url = snapshotURL(userId: userId),
              let data = try? Data(contentsOf: url),
              let snapshot = try? decoder.decode(VaultSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func saveSnapshot(_ snapshot: VaultSnapshot, userId: String) {
        guard let url = snapshotURL(userId: userId),
              let data = try? encoder.encode(snapshot) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    func downloadsDirectory(userId: String) -> URL? {
        guard let root = rootDirectory() else { return nil }
        let directory = root.appendingPathComponent("downloads-\(safe(userId))", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func snapshotURL(userId: String) -> URL? {
        guard let root = rootDirectory() else { return nil }
        return root.appendingPathComponent("snapshot-\(safe(userId)).json")
    }

    private func rootDirectory() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let root = support.appendingPathComponent("Vault", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func safe(_ text: String) -> String {
        text.replacingOccurrences(of: "/", with: "_")
    }
}
