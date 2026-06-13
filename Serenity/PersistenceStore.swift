import Foundation

// MARK: - Storage keys
/// Single source of truth for persistence keys (UserDefaults, Keychain and data files).
enum StorageKey {
    // Collections — stored as JSON files via PersistenceStore
    static let moodEntries      = "moodEntries"
    static let journalEntries   = "journalEntries"
    static let gratitudeEntries = "gratitudeEntries"
    static let programs         = "programs"
    static let badges           = "badges"
    static let chatMessages     = "chatMessages"
    static let thoughtRecords   = "thoughtRecords"
    static let copingPlan       = "copingPlan"
    static let habits           = "habits"
    static let affirmationText  = "personalAffirmationText"
    static let affirmationDate  = "personalAffirmationDate"

    // Scalar settings — UserDefaults
    static let isOnboardingComplete   = "isOnboardingComplete"
    static let userName               = "userName"
    static let selectedTheme          = "selectedTheme"
    static let userGoals              = "userGoals"
    static let customTags             = "customTags"
    static let faceLockEnabled        = "faceLockEnabled"
    static let llmEndpoint            = "llmEndpoint"
    static let llmLegacyProvider      = "llmProvider"
    static let llmModel               = "llmModel"
    static let lunchReminderEnabled   = "lunchReminderEnabled"
    static let lunchReminderHour      = "lunchReminderHour"
    static let lunchReminderMinute    = "lunchReminderMinute"
    static let eveningReminderEnabled = "eveningReminderEnabled"
    static let eveningReminderHour    = "eveningReminderHour"
    static let eveningReminderMinute  = "eveningReminderMinute"
    static let affirmationsEnabled    = "affirmationsEnabled"
    static let affirmationHour        = "affirmationHour"
    static let affirmationMinute      = "affirmationMinute"
    static let sosUsed                = "sosUsed"
    static let hasSeenChatDisclaimer  = "hasSeenChatDisclaimer"
    static let healthEnabled          = "healthEnabled"

    // Keychain
    static let claudeAPIKey = "claudeAPIKey"
}

// MARK: - PersistenceStore
/// Stores user data collections as individual JSON files in Application Support,
/// so each collection is written independently and UserDefaults holds only
/// small scalar preferences.
struct PersistenceStore {
    private let directory: URL
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, directoryName: String = "SerenityData") {
        self.defaults = defaults
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        if let data = try? Data(contentsOf: fileURL(key)),
           let value = try? JSONDecoder().decode(T.self, from: data) {
            return value
        }
        return migrateFromDefaults(type, key: key)
    }

    func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        // Mental-health data stays encrypted whenever the device is locked.
        try? data.write(to: fileURL(key), options: [.atomic, .completeFileProtection])
    }

    private func fileURL(_ key: String) -> URL {
        directory.appendingPathComponent("\(key).json")
    }

    /// One-time migration of data previously stored as a blob in UserDefaults.
    private func migrateFromDefaults<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard let legacy = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: legacy) else { return nil }
        save(value, key: key)
        defaults.removeObject(forKey: key)
        return value
    }
}
