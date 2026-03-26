import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PillarCard: View {
    let pillar: LifePillar
    @ObservedObject var repo: TodoRepository
    @State private var isAdding = false
    @State private var newTitle = ""

    var todos: [Todo] { repo.todos(for: pillar) }
    var completed: Int { repo.completedCount(for: pillar) }
    var total: Int { todos.count }
    var progress: Double { total > 0 ? Double(completed) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(pillar.color.opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: pillar.icon)
                            .font(.system(size: 14))
                            .foregroundColor(pillar.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pillar.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("\(completed)/\(total) completed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressTrackColor)
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(pillar.color.opacity(0.6))
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(16)
            .background(headerBackgroundColor)

            Divider()

            // Todos list
            VStack(spacing: 0) {
                ForEach(todos) { todo in
                    TodoRow(todo: todo, pillarColor: pillar.color, repo: repo)
                    Divider().padding(.leading, 40)
                }

                // Add todo
                if isAdding {
                    HStack {
                        TextField("New todo...", text: $newTitle)
                            .font(.subheadline)
                            .onSubmit { submitNew() }

                        Button("Add", action: submitNew)
                            .font(.subheadline)
                            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                } else {
                    Button {
                        isAdding = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("Add todo")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(cardBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderStrokeColor, lineWidth: 0.5)
        )
    }

    private func submitNew() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        Task {
            await repo.create(title: trimmed, goalGroup: pillar.goalGroup)
        }

        newTitle = ""
        isAdding = false
    }

    private var progressTrackColor: Color {
        #if os(iOS)
        Color(.secondarySystemFill)
        #else
        Color(nsColor: .separatorColor).opacity(0.3)
        #endif
    }

    private var headerBackgroundColor: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    private var cardBackgroundColor: Color {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(nsColor: .textBackgroundColor)
        #endif
    }

    private var borderStrokeColor: Color {
        #if os(iOS)
        Color(.separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }
}
