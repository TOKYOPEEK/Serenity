import Foundation

/// The mood of the Serenity companion ("Лу") — a small otter spirit that
/// mirrors how the user has been caring for themselves.
enum CompanionState: String {
    case blooming   // long streak, doing great
    case calm       // ordinary day
    case sleepy     // neglected for a few days
    case anxious    // a string of low-mood days

    /// Pure derivation so it can be unit-tested without the view model.
    static func derive(daysSinceLastCheckIn: Int?, recentAvgMood: Double?, streak: Int) -> CompanionState {
        // Neglect takes priority — the otter dozes off when you stop visiting.
        if let days = daysSinceLastCheckIn, days >= 3 { return .sleepy }
        // Then a genuinely rough stretch (needs enough signal, checked by caller).
        if let avg = recentAvgMood, avg <= 1.0 { return .anxious }
        // Reward consistency.
        if streak >= 7 { return .blooming }
        return .calm
    }
}

/// Picks a short, in-character line for the companion, lightly personalised
/// with the user's name and streak. Lines live in Localizable.strings.
enum CompanionDialogue {
    static func line(for state: CompanionState, name: String, streak: Int) -> String {
        let n = name.trimmingCharacters(in: .whitespaces)
        switch state {
        case .blooming:
            let key = ["companion.blooming.1", "companion.blooming.2", "companion.blooming.3"].randomElement()!
            return personalize(L(key), name: n, streak: streak)
        case .calm:
            let key = ["companion.calm.1", "companion.calm.2", "companion.calm.3"].randomElement()!
            return personalize(L(key), name: n, streak: streak)
        case .sleepy:
            let key = ["companion.sleepy.1", "companion.sleepy.2"].randomElement()!
            return personalize(L(key), name: n, streak: streak)
        case .anxious:
            let key = ["companion.anxious.1", "companion.anxious.2"].randomElement()!
            return personalize(L(key), name: n, streak: streak)
        }
    }

    private static func personalize(_ template: String, name: String, streak: Int) -> String {
        template
            .replacingOccurrences(of: "%name%", with: name.isEmpty ? L("companion.friend") : name)
            .replacingOccurrences(of: "%streak%", with: "\(streak)")
    }
}
