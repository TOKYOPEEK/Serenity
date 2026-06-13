import Foundation

/// Turns the user's accumulated data into a single proactive observation —
/// the kind a thoughtful companion would notice. Pure and rules-based so it
/// works offline and can be scheduled into a local notification (no server,
/// no LLM at fire-time). Returns nil until there's enough history.
enum ProactiveInsight {
    static func current(
        moods: [MoodEntry],
        streak: Int,
        health: HealthSnapshot?,
        now: Date = Date(),
        calendar cal: Calendar = .current
    ) -> String? {
        guard moods.count >= 3 else { return nil }

        // Been away a couple of days → a gentle re-engagement nudge.
        if let last = moods.map(\.date).max() {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: last),
                                          to: cal.startOfDay(for: now)).day ?? 0
            if days >= 2 { return L("insight.return") }
        }

        // Celebrate a streak milestone.
        if [3, 7, 14, 30, 50, 100, 200, 365].contains(streak) {
            return String(format: L("insight.streak"), streak)
        }

        // Body ↔ mood signals from Apple Health.
        if health?.shortSleepLowersMood == true { return L("insight.sleep") }
        if health?.moreStepsLiftsMood == true { return L("insight.steps") }

        // Activity correlations.
        let influences = Correlations.activityInfluences(from: moods)
        if let weigh = influences.weighs.first {
            return String(format: L("insight.weighs"), L("tag.\(weigh.tag)"))
        }
        if let lift = influences.lifts.first {
            return String(format: L("insight.lifts"), L("tag.\(lift.tag)"))
        }

        return L("insight.generic")
    }
}
