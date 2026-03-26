import SwiftUI

struct LifePillar: Identifiable {
    let id: String
    let name: String
    let icon: String // SF Symbol name
    let color: Color
    let goalGroup: String
}

// IMPORTANT: goalGroup string values must match exactly what is stored
// in the Supabase todos.goal_group column. Verify these against your DB.
let pillars: [LifePillar] = [
    LifePillar(id: "glow-project", name: "The Glow Project", icon: "sparkles", color: Color(hex: "#FACC15"), goalGroup: "glow_project"),
    LifePillar(id: "career", name: "$75K Career", icon: "briefcase", color: Color(hex: "#22C55E"), goalGroup: "career_75k"),
    LifePillar(id: "education", name: "Education & Academic", icon: "graduationcap", color: Color(hex: "#3B82F6"), goalGroup: "education"),
    LifePillar(id: "m-and-i", name: "M & I", icon: "heart", color: Color(hex: "#EC4899"), goalGroup: "m_and_i"),
    LifePillar(id: "family", name: "Family", icon: "person.3", color: Color(hex: "#A855F7"), goalGroup: "family"),
    LifePillar(id: "ava", name: "Ava", icon: "figure.and.child.holdinghands", color: Color(hex: "#FB7185"), goalGroup: "ava"),
    LifePillar(id: "setpoint", name: "Setpoint", icon: "waveform.path.ecg", color: Color(hex: "#14B8A6"), goalGroup: "setpoint"),
]
