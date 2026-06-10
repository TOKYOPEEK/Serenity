import Foundation
import SwiftUI

// MARK: - Localization
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

// MARK: - Weekday helper
func weekdayName(_ weekday: Int) -> String {
    guard weekday >= 1 && weekday <= 7 else { return "" }
    return L("weekday.\(weekday)")
}

// MARK: - Color hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 100, 100, 100)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - AppColorTheme
enum AppColorTheme: String, CaseIterable, Codable {
    case cosmic, aurora, midnight, forest, rose

    var primaryColor: Color {
        switch self {
        case .cosmic:   return Color(hex: "8B7CF8")
        case .aurora:   return Color(hex: "22D3EE")
        case .midnight: return Color(hex: "60A5FA")
        case .forest:   return Color(hex: "34D399")
        case .rose:     return Color(hex: "F87171")
        }
    }

    var secondaryColor: Color {
        switch self {
        case .cosmic:   return Color(hex: "A5B4FC")
        case .aurora:   return Color(hex: "818CF8")
        case .midnight: return Color(hex: "818CF8")
        case .forest:   return Color(hex: "6EE7B7")
        case .rose:     return Color(hex: "FCA5A5")
        }
    }

    var orbColor: Color {
        switch self {
        case .cosmic:   return Color(hex: "3D2E8A")
        case .aurora:   return Color(hex: "0E7490")
        case .midnight: return Color(hex: "1E40AF")
        case .forest:   return Color(hex: "065F46")
        case .rose:     return Color(hex: "9F1239")
        }
    }

    var name: String { L("theme.\(rawValue)") }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - AIInsight
struct AIInsight: Codable {
    var emoji: String
    var title: String
    var body: String
    var tip: String
    var tone: String
}

// MARK: - MoodEntry
struct MoodEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date = Date()
    var moodIndex: Int
    var energyLevel: Double
    var stressLevel: Double
    var tags: [String]
    var note: String
    var aiInsight: AIInsight?

    var moodEmoji: String { ["😔", "😕", "😐", "🙂", "😊"][moodIndex] }

    var moodName: String {
        [L("mood.veryBad"), L("mood.bad"), L("mood.neutral"),
         L("mood.good"), L("mood.great")][moodIndex]
    }
}

// MARK: - JournalEntry
struct JournalEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date = Date()
    var title: String
    var content: String
    var mood: Int?
}

// MARK: - GratitudeEntry
struct GratitudeEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date = Date()
    var text: String
}

// MARK: - ChatMessage
struct ChatMessage: Codable, Identifiable {
    enum Role: String, Codable {
        case user, assistant
    }

    var id = UUID()
    var role: Role
    var content: String
    var timestamp: Date = Date()
}

// MARK: - WellnessProgram
struct WellnessProgram: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var duration: Int
    var category: ProgramCategory
    var tasks: [ProgramTask]
    var isActive: Bool = false
    var startDate: Date?
    var currentDay: Int = 0

    enum ProgramCategory: String, Codable {
        case calm, energy, stress

        var icon: String {
            switch self {
            case .calm:   return "moon.fill"
            case .energy: return "bolt.fill"
            case .stress: return "leaf.fill"
            }
        }

        var displayName: String {
            switch self {
            case .calm:   return L("program.category.calm")
            case .energy: return L("program.category.energy")
            case .stress: return L("program.category.stress")
            }
        }
    }
}

struct ProgramTask: Codable, Identifiable {
    var id: String
    var day: Int
    var title: String
    var taskDescription: String
    var exerciseId: String?
    var isCompleted: Bool = false
}

// MARK: - Badge
struct Badge: Codable, Identifiable {
    var id: String
    var title: String
    var badgeDescription: String
    var icon: String
    var isUnlocked: Bool = false
    var unlockedDate: Date?
}

// MARK: - WeeklyStats
struct WeeklyStats {
    var averageMood: Double
    var totalEntries: Int
    var topMood: Int
    var topTags: [String]
    var streak: Int
}

