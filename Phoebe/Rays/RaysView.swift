import SwiftUI

struct RaysView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = TodoRepository()
    let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [appState.backgroundTopColor, appState.backgroundBottomColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rays")
                        .font(.system(size: appState.titleFontSize, weight: .light, design: .rounded))

                    Text("Life pillars · Todos")
                        .font(.system(size: appState.bodyFontSize, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    if repo.isRefreshing && !repo.todos.isEmpty {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                if repo.isLoading && repo.todos.isEmpty {
                    ProgressView()
                        .padding(.top, 48)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(pillars) { pillar in
                            PillarCard(pillar: pillar, repo: repo)
                        }
                    }
                    .padding(24)
                }

                if let loadError = repo.loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
            }
        }
        .task {
            await repo.loadIfNeeded()
        }
        .refreshable {
            await repo.fetchAll(force: true)
        }
        .navigationTitle("Rays")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
