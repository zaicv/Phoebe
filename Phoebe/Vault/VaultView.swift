import SwiftUI
import Auth

struct VaultView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case library = "Library"
        case lists = "Lists"
        case downloads = "Downloads"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .library: return "film.stack"
            case .lists: return "list.bullet"
            case .downloads: return "arrow.down.circle"
            }
        }
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
    @State private var isPlayerPresented: Bool = false

    init() {
        let settings = VaultSettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _repo = StateObject(wrappedValue: VaultRepository(settings: settings, persistence: VaultPersistence()))
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topChrome
                    tabBar

                    switch selectedTab {
                    case .library:
                        libraryTab
                    case .lists:
                        listsTab
                    case .downloads:
                        downloadsTab
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
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
        #if os(iOS)
        .fullScreenCover(isPresented: $isPlayerPresented, onDismiss: {
            selectedVideo = nil
        }) {
            playerDestination
        }
        #else
        .sheet(isPresented: $isPlayerPresented, onDismiss: {
            selectedVideo = nil
        }) {
            playerDestination
        }
        #endif
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.06, green: 0.08, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 420, height: 420)
                .blur(radius: 80)
                .offset(x: -150, y: -260)

            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: 220, y: -120)
        }
    }

    private var topChrome: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vault Stream")
                    .font(.system(size: appState.titleFontSize * 0.58, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("Bridge: \(healthStatus) · \(settings.rootLabel)")
                    .font(.system(size: appState.bodyFontSize - 1, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await repo.refreshLibrary() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(PillGhostButtonStyle())

                Button {
                    Task { await repo.search(query: searchText) }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(PillGhostButtonStyle())
            }
        }
        .padding(14)
        .background(glassPanel(cornerRadius: 24))
    }

    private var tabBar: some View {
        HStack(spacing: 10) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(selectedTab == tab ? .black : .white.opacity(0.8))
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selectedTab == tab ? Color.white : Color.white.opacity(0.09))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(glassPanel(cornerRadius: 999))
    }

    private var libraryTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let featured = repo.files.first {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Featured")
                        .font(.system(size: appState.bodyFontSize - 1, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(featured.filename)
                                .font(.system(size: appState.bodyFontSize + 4, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            Text([featured.displaySize, featured.isPlayableInApp ? "MP4/MOV Ready" : "Unsupported for in-app play"].joined(separator: " • "))
                                .font(.system(size: appState.bodyFontSize - 1, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        Spacer(minLength: 12)
                        HStack(spacing: 8) {
                            Button("Play") {
                                if featured.isPlayableInApp {
                                    selectedVideo = featured
                                    isPlayerPresented = true
                                }
                            }
                            .buttonStyle(PillPrimaryButtonStyle())
                            .disabled(!featured.isPlayableInApp)

                            Button("Download") {
                                repo.download(featured)
                            }
                            .buttonStyle(PillSecondaryButtonStyle())
                        }
                    }
                }
                .padding(16)
                .background(glassPanel(cornerRadius: 28))
            }

            HStack(spacing: 8) {
                TextField("Search videos", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: appState.bodyFontSize, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )

                Button("Find") {
                    Task { await repo.search(query: searchText) }
                }
                .buttonStyle(PillPrimaryButtonStyle())
            }

            HStack {
                Button("Up") {
                    Task { await repo.navigateUp() }
                }
                .buttonStyle(PillSecondaryButtonStyle())
                .disabled(repo.currentPath.isEmpty)

                Text(repo.currentPath.isEmpty ? "/" : "/\(repo.currentPath)")
                    .font(.system(size: appState.bodyFontSize - 1, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                Spacer()
            }

            if repo.isLoading {
                ProgressView()
                    .tint(.white)
            }

            if let errorMessage = repo.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.9))
            }

            LazyVStack(spacing: 10) {
                ForEach(repo.folders) { folder in
                    Button {
                        Task { await repo.openFolder(folder) }
                    } label: {
                        HStack {
                            Label(folder.name, systemImage: "folder.fill")
                                .font(.system(size: appState.bodyFontSize, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .padding(14)
                        .background(glassPanel(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(repo.files) { video in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Label(video.filename, systemImage: video.isPlayableInApp ? "film.fill" : "doc.fill")
                                .font(.system(size: appState.bodyFontSize, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(2)

                            Spacer(minLength: 8)

                            Menu {
                                ForEach(repo.lists) { list in
                                    Button("Add to \(list.name)") {
                                        repo.add(video, to: list)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        Text("\(video.displaySize) • \(video.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        HStack(spacing: 8) {
                            Button("Play") {
                                if video.isPlayableInApp {
                                    selectedVideo = video
                                    isPlayerPresented = true
                                }
                            }
                            .buttonStyle(PillPrimaryButtonStyle())
                            .disabled(!video.isPlayableInApp)

                            Button("Download") {
                                repo.download(video)
                            }
                            .buttonStyle(PillSecondaryButtonStyle())
                        }
                    }
                    .padding(14)
                    .background(glassPanel(cornerRadius: 24))
                }
            }
        }
    }

    private var listsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("New list name", text: $newListName)
                    .textFieldStyle(.plain)
                    .font(.system(size: appState.bodyFontSize, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )

                Button("Create") {
                    repo.createList(name: newListName)
                    newListName = ""
                }
                .buttonStyle(PillPrimaryButtonStyle())
            }

            ForEach(repo.lists) { list in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(list.name)
                            .font(.system(size: appState.bodyFontSize + 1, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Button(role: .destructive) {
                            repo.deleteList(list)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }

                    let listVideos = repo.videos(for: list)
                    if listVideos.isEmpty {
                        Text("No videos yet")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.55))
                    } else {
                        ForEach(listVideos) { video in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(video.filename)
                                        .font(.system(size: appState.bodyFontSize, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    Text(video.displaySize)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                Spacer(minLength: 8)
                                Button("Play") {
                                    if video.isPlayableInApp {
                                        selectedVideo = video
                                        isPlayerPresented = true
                                    }
                                }
                                .buttonStyle(PillSecondaryButtonStyle())
                                .disabled(!video.isPlayableInApp)

                                Button(role: .destructive) {
                                    repo.remove(video, from: list)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            if video.id != listVideos.last?.id {
                                Divider().overlay(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
                .padding(14)
                .background(glassPanel(cornerRadius: 24))
            }
        }
    }

    private var downloadsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            if repo.downloads.isEmpty {
                Text("No downloads yet")
                    .font(.system(size: appState.bodyFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(glassPanel(cornerRadius: 22))
            }

            ForEach(repo.downloads) { download in
                VStack(alignment: .leading, spacing: 8) {
                    Text(download.filename)
                        .font(.system(size: appState.bodyFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    ProgressView(value: download.progress)
                        .tint(.white)

                    HStack(spacing: 8) {
                        Text(download.status.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))

                        if let path = download.localFilePath {
                            Text(path)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(1)
                        }

                        if let error = download.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.9))
                        }
                    }
                }
                .padding(14)
                .background(glassPanel(cornerRadius: 22))
            }
        }
    }

    private func glassPanel(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var playerDestination: some View {
        if let video = selectedVideo, let streamURL = repo.playerURL(for: video) {
            VaultPlayerView(
                video: video,
                streamURL: streamURL,
                headers: VaultBridgeClient(settings: settings).authHeaders(),
                startSeconds: repo.resumePosition(for: video.id),
                onSavePosition: { position in
                    repo.savePlayback(videoId: video.id, seconds: position)
                }
            )
        } else {
            Text("Invalid stream URL")
                .padding()
        }
    }
}

private struct PillPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(configuration.isPressed ? 0.85 : 1)))
    }
}

private struct PillSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule(style: .continuous).fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.12)))
            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 0.8))
    }
}

private struct PillGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(0.85))
            .padding(10)
            .background(Circle().fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0.12)))
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
    }
}
