import SwiftUI

struct RaysView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = TodoRepository()
    private let cardWidth: CGFloat = 320
    private let gridSpacing: CGFloat = 16
    private var columns: [GridItem] {
        [
            GridItem(.fixed(cardWidth), spacing: gridSpacing),
            GridItem(.fixed(cardWidth), spacing: gridSpacing),
            GridItem(.fixed(cardWidth), spacing: gridSpacing)
        ]
    }
    private var gridMinWidth: CGFloat {
        (cardWidth * 3) + (gridSpacing * 2)
    }

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
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            ForEach(pillars) { pillar in
                                PillarCard(pillar: pillar, repo: repo)
                                    .frame(width: cardWidth)
                            }
                        }
                        .frame(minWidth: gridMinWidth, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
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
