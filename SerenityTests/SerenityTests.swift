import XCTest
@testable import Serenity

// MARK: - Streaks

final class StreakTests: XCTestCase {
    private let cal = Calendar.current

    /// Start of the day `offset` days from today (0 = today, -1 = yesterday).
    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: Date()))!
    }

    func testEmptyDatesGiveZero() {
        XCTAssertEqual(Streaks.consecutiveDays(containing: []), 0)
    }

    func testRunEndingTodayIsCounted() {
        XCTAssertEqual(Streaks.consecutiveDays(containing: [day(0), day(-1), day(-2)]), 3)
    }

    func testMissingTodayDoesNotBreakRun() {
        // No check-in yet today — the streak survives until the day ends.
        XCTAssertEqual(Streaks.consecutiveDays(containing: [day(-1), day(-2)]), 2)
    }

    func testGapResetsRun() {
        XCTAssertEqual(Streaks.consecutiveDays(containing: [day(0), day(-2), day(-3)]), 1)
    }

    func testStaleHistoryGivesZero() {
        XCTAssertEqual(Streaks.consecutiveDays(containing: [day(-5), day(-6)]), 0)
    }

    func testSeveralCheckInsSameDayCountOnce() {
        let noon = cal.date(byAdding: .hour, value: 12, to: day(0))!
        XCTAssertEqual(Streaks.consecutiveDays(containing: [day(0), noon, day(-1)]), 2)
    }
}

// MARK: - WeeklyStats

final class WeeklyStatsTests: XCTestCase {
    private let cal = Calendar.current

    private func entry(daysAgo: Int, mood: Int, tags: [String] = []) -> MoodEntry {
        MoodEntry(
            date: cal.date(byAdding: .day, value: -daysAgo, to: Date())!,
            moodIndex: mood,
            energyLevel: 0.5,
            stressLevel: 0.5,
            tags: tags,
            note: ""
        )
    }

    func testEmptyEntriesProduceNeutralDefaults() {
        let stats = WeeklyStats.compute(from: [], streak: 0)
        XCTAssertEqual(stats.averageMood, 0)
        XCTAssertEqual(stats.totalEntries, 0)
        XCTAssertEqual(stats.topMood, 2)
        XCTAssertTrue(stats.topTags.isEmpty)
    }

    func testAverageAndCount() {
        let stats = WeeklyStats.compute(
            from: [entry(daysAgo: 0, mood: 4), entry(daysAgo: 1, mood: 2)],
            streak: 2
        )
        XCTAssertEqual(stats.averageMood, 3.0, accuracy: 0.001)
        XCTAssertEqual(stats.totalEntries, 2)
        XCTAssertEqual(stats.streak, 2)
    }

    func testTopMoodIsTheMostFrequent() {
        let stats = WeeklyStats.compute(
            from: [entry(daysAgo: 0, mood: 1),
                   entry(daysAgo: 1, mood: 3),
                   entry(daysAgo: 2, mood: 3)],
            streak: 0
        )
        XCTAssertEqual(stats.topMood, 3)
    }

    func testTopTagsAreLimitedToThreeAndSortedByFrequency() {
        let stats = WeeklyStats.compute(
            from: [entry(daysAgo: 0, mood: 2, tags: ["a", "b", "c", "d"]),
                   entry(daysAgo: 1, mood: 2, tags: ["a", "b", "c"]),
                   entry(daysAgo: 2, mood: 2, tags: ["a", "b"]),
                   entry(daysAgo: 3, mood: 2, tags: ["a"])],
            streak: 0
        )
        XCTAssertEqual(stats.topTags.count, 3)
        XCTAssertEqual(stats.topTags.first, "a")
        XCTAssertFalse(stats.topTags.contains("d"))
    }

    func testEntriesOlderThanAWeekAreExcluded() {
        let stats = WeeklyStats.compute(
            from: [entry(daysAgo: 0, mood: 4), entry(daysAgo: 10, mood: 0)],
            streak: 0
        )
        XCTAssertEqual(stats.totalEntries, 1)
        XCTAssertEqual(stats.averageMood, 4.0, accuracy: 0.001)
    }
}

// MARK: - Badge rules

final class BadgeRulesTests: XCTestCase {
    func testFirstCheckInUnlocksAtOne() {
        XCTAssertFalse(BadgeRules.shouldUnlock("first_checkin", progress: BadgeProgress()))
        XCTAssertTrue(BadgeRules.shouldUnlock("first_checkin", progress: BadgeProgress(checkInCount: 1)))
    }

    func testWeekStreakThreshold() {
        XCTAssertFalse(BadgeRules.shouldUnlock("week_streak", progress: BadgeProgress(streak: 6)))
        XCTAssertTrue(BadgeRules.shouldUnlock("week_streak", progress: BadgeProgress(streak: 7)))
    }

    func testMonthStreakThreshold() {
        XCTAssertFalse(BadgeRules.shouldUnlock("month_streak", progress: BadgeProgress(streak: 29)))
        XCTAssertTrue(BadgeRules.shouldUnlock("month_streak", progress: BadgeProgress(streak: 30)))
    }

    func testJournalThresholds() {
        XCTAssertTrue(BadgeRules.shouldUnlock("journal_5", progress: BadgeProgress(journalCount: 5)))
        XCTAssertFalse(BadgeRules.shouldUnlock("journal_20", progress: BadgeProgress(journalCount: 19)))
    }

