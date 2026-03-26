import Foundation

struct Todo: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var status: String // "pending" or "completed"
    var priority: Int?
    var goal_group: String
    let user_id: String
    let created_at: String

    var isCompleted: Bool {
        status == "completed"
    }
}
