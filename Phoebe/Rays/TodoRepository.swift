import Foundation
import Combine
import Supabase

@MainActor
class TodoRepository: ObservableObject {
    @Published var todos: [Todo] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var loadError: String?

    private let client = SupabaseManager.shared.client
    private let goalGroups = pillars.map { $0.goalGroup }
    private var inFlightFetch: Task<[Todo], Error>?
    private var lastFetchAt: Date?
    private let minimumRefreshInterval: TimeInterval = 20
    private let defaults = UserDefaults.standard

    init() {
        restoreCachedTodos()
    }

    func loadIfNeeded() async {
        await fetchAll(force: false)
    }

    func fetchAll(force: Bool = true) async {
        guard let userId = SupabaseManager.shared.session?.user.id else {
            loadError = "No active session."
            return
        }

        if !force,
           let lastFetchAt,
           Date().timeIntervalSince(lastFetchAt) < minimumRefreshInterval {
            return
        }

        if todos.isEmpty {
            isLoading = true
        }
        isRefreshing = true
        loadError = nil

        do {
            let result: [Todo]
            if let inFlightFetch {
                result = try await inFlightFetch.value
            } else {
                let task = Task<[Todo], Error> {
                    try await self.fetchWithRetry(userId: userId)
                }
                inFlightFetch = task
                defer { inFlightFetch = nil }
                result = try await task.value
            }

            todos = result
            cacheTodos(result, for: userId)
            lastFetchAt = Date()
        } catch {
            loadError = "Couldn't refresh todos. Showing latest cached data."
            print("fetchAll error: \(error)")
        }
        isLoading = false
        isRefreshing = false
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

            await fetchAll(force: true)
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

            await fetchAll(force: true)
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
            await fetchAll(force: true)
        }
    }

    func todos(for pillar: LifePillar) -> [Todo] {
        todos.filter { $0.goal_group == pillar.goalGroup }
    }

    func completedCount(for pillar: LifePillar) -> Int {
        todos(for: pillar).filter { $0.isCompleted }.count
    }

    private func fetchWithRetry(userId: UUID) async throws -> [Todo] {
        var attempt = 0
        var delayNanos: UInt64 = 300_000_000
        var lastError: Error?

        while attempt < 3 {
            do {
                return try await client
                    .from("todos")
                    .select("id,title,status,priority,goal_group,user_id,created_at")
                    .eq("user_id", value: userId.uuidString)
                    .in("goal_group", values: goalGroups)
                    .order("priority", ascending: true)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            } catch {
                lastError = error
                attempt += 1
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: delayNanos)
                    delayNanos *= 2
                }
            }
        }

        throw lastError ?? URLError(.badServerResponse)
    }

    private func cacheTodos(_ todos: [Todo], for userId: UUID) {
        guard let data = try? JSONEncoder().encode(todos) else { return }
        defaults.set(data, forKey: cacheKey(for: userId))
        defaults.set(userId.uuidString, forKey: "todos.cache.lastUser")
    }

    private func restoreCachedTodos() {
        guard let lastUser = defaults.string(forKey: "todos.cache.lastUser"),
              let userId = UUID(uuidString: lastUser),
              let data = defaults.data(forKey: cacheKey(for: userId)),
              let cached = try? JSONDecoder().decode([Todo].self, from: data) else {
            return
        }
        todos = cached
    }

    private func cacheKey(for userId: UUID) -> String {
        "todos.cache.\(userId.uuidString)"
    }
}
