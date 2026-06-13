import Foundation

/// Builds a compact, privacy-light snapshot of the user's recent history that
/// is injected into every AI prompt. This is what makes the assistant feel
/// like it *remembers* the person instead of starting cold each time.
///
/// The summary is intentionally terse (counts, averages, recurring themes,
/// notable patterns) rather than raw entries — it keeps token cost low and
/// avoids shipping full journal text to the provider.
enum UserContext {

    /// Produces the context block, or `nil` when there is too little data to
    /// say anything meaningful (fewer than 3 check-ins).
    static func summary(
        name: String,
        moods: [MoodEntry],
        journals: [JournalEntry],
        gratitude: [GratitudeEntry],
        streak: Int,
        health: HealthSnapshot? = nil,
        now: Date = Date(),
        calendar cal: Calendar = .current
    ) -> String? {
        guard moods.count >= 3 else { return nil }

        var lines: [String] = []

        if !name.isEmpty {
            lines.append("Name: \(name)")
        }

        // Recent window: last 14 days of check-ins.
        let window = cal.date(byAdding: .day, value: -14, to: now) ?? now
        let recent = moods.filter { $0.date >= window }
        if !recent.isEmpty {
            let avg = Double(recent.map { $0.moodIndex }.reduce(0, +)) / Double(recent.count)
            lines.append("Last 14 days: \(recent.count) check-ins, average mood \(moodWord(Int(avg.rounded()))).")
        }

        if streak > 0 {
            lines.append("Current check-in streak: \(streak) days.")
        }

        // Recurring themes (tags) over the recent window.
        let tagCounts = recent.flatMap { $0.tags }.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let topTags = tagCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        if !topTags.isEmpty {
            lines.append("Recurring themes: \(topTags.joined(separator: ", ")).")
        }

        // Hardest weekday — the seed for proactive "Thursdays are tough" insight.
        if let tough = hardestWeekday(in: moods, calendar: cal) {
            lines.append("Tends to feel lowest on \(tough).")
        }

        // Most-named feelings (emotion wheel) over the recent window.
        let emotionCounts = recent.flatMap { $0.emotionNames }.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let topEmotions = emotionCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        if !topEmotions.isEmpty {
            lines.append("Often names these feelings: \(topEmotions.joined(separator: ", ")).")
        }

        // Latest journal entry, trimmed — gives the AI something concrete and current.
        if let last = journals.max(by: { $0.date < $1.date }) {
            let snippet = last.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160)
            if !snippet.isEmpty {
                lines.append("Most recent journal note: \"\(snippet)\".")
            }
        }

        if let lastGratitude = gratitude.max(by: { $0.date < $1.date }) {
            let snippet = lastGratitude.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)
            if !snippet.isEmpty {
                lines.append("Recently grateful for: \"\(snippet)\".")
            }
        }

        // Apple Health context — lets the AI connect body and mood.
        if let h = health, h.hasAnything {
            var parts: [String] = []
            if let s = h.avgSleepHours { parts.append(String(format: "sleeps ~%.1fh/night", s)) }
            if let hr = h.restingHeartRate { parts.append("resting heart rate ~\(Int(hr)) bpm") }
            if let steps = h.avgSteps { parts.append("~\(steps) steps/day") }
            if !parts.isEmpty {
                lines.append("Health (last 2 weeks): \(parts.joined(separator: ", ")).")
            }
            if h.shortSleepLowersMood == true {
                lines.append("Mood tends to be lower after nights of shorter-than-usual sleep.")
            }
        }

        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }

    /// Wraps the summary into a system-prompt section the model can lean on.
    static func systemPreamble(_ summary: String?) -> String {
        guard let summary else { return "" }
        return """

        --- What you remember about this person (use it naturally, never recite it verbatim) ---
        \(summary)
        -------------------------------------------------------------------------------
        """
    }

    // MARK: - Helpers

    private static func moodWord(_ index: Int) -> String {
        ["rough", "low", "okay", "good", "great"][max(0, min(index, 4))]
    }

    /// Weekday with the lowest average mood, if one stands out across ≥7 entries.
    private static func hardestWeekday(in moods: [MoodEntry], calendar cal: Calendar) -> String? {
        guard moods.count >= 7 else { return nil }
        var sums = [Int: (total: Int, count: Int)]()
        for e in moods {
            let wd = cal.component(.weekday, from: e.date)
            let cur = sums[wd] ?? (0, 0)
            sums[wd] = (cur.total + e.moodIndex, cur.count + 1)
        }
        // Only weekdays with at least 2 samples, so one bad day isn't "a pattern".
        let averaged = sums.filter { $0.value.count >= 2 }
            .mapValues { Double($0.total) / Double($0.count) }
        guard let worst = averaged.min(by: { $0.value < $1.value }),
              let best  = averaged.max(by: { $0.value < $1.value }),
              best.value - worst.value >= 0.8 else { return nil }  // needs a real gap
        return englishWeekday(worst.key)
    }

    private static func englishWeekday(_ weekday: Int) -> String {
        // Calendar weekday: 1 = Sunday ... 7 = Saturday
        ["", "Sundays", "Mondays", "Tuesdays", "Wednesdays",
         "Thursdays", "Fridays", "Saturdays"][max(1, min(weekday, 7))]
    }
}
