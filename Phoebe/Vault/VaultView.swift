import SwiftUI
import Auth

struct VaultView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case library = "Library"
        case lists = "Lists"
        case downloads = "Downloads"

        var id: String { rawValue }
    }

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var supabaseManager: SupabaseManager

    @StateObject private var settings: VaultSettingsStore
    @StateObject private var repo: VaultRepository

    @State private var selectedTab: Tab = .library
    @State private var searchText: String = ""
    @State private var newListName: String = ""
    @State private var healthStatus: String = "Unknown"
    @State private var selectedVideo: VaultVideoRef?

    init() {
        let settings = VaultSettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _repo = StateObject(wrappedValue: VaultRepository(settings: settings, persistence: VaultPersistence()))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [appState.backgroundTopColor, appState.backgroundBottomColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                header

                Picker("View", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .library:
                    libraryTab
                case .lists:
                    listsTab
                case .downloads:
                    downloadsTab
                }
            }
            .padding(20)
        }
        .navigationTitle("Vault")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            let userId = supabaseManager.session?.user.id.uuidString ?? "anonymous"
            repo.configureUser(userId)
            if repo.files.isEmpty && repo.folders.isEmpty {
                await repo.refreshLibrary()
            }
            healthStatus = await repo.bridgeHealth()
        }
        .sheet(item: $selectedVideo) { video in
            NavigationStack {
                if let streamURL = repo.playerURL(for: video) {
                    VaultPlayerView(
                        video: video,
                        streamURL: streamURL,
                        headers: VaultBridgeClient(settings: settings).authHeaders(),
                        startSeconds: repo.resumePosition(for: video.id),
                        onSavePosition: { position in
                            repo.savePlayback(videoId: video.id, seconds: position)
                        }
                    )
                    .environmentObject(appState)
                } else {
                    Text("Invalid stream URL")
                        .padding()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remote Video Vault")
                .font(.system(size: appState.titleFontSize * 0.62, weight: .light, design: .rounded))

            Text("Bridge: \(healthStatus) · Root: \(settings.rootLabel)")
                .font(.system(size: appState.bodyFontSize, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    private var libraryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Search videos", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Button("Find") {
                    Task { await repo.search(query: searchText) }
                }
                .buttonStyle(.borderedProminent)

                Button("Refresh") {
                    Task { await repo.refreshLibrary() }
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Button("Up") {
                    Task { await repo.navigateUp() }
                }
                .buttonStyle(.bordered)
                .disabled(repo.currentPath.isEmpty)

                Text(repo.currentPath.isEmpty ? "/" : "/\(repo.currentPath)")
                    .font(.system(size: appState.bodyFontSize, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
            }

            if repo.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = repo.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            List {
                ForEach(repo.folders) { folder in
                    Button {
                        Task { await repo.openFolder(folder) }
                    } label: {
                        Label(folder.name, systemImage: "folder")
                    }
                }

                ForEach(repo.files) { video in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(video.filename, systemImage: video.isPlayableInApp ? "film" : "doc")
                            Spacer()
                            Menu {
                                ForEach(repo.lists) { list in
                                    Button("Add to \(list.name)") {
                                        repo.add(video, to: list)
                                    }
                                }
                            } label: {
                                Image(systemName: "list.bullet")
                            }
                        }

                        HStack(spacing: 10) {
                            Text(video.displaySize)
                                .foregroundColor(.secondary)
                            Text(video.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)

                        HStack(spacing: 8) {
                            Button("Play") {
                                guard video.isPlayableInApp else { return }
                                selectedVideo = video
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!video.isPlayableInApp)

                            Button("Download") {
                                repo.download(video)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }

    private var listsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("New list name", text: $newListName)
                    .textFieldStyle(.roundedBorder)

                Button("Create") {
                    repo.createList(name: newListName)
                    newListName = ""
                }
                .buttonStyle(.borderedProminent)
            }

            List {
                ForEach(repo.lists) { list in
                    Section {
                        ForEach(repo.videos(for: list)) { video in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(video.filename)
                                    Text(video.displaySize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Play") {
                                    guard video.isPlayableInApp else { return }
                                    selectedVideo = video
                                }
                                .buttonStyle(.bordered)
                                .disabled(!video.isPlayableInApp)

                                Button(role: .destructive) {
                                    repo.remove(video, from: list)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(list.name)
                            Spacer()
                            Button(role: .destructive) {
                                repo.deleteList(list)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
    }

    private var downloadsTab: some View {
        List {
            if repo.downloads.isEmpty {
                Text("No downloads yet")
                    .foregroundColor(.secondary)
            }

            ForEach(repo.downloads) { download in
                VStack(alignment: .leading, spacing: 6) {
                    Text(download.filename)
                        .font(.system(size: appState.bodyFontSize, weight: .medium, design: .rounded))

                    ProgressView(value: download.progress)

                    HStack(spacing: 8) {
                        Text(download.status.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let path = download.localFilePath {
                            Text(path)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        if let error = download.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}