    func testAllMoodsNeedsAllFive() {
        XCTAssertFalse(BadgeRules.shouldUnlock("all_moods", progress: BadgeProgress(distinctMoodCount: 4)))
        XCTAssertTrue(BadgeRules.shouldUnlock("all_moods", progress: BadgeProgress(distinctMoodCount: 5)))
    }

    func testUnknownBadgeNeverUnlocks() {
        XCTAssertFalse(BadgeRules.shouldUnlock("nonexistent", progress: BadgeProgress(checkInCount: 999, streak: 999)))
    }
}

// MARK: - UserContext (AI memory)

final class UserContextTests: XCTestCase {
    private let cal = Calendar.current

    private func mood(daysAgo: Int, _ index: Int, tags: [String] = []) -> MoodEntry {
        MoodEntry(
            date: cal.date(byAdding: .day, value: -daysAgo, to: Date())!,
            moodIndex: index, energyLevel: 0.5, stressLevel: 0.5, tags: tags, note: ""
        )
    }

    func testNilWhenTooFewCheckIns() {
        let summary = UserContext.summary(
            name: "Amir", moods: [mood(daysAgo: 0, 3), mood(daysAgo: 1, 2)],
            journals: [], gratitude: [], streak: 2
        )
        XCTAssertNil(summary, "fewer than 3 check-ins should produce no memory")
    }

    func testIncludesNameStreakAndThemes() {
        let moods = [
            mood(daysAgo: 0, 3, tags: ["work", "sleep"]),
            mood(daysAgo: 1, 2, tags: ["work"]),
            mood(daysAgo: 2, 4, tags: ["work"])
        ]
        let summary = UserContext.summary(
            name: "Amir", moods: moods, journals: [], gratitude: [], streak: 3
        )
        let text = try? XCTUnwrap(summary)
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("Amir"))
        XCTAssertTrue(text!.contains("streak: 3"))
        XCTAssertTrue(text!.contains("work"), "the dominant theme should surface")
    }

    func testIncludesLatestJournalSnippet() {
        let moods = (0..<3).map { mood(daysAgo: $0, 3) }
        let journals = [
            JournalEntry(date: cal.date(byAdding: .day, value: -1, to: Date())!,
                         title: "t", content: "I felt overwhelmed at work today", mood: 1)
        ]
        let summary = UserContext.summary(
            name: "", moods: moods, journals: journals, gratitude: [], streak: 1
        )
        XCTAssertTrue(summary?.contains("overwhelmed at work") ?? false)
    }

    func testPreambleIsEmptyForNilSummary() {
        XCTAssertEqual(UserContext.systemPreamble(nil), "")
        XCTAssertFalse(UserContext.systemPreamble("Name: Amir").isEmpty)
    }
}

// MARK: - ChatMessage backward compatibility

final class ChatMessageCompatibilityTests: XCTestCase {
    func testLegacyStringRoleStillDecodes() throws {
        // Chats saved before Role became an enum stored the role as a plain string.
        let legacyJSON = """
        {"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","role":"assistant","content":"hi","timestamp":0}
        """
        let message = try JSONDecoder().decode(ChatMessage.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "hi")
    }

    func testRoundTripKeepsRole() throws {
        let original = ChatMessage(role: .user, content: "привет")
        let data     = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(ChatMessage.self, from: data)
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.content, "привет")
    }
}

// MARK: - UserDefaults default-aware accessor

final class UserDefaultsDefaultTests: XCTestCase {
    private let suite = "UserDefaultsDefaultTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testMissingKeyFallsBackToDefault() {
        XCTAssertEqual(defaults.integer(forKey: "hour", default: 13), 13)
    }

    func testStoredZeroIsNotTreatedAsMissing() {
        // Midnight (hour 0) must survive a relaunch — the original bug.
        defaults.set(0, forKey: "hour")
        XCTAssertEqual(defaults.integer(forKey: "hour", default: 13), 0)
    }

    func testStoredValueWins() {
        defaults.set(21, forKey: "hour")
        XCTAssertEqual(defaults.integer(forKey: "hour", default: 13), 21)
    }
}

// MARK: - PersistenceStore

final class PersistenceStoreTests: XCTestCase {
    private let suite   = "PersistenceStoreTests"
    private let dirName = "SerenityDataTests"
    private var defaults: UserDefaults!
    private var store: PersistenceStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = PersistenceStore(defaults: defaults, directoryName: dirName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: base.appendingPathComponent(dirName))
        super.tearDown()
    }

    func testRoundTrip() {
        store.save([1, 2, 3], key: "numbers")
        XCTAssertEqual(store.load([Int].self, key: "numbers"), [1, 2, 3])
    }

    func testMissingKeyReturnsNil() {
        XCTAssertNil(store.load([Int].self, key: "missing"))
    }

    func testOverwriteReplacesValue() {
        store.save(["old"], key: "tags")
        store.save(["new"], key: "tags")
        XCTAssertEqual(store.load([String].self, key: "tags"), ["new"])
    }

    func testMigratesLegacyUserDefaultsBlob() throws {
        // Data saved by old versions lived as a JSON blob inside UserDefaults.
        let legacy = try JSONEncoder().encode(["a", "b"])
        defaults.set(legacy, forKey: "tags")

        XCTAssertEqual(store.load([String].self, key: "tags"), ["a", "b"])
        XCTAssertNil(defaults.data(forKey: "tags"), "legacy blob should be removed after migration")
        XCTAssertEqual(store.load([String].self, key: "tags"), ["a", "b"], "migrated data must persist as a file")
    }
}
