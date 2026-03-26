import SwiftUI

struct RaysView: View {
    @StateObject private var repo = TodoRepository()
    let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rays")
                    .font(.largeTitle)
                    .fontWeight(.light)

                Text("Life pillars · Todos")
                    .font(.subheadline)
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
        .task {
            await repo.fetchAll()
        }
        .navigationTitle("Rays")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
