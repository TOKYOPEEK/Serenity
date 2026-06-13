import Foundation

/// One activity tag and how mood on days with it compares to the overall mean.
struct ActivityInfluence: Identifiable {
    let tag: String          // localization key, e.g. "exercise"
    let delta: Double         // avg mood with this tag minus overall avg (mood scale 0–4)
    let count: Int            // how many entries had this tag
    var id: String { tag }
}

/// Pure correlation logic over mood entries — no view-model or HealthKit
/// dependency, so it's unit-testable.
enum Correlations {
    /// Activities that lift / weigh on mood, ranked by effect size. Needs a bit
    /// of history (≥5 entries) and a few samples per tag (≥`minCount`) so a
    /// single day can't masquerade as a pattern.
    static func activityInfluences(
        from moods: [MoodEntry],
        minCount: Int = 3,
        threshold: Double = 0.2
    ) -> (lifts: [ActivityInfluence], weighs: [ActivityInfluence]) {
        guard moods.count >= 5 else { return ([], []) }

        let overall = Double(moods.map { $0.moodIndex }.reduce(0, +)) / Double(moods.count)

        var byTag: [String: [Int]] = [:]
        for entry in moods {
            for tag in entry.tags { byTag[tag, default: []].append(entry.moodIndex) }
        }

        var influences: [ActivityInfluence] = []
        for (tag, values) in byTag where values.count >= minCount {
            let avg = Double(values.reduce(0, +)) / Double(values.count)
            influences.append(ActivityInfluence(tag: tag, delta: avg - overall, count: values.count))
        }

        let lifts  = influences.filter { $0.delta >=  threshold }.sorted { $0.delta > $1.delta }
        let weighs = influences.filter { $0.delta <= -threshold }.sorted { $0.delta < $1.delta }
        return (Array(lifts.prefix(3)), Array(weighs.prefix(3)))
    }

    /// Habits whose completed days carry better-than-average mood.
    static func habitInfluences(
        habits: [Habit],
        moods: [MoodEntry],
        minCount: Int = 3,
        threshold: Double = 0.2,
        calendar cal: Calendar = .current
    ) -> [(name: String, delta: Double)] {
        guard moods.count >= 5 else { return [] }
        let moodByDay = Dictionary(
            moods.map { (cal.startOfDay(for: $0.date), $0.moodIndex) },
            uniquingKeysWith: { a, _ in a })
        guard !moodByDay.isEmpty else { return [] }
        let overall = Double(moodByDay.values.reduce(0, +)) / Double(moodByDay.count)

        var result: [(String, Double)] = []
        for habit in habits {
            let doneDays = Set(habit.completions.map { cal.startOfDay(for: $0) })
            let moodsOnDone = moodByDay.filter { doneDays.contains($0.key) }.map { $0.value }
            guard moodsOnDone.count >= minCount else { continue }
            let avg = Double(moodsOnDone.reduce(0, +)) / Double(moodsOnDone.count)
            if avg - overall >= threshold { result.append((habit.name, avg - overall)) }
        }
        return result.sorted { $0.1 > $1.1 }
    }
}
