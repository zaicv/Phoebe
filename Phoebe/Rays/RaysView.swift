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
                        .font(.system(size: 34, weight: .light, design: .rounded))

                    Text("Life pillars · Todos")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                if repo.isLoading {
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
            }
        }
        .task {
            await repo.fetchAll()
        }
        .navigationTitle("Rays")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
