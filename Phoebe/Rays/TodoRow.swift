import SwiftUI

struct TodoRow: View {
    @EnvironmentObject var appState: AppState
    let todo: Todo
    let pillarColor: Color
    @ObservedObject var repo: TodoRepository
    @State private var isEditing = false
    @State private var editTitle = ""

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Toggle button
            Button {
                Task { await repo.toggle(todo) }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Title or edit field
            if isEditing {
                TextField("", text: $editTitle)
                    .font(.subheadline)
                    .onSubmit { submitEdit() }
                    .onAppear { editTitle = todo.title }
            } else {
                Text(todo.title)
                    .font(.subheadline)
                    .strikethrough(todo.isCompleted)
                    .foregroundColor(todo.isCompleted ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Priority dot
            if let priority = todo.priority, !todo.isCompleted {
                Circle()
                    .fill(priorityColor(priority))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task { await repo.delete(todo) }
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                isEditing = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(appState.accentColor)
        }
    }

    private func submitEdit() {
        let trimmed = editTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { isEditing = false; return }

        Task {
            await repo.updateTitle(todo, title: trimmed)
        }

        isEditing = false
    }

    private func priorityColor(_ p: Int) -> Color {
        switch p {
        case ...1: return .red
        case 2: return .yellow
        default: return .blue
        }
    }
}
