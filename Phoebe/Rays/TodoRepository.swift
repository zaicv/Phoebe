import Foundation
import Combine
import Supabase

@MainActor
class TodoRepository: ObservableObject {
    @Published var todos: [Todo] = []
    @Published var isLoading = false

    private let client = SupabaseManager.shared.client
    private let goalGroups = pillars.map { $0.goalGroup }

    func fetchAll() async {
        isLoading = true
        do {
            guard let userId = SupabaseManager.shared.session?.user.id else { return }

            let result: [Todo] = try await client
                .from("todos")
                .select()
                .eq("user_id", value: userId.uuidString)
                .in("goal_group", values: goalGroups)
                .order("priority", ascending: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            todos = result
        } catch {
            print("fetchAll error: \(error)")
        }
        isLoading = false
    }

    func toggle(_ todo: Todo) async {
        let newStatus = todo.isCompleted ? "pending" : "completed"

        // Optimistic update
        if let idx = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[idx].status = newStatus
        }

        do {
            try await client
                .from("todos")
                .update(["status": newStatus])
                .eq("id", value: todo.id)
                .execute()
        } catch {
            print("toggle error: \(error)")
            await fetchAll()
        }
    }

    func create(title: String, goalGroup: String) async {
        guard let userId = SupabaseManager.shared.session?.user.id else { return }

        do {
            try await client
                .from("todos")
                .insert([
                    "user_id": userId.uuidString,
                    "title": title.trimmingCharacters(in: .whitespaces),
                    "goal_group": goalGroup,
                    "priority": "2",
                    "status": "pending"
                ])
                .execute()

            await fetchAll()
        } catch {
            print("create error: \(error)")
        }
    }

    func updateTitle(_ todo: Todo, title: String) async {
        do {
            try await client
                .from("todos")
                .update(["title": title.trimmingCharacters(in: .whitespaces)])
                .eq("id", value: todo.id)
                .execute()

            await fetchAll()
        } catch {
            print("updateTitle error: \(error)")
        }
    }

    func delete(_ todo: Todo) async {
        do {
            try await client
                .from("todos")
                .delete()
                .eq("id", value: todo.id)
                .execute()

            todos.removeAll { $0.id == todo.id }
        } catch {
            print("delete error: \(error)")
        }
    }

    func move(_ todoIds: [String], to goalGroup: String) async {
        // Optimistic update
        for id in todoIds {
            if let idx = todos.firstIndex(where: { $0.id == id }) {
                todos[idx].goal_group = goalGroup
            }
        }

        do {
            try await client
                .from("todos")
                .update(["goal_group": goalGroup])
                .in("id", values: todoIds)
                .execute()
        } catch {
            print("move error: \(error)")
            await fetchAll()
        }
    }

    func todos(for pillar: LifePillar) -> [Todo] {
        todos.filter { $0.goal_group == pillar.goalGroup }
    }

    func completedCount(for pillar: LifePillar) -> Int {
        todos(for: pillar).filter { $0.isCompleted }.count
    }
}