extension WeeklyStats {
    /// Pure computation over the last 7 days of entries.
    static func compute(from entries: [MoodEntry],
                        streak: Int,
                        now: Date = Date(),
                        calendar cal: Calendar = .current) -> WeeklyStats {
        guard let weekAgo = cal.date(byAdding: .day, value: -7, to: now) else {
            return WeeklyStats(averageMood: 0, totalEntries: 0, topMood: 2, topTags: [], streak: streak)
        }
        let recent = entries.filter { $0.date >= weekAgo }

        let avgMood = recent.isEmpty ? 0.0 :
            Double(recent.map { $0.moodIndex }.reduce(0, +)) / Double(recent.count)

        let moodCounts = recent.reduce(into: [Int: Int]()) { c, e in
            c[e.moodIndex, default: 0] += 1
        }
        let topMood = moodCounts.max(by: { $0.value < $1.value })?.key ?? 2

        let tagCounts = recent.flatMap { $0.tags }.reduce(into: [String: Int]()) { c, t in
            c[t, default: 0] += 1
        }
        let topTags = Array(tagCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key })

        return WeeklyStats(
            averageMood: avgMood,
            totalEntries: recent.count,
            topMood: topMood,
            topTags: topTags,
            streak: streak
        )
    }
}

// MARK: - Streaks
enum Streaks {
    /// Number of consecutive days (ending today or yesterday) that contain
    /// at least one of `dates`. A day without a check-in yet (today) does
    /// not break the run until it ends.
    static func consecutiveDays(containing dates: [Date],
                                today: Date = Date(),
                                calendar cal: Calendar = .current) -> Int {
        let days = Set(dates.map { cal.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        var day = cal.startOfDay(for: today)
        if !days.contains(day) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}

// MARK: - Badge rules
/// Snapshot of everything badge unlocks depend on.
struct BadgeProgress {
    var checkInCount      = 0
    var streak            = 0
    var journalCount      = 0
    var gratitudeCount    = 0
    var completedPrograms = 0
    var sosUsed           = false
    var distinctMoodCount = 0
}

enum BadgeRules {
    static func shouldUnlock(_ badgeId: String, progress p: BadgeProgress) -> Bool {
        switch badgeId {
        case "first_checkin":     return p.checkInCount >= 1
        case "week_streak":       return p.streak >= 7
        case "month_streak":      return p.streak >= 30
        case "journal_5":         return p.journalCount >= 5
        case "journal_20":        return p.journalCount >= 20
        case "gratitude_7":       return p.gratitudeCount >= 7
        case "programs_complete": return p.completedPrograms >= 1
        case "sos_used":          return p.sosUsed
        case "mood_dna":          return p.checkInCount >= 7
        case "all_moods":         return p.distinctMoodCount >= 5
        default:                  return false
        }
    }
}

// MARK: - BreathingExerciseModel
struct BreathPhase {
    let name: String
    let duration: Int
}

struct BreathingExerciseModel: Identifiable {
    var id: String
    var name: String
    var exerciseDescription: String
    var icon: String
    var phases: [BreathPhase]

    static let allExercises: [BreathingExerciseModel] = [
        BreathingExerciseModel(
            id: "box",
            name: L("breathing.box"),
            exerciseDescription: L("breathing.box.desc"),
            icon: "square",
            phases: [
                BreathPhase(name: L("breathing.inhale"),  duration: 4),
                BreathPhase(name: L("breathing.hold"),    duration: 4),
                BreathPhase(name: L("breathing.exhale"),  duration: 4),
                BreathPhase(name: L("breathing.holdOut"), duration: 4)
            ]
        ),
        BreathingExerciseModel(
            id: "478",
            name: "4-7-8",
            exerciseDescription: L("breathing.478.desc"),
            icon: "lungs.fill",
            phases: [
                BreathPhase(name: L("breathing.inhale"), duration: 4),
                BreathPhase(name: L("breathing.hold"),   duration: 7),
                BreathPhase(name: L("breathing.exhale"), duration: 8)
            ]
        ),
        BreathingExerciseModel(
            id: "calm",
            name: L("breathing.calm"),
            exerciseDescription: L("breathing.calm.desc"),
            icon: "wind",
            phases: [
                BreathPhase(name: L("breathing.inhale"), duration: 4),
                BreathPhase(name: L("breathing.exhale"), duration: 6)
            ]
        )
    ]
}

// MARK: - Localized accessors
extension WellnessProgram {
    var localizedName: String {
        switch id {
        case "calm_7":   return L("program.calm7.name")
        case "energy_7": return L("program.energy7.name")
        case "stress_7": return L("program.stress7.name")
        default:         return name
        }
    }
    var localizedDescription: String {
        switch id {
        case "calm_7":   return L("program.calm7.desc")
        case "energy_7": return L("program.energy7.desc")
        case "stress_7": return L("program.stress7.desc")
        default:         return description
        }
    }
}

extension Badge {
    var localizedTitle: String {
        let key = "badge.\(id).title"
        let result = L(key)
        return result == key ? title : result
    }
}

extension ProgramTask {
    var localizedTitle: String {
        let key = "program.task.\(id).title"
        let result = L(key)
        return result == key ? title : result
    }
    var localizedDescription: String {
        let key = "program.task.\(id).desc"
        let result = L(key)
        return result == key ? taskDescription : result
    }
}

// MARK: - Default Data
extension WellnessProgram {
    static var defaultPrograms: [WellnessProgram] {
        [
            WellnessProgram(
                id: "calm_7",
                name: "7 Days of Calm",
                description: "Reduce anxiety and find inner peace through daily mindfulness.",
                duration: 7,
                category: .calm,
                tasks: [
                    ProgramTask(id: "c1", day: 1, title: "Morning Breathing", taskDescription: "Practice box breathing for 5 minutes after waking up.", exerciseId: "box"),
                    ProgramTask(id: "c2", day: 2, title: "Body Scan", taskDescription: "Do a 10-minute body scan meditation before sleep."),
                    ProgramTask(id: "c3", day: 3, title: "Mindful Walk", taskDescription: "Take a 15-minute walk without your phone, observing nature.", exerciseId: "calm"),
                    ProgramTask(id: "c4", day: 4, title: "Gratitude List", taskDescription: "Write 3 things you are grateful for today."),
                    ProgramTask(id: "c5", day: 5, title: "Digital Detox", taskDescription: "Spend 1 hour completely offline. Read or journal instead."),
                    ProgramTask(id: "c6", day: 6, title: "4-7-8 Breathing", taskDescription: "Practice 4-7-8 breathing before any stressful activity.", exerciseId: "478"),
                    ProgramTask(id: "c7", day: 7, title: "Reflect & Plan", taskDescription: "Write a reflection on how you felt this week and what helped most.")
                ]
            ),
            WellnessProgram(
                id: "energy_7",
                name: "Energy Boost",
                description: "Recharge your vitality and motivation with daily practices.",
                duration: 7,
                category: .energy,
                tasks: [
                    ProgramTask(id: "e1", day: 1, title: "Morning Stretch", taskDescription: "Do 5 minutes of energizing stretches after waking up."),
                    ProgramTask(id: "e2", day: 2, title: "Power Breathing", taskDescription: "Try energizing breath-of-fire breathing for 2 minutes.", exerciseId: "box"),
                    ProgramTask(id: "e3", day: 3, title: "Cold Water", taskDescription: "End your shower with 30 seconds of cold water."),
                    ProgramTask(id: "e4", day: 4, title: "Move Your Body", taskDescription: "Do any 20-minute physical activity you enjoy."),
                    ProgramTask(id: "e5", day: 5, title: "Power Pose", taskDescription: "Stand in a confident power pose for 2 minutes before a challenge."),
                    ProgramTask(id: "e6", day: 6, title: "Hydration Check", taskDescription: "Drink 8 glasses of water today and notice how you feel."),
                    ProgramTask(id: "e7", day: 7, title: "Celebration", taskDescription: "Do something that brings you genuine joy today.")
                ]
            ),
            WellnessProgram(
                id: "stress_7",
                name: "Stress Relief",
                description: "Practical tools to manage and release daily stress.",
                duration: 7,
                category: .stress,
                tasks: [
                    ProgramTask(id: "s1", day: 1, title: "Stress Audit", taskDescription: "Write down your top 3 stressors and one small action for each."),
                    ProgramTask(id: "s2", day: 2, title: "Progressive Relaxation", taskDescription: "Practice progressive muscle relaxation for 10 minutes."),
                    ProgramTask(id: "s3", day: 3, title: "Say No Practice", taskDescription: "Politely decline one non-essential request today.", exerciseId: "calm"),
                    ProgramTask(id: "s4", day: 4, title: "Nature Time", taskDescription: "Spend 20 minutes in a park or natural setting."),
                    ProgramTask(id: "s5", day: 5, title: "Worry Box", taskDescription: "Write your worries on paper, fold them, and set them aside until evening."),
                    ProgramTask(id: "s6", day: 6, title: "Breathing Reset", taskDescription: "Use 4-7-8 breathing whenever stress arises today.", exerciseId: "478"),
                    ProgramTask(id: "s7", day: 7, title: "Future Letter", taskDescription: "Write a letter to yourself 1 year from now about how you managed stress.")
                ]
            )
        ]
    }
}

extension Badge {
    static var defaultBadges: [Badge] {
        [
            Badge(id: "first_checkin",    title: "First Step",       badgeDescription: "Completed your first mood check-in",    icon: "star.fill"),
            Badge(id: "week_streak",      title: "Week Warrior",     badgeDescription: "7-day check-in streak",                  icon: "flame.fill"),
            Badge(id: "month_streak",     title: "Iron Discipline",  badgeDescription: "30-day check-in streak",                 icon: "crown.fill"),
            Badge(id: "journal_5",        title: "Wordsmith",        badgeDescription: "Wrote 5 journal entries",                icon: "pencil.circle.fill"),
            Badge(id: "journal_20",       title: "Storyteller",      badgeDescription: "Wrote 20 journal entries",               icon: "book.fill"),
            Badge(id: "gratitude_7",      title: "Grateful Heart",   badgeDescription: "7 gratitude entries",                    icon: "heart.fill"),
            Badge(id: "programs_complete",title: "Goal Crusher",     badgeDescription: "Completed a 7-day program",              icon: "checkmark.seal.fill"),
            Badge(id: "sos_used",         title: "Brave Soul",       badgeDescription: "Used SOS mode when needed",              icon: "shield.fill"),
            Badge(id: "mood_dna",         title: "Self-Aware",       badgeDescription: "Unlocked Mood DNA insights",             icon: "chart.bar.fill"),
            Badge(id: "all_moods",        title: "Emotional Range",  badgeDescription: "Logged all 5 mood types",                icon: "face.smiling.fill")
        ]
    }
}

// MARK: - Mood tags
let allMoodTags = [
    "work", "family", "health", "sleep", "exercise",
    "food", "social", "weather", "creativity", "travel",
    "money", "love", "stress", "joy", "tired"
]

// MARK: - Fallback AI insights
let fallbackInsights: [AIInsight] = {
    let emojis = ["🌟", "💙", "🌿", "✨", "🌊", "🔑", "🌱"]
    let tones  = ["encouraging", "compassionate", "practical", "positive", "calm", "reflective", "growth"]
    return (0 ..< 7).map { i in
        AIInsight(
            emoji: emojis[i],
            title: L("fallback.\(i + 1).title"),
            body:  L("fallback.\(i + 1).body"),
            tip:   L("fallback.\(i + 1).tip"),
            tone:  tones[i]
        )
    }
}()
