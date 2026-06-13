import Foundation
import SwiftUI
import UserNotifications
import Combine
import LocalAuthentication

// MARK: - UserDefaults helpers
extension UserDefaults {
    /// Unlike `integer(forKey:)`, distinguishes "not set" from a stored 0
    /// so values like midnight (hour 0) survive relaunch.
    func integer(forKey key: String, default defaultValue: Int) -> Int {
        object(forKey: key) == nil ? defaultValue : integer(forKey: key)
    }
}

// MARK: - AppViewModel
@MainActor
class AppViewModel: ObservableObject {
    @Published var isOnboardingComplete: Bool
    @Published var userName: String
    @Published var selectedTheme: AppColorTheme
    @Published var moodEntries: [MoodEntry]
    @Published var journalEntries: [JournalEntry]
    @Published var gratitudeEntries: [GratitudeEntry]
    @Published var programs: [WellnessProgram]
    @Published var badges: [Badge]
    @Published var claudeAPIKey: String
    @Published var showBadgeToast: Bool = false
    @Published var newBadge: Badge?
    @Published var userGoals: [String]
    @Published var selectedTab: Int = 0

    // Chat persistence
    @Published var chatMessages: [ChatMessage]

    // CBT tools
    @Published var thoughtRecords: [ThoughtRecord]
    @Published var copingPlan: [CopingItem]

    // Habits
    @Published var habits: [Habit]

    // Custom tags
    @Published var customTags: [String]

    // Reminder settings
    @Published var lunchReminderEnabled: Bool
    @Published var lunchReminderHour: Int
    @Published var lunchReminderMinute: Int
    @Published var eveningReminderEnabled: Bool
    @Published var eveningReminderHour: Int
    @Published var eveningReminderMinute: Int

    // Affirmations
    @Published var affirmationsEnabled: Bool
    @Published var affirmationHour: Int
    @Published var affirmationMinute: Int

    // Face ID
    @Published var faceLockEnabled: Bool
    @Published var isUnlocked: Bool = false

    // LLM
    @Published var llmEndpoint: String
    @Published var llmModel: String

    // Apple Health
    @Published var healthEnabled: Bool
    @Published var healthSnapshot: HealthSnapshot?

    private let defaults = UserDefaults.standard
    private let store: PersistenceStore
    private let notifications = NotificationScheduler()
    private let health = HealthStore()

    init() {
        let store = PersistenceStore()
        self.store = store

        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: StorageKey.isOnboardingComplete)
        self.userName             = UserDefaults.standard.string(forKey: StorageKey.userName) ?? ""
        self.claudeAPIKey         = KeychainHelper.load(forKey: StorageKey.claudeAPIKey) ?? ""
        self.faceLockEnabled      = UserDefaults.standard.bool(forKey: StorageKey.faceLockEnabled)
        self.isUnlocked           = !UserDefaults.standard.bool(forKey: StorageKey.faceLockEnabled)

        if let raw = UserDefaults.standard.string(forKey: StorageKey.selectedTheme),
           let t = AppColorTheme(rawValue: raw) {
            self.selectedTheme = t
        } else {
            self.selectedTheme = .cosmic
        }

        self.moodEntries      = store.load([MoodEntry].self,       key: StorageKey.moodEntries)      ?? []
        self.journalEntries   = store.load([JournalEntry].self,    key: StorageKey.journalEntries)   ?? []
        self.gratitudeEntries = store.load([GratitudeEntry].self,  key: StorageKey.gratitudeEntries) ?? []
        self.programs         = store.load([WellnessProgram].self, key: StorageKey.programs)         ?? WellnessProgram.defaultPrograms
        self.badges           = store.load([Badge].self,           key: StorageKey.badges)           ?? Badge.defaultBadges
        self.chatMessages     = store.load([ChatMessage].self,     key: StorageKey.chatMessages)     ?? []
        self.thoughtRecords   = store.load([ThoughtRecord].self,   key: StorageKey.thoughtRecords)   ?? []
        self.copingPlan       = store.load([CopingItem].self,      key: StorageKey.copingPlan)       ?? []
        self.habits           = store.load([Habit].self,           key: StorageKey.habits)           ?? []

        self.userGoals  = UserDefaults.standard.array(forKey: StorageKey.userGoals) as? [String] ?? []
        self.customTags = UserDefaults.standard.array(forKey: StorageKey.customTags) as? [String] ?? []

        self.lunchReminderEnabled  = UserDefaults.standard.bool(forKey: StorageKey.lunchReminderEnabled)
        self.lunchReminderHour     = UserDefaults.standard.integer(forKey: StorageKey.lunchReminderHour, default: 13)
        self.lunchReminderMinute   = UserDefaults.standard.integer(forKey: StorageKey.lunchReminderMinute)
        self.eveningReminderEnabled = UserDefaults.standard.object(forKey: StorageKey.eveningReminderEnabled) == nil
            ? true : UserDefaults.standard.bool(forKey: StorageKey.eveningReminderEnabled)
        self.eveningReminderHour   = UserDefaults.standard.integer(forKey: StorageKey.eveningReminderHour, default: 20)
        self.eveningReminderMinute = UserDefaults.standard.integer(forKey: StorageKey.eveningReminderMinute)
        self.affirmationsEnabled   = UserDefaults.standard.bool(forKey: StorageKey.affirmationsEnabled)
        self.affirmationHour       = UserDefaults.standard.integer(forKey: StorageKey.affirmationHour, default: 9)
        self.affirmationMinute     = UserDefaults.standard.integer(forKey: StorageKey.affirmationMinute)

        // Migrate from old enum-based storage if needed
        if let saved = UserDefaults.standard.string(forKey: StorageKey.llmEndpoint), !saved.isEmpty {
            self.llmEndpoint = saved
        } else if let old = UserDefaults.standard.string(forKey: StorageKey.llmLegacyProvider) {
            self.llmEndpoint = old == "openai"
                ? "https://api.openai.com/v1/chat/completions"
                : "https://api.anthropic.com/v1/messages"
        } else if !Secrets.defaultEndpoint.isEmpty {
            self.llmEndpoint = Secrets.defaultEndpoint
        } else {
            self.llmEndpoint = "https://api.anthropic.com/v1/messages"
        }
        self.llmModel = UserDefaults.standard.string(forKey: StorageKey.llmModel) ?? ""

        self.healthEnabled = UserDefaults.standard.bool(forKey: StorageKey.healthEnabled)
        if let data = UserDefaults.standard.data(forKey: StorageKey.healthSnapshot) {
            self.healthSnapshot = try? JSONDecoder().decode(HealthSnapshot.self, from: data)
        }
        if healthEnabled { Task { await refreshHealth() } }
    }

    /// Persists scalar settings only. Collections are written individually
    /// by their mutating methods (see MARK: Persistence).
    func save() {
        defaults.set(isOnboardingComplete, forKey: StorageKey.isOnboardingComplete)
        defaults.set(userName,             forKey: StorageKey.userName)
        KeychainHelper.save(claudeAPIKey,  forKey: StorageKey.claudeAPIKey)
        defaults.set(selectedTheme.rawValue, forKey: StorageKey.selectedTheme)
        defaults.set(userGoals,            forKey: StorageKey.userGoals)
        defaults.set(customTags,           forKey: StorageKey.customTags)
        defaults.set(faceLockEnabled,      forKey: StorageKey.faceLockEnabled)
        defaults.set(llmEndpoint, forKey: StorageKey.llmEndpoint)
        defaults.set(llmModel,    forKey: StorageKey.llmModel)
        defaults.set(healthEnabled, forKey: StorageKey.healthEnabled)

        defaults.set(lunchReminderEnabled,  forKey: StorageKey.lunchReminderEnabled)
        defaults.set(lunchReminderHour,     forKey: StorageKey.lunchReminderHour)
        defaults.set(lunchReminderMinute,   forKey: StorageKey.lunchReminderMinute)
        defaults.set(eveningReminderEnabled, forKey: StorageKey.eveningReminderEnabled)
        defaults.set(eveningReminderHour,   forKey: StorageKey.eveningReminderHour)
        defaults.set(eveningReminderMinute, forKey: StorageKey.eveningReminderMinute)
        defaults.set(affirmationsEnabled,   forKey: StorageKey.affirmationsEnabled)
        defaults.set(affirmationHour,       forKey: StorageKey.affirmationHour)
        defaults.set(affirmationMinute,     forKey: StorageKey.affirmationMinute)
    }

    // MARK: - Persistence (per-collection)
    private func saveMoodEntries()      { store.save(moodEntries,      key: StorageKey.moodEntries) }
    private func saveJournalEntries()   { store.save(journalEntries,   key: StorageKey.journalEntries) }
    private func saveGratitudeEntries() { store.save(gratitudeEntries, key: StorageKey.gratitudeEntries) }
    private func savePrograms()         { store.save(programs,         key: StorageKey.programs) }
    private func saveBadges()           { store.save(badges,           key: StorageKey.badges) }
    private func saveChat()             { store.save(chatMessages,     key: StorageKey.chatMessages) }
    private func saveThoughtRecords()   { store.save(thoughtRecords,   key: StorageKey.thoughtRecords) }
    func saveCopingPlan()               { store.save(copingPlan,       key: StorageKey.copingPlan) }

    func addThoughtRecord(_ record: ThoughtRecord) {
        thoughtRecords.insert(record, at: 0)
        saveThoughtRecords()
    }
    func deleteThoughtRecord(_ record: ThoughtRecord) {
        thoughtRecords.removeAll { $0.id == record.id }
        saveThoughtRecords()
    }

    private func saveHabits() { store.save(habits, key: StorageKey.habits) }
    func addHabit(name: String, icon: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        habits.append(Habit(name: trimmed, icon: icon))
        saveHabits()
    }
    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        saveHabits()
    }
    func toggleHabitToday(_ habit: Habit) {
        guard let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        if let j = habits[i].completions.firstIndex(where: { cal.isDate($0, inSameDayAs: today) }) {
            habits[i].completions.remove(at: j)
        } else {
            habits[i].completions.append(today)
            HapticManager.notification(.success)
        }
        saveHabits()
    }

    func addMoodEntry(_ entry: MoodEntry) {
        moodEntries.insert(entry, at: 0)
        checkBadges()
        saveMoodEntries()
    }

    func deleteMoodEntry(_ entry: MoodEntry) {
        moodEntries.removeAll { $0.id == entry.id }
        saveMoodEntries()
    }

    func addJournalEntry(_ entry: JournalEntry) {
        journalEntries.insert(entry, at: 0)
        checkBadges()
        saveJournalEntries()
    }

    func deleteJournalEntry(_ entry: JournalEntry) {
        journalEntries.removeAll { $0.id == entry.id }
        saveJournalEntries()
    }

    func updateJournalEntry(_ entry: JournalEntry) {
        if let idx = journalEntries.firstIndex(where: { $0.id == entry.id }) {
            journalEntries[idx] = entry
            saveJournalEntries()
        }
    }

    func addGratitudeEntry(_ entry: GratitudeEntry) {
        gratitudeEntries.insert(entry, at: 0)
        checkBadges()
        saveGratitudeEntries()
    }

    func addCustomTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !customTags.contains(trimmed), !allMoodTags.contains(trimmed) else { return }
        customTags.append(trimmed)
        save()
    }

    func removeCustomTag(_ tag: String) {
        customTags.removeAll { $0 == tag }
        save()
    }

    // MARK: - Programs
    func startProgram(_ programId: String) {
        guard let idx = programs.firstIndex(where: { $0.id == programId }) else { return }
        programs[idx].isActive  = true
        programs[idx].startDate = Date()
        savePrograms()
    }

    func completeProgramTask(programId: String, taskId: String) {
        guard let pIdx = programs.firstIndex(where: { $0.id == programId }),
              let tIdx = programs[pIdx].tasks.firstIndex(where: { $0.id == taskId })
        else { return }
        programs[pIdx].tasks[tIdx].isCompleted = true
        programs[pIdx].currentDay = programs[pIdx].tasks.filter { $0.isCompleted }.count
        checkBadges()
        savePrograms()
    }

    func resetProgram(_ programId: String) {
        guard let idx = programs.firstIndex(where: { $0.id == programId }) else { return }
        programs[idx].isActive   = false
        programs[idx].currentDay = 0
        programs[idx].startDate  = nil
        for tIdx in programs[idx].tasks.indices {
            programs[idx].tasks[tIdx].isCompleted = false
        }
        savePrograms()
    }

    // MARK: - SOS
    func markSOSUsed() {
        defaults.set(true, forKey: StorageKey.sosUsed)
        checkBadges()
        scheduleSOSFollowUp()
    }

    func saveChatMessages(_ messages: [ChatMessage]) {
        chatMessages = messages
        saveChat()
    }

    // MARK: - Daily limit
    func todayCheckInCount() -> Int {
        let cal = Calendar.current
        return moodEntries.filter { cal.isDateInToday($0.date) }.count
    }

    func canCheckInToday() -> Bool { todayCheckInCount() < 2 }

    // MARK: - Streak
    /// Consecutive days with at least one check-in, derived from `moodEntries`.
    var streak: Int {
        Streaks.consecutiveDays(containing: moodEntries.map { $0.date })
    }

    func checkBadges() {
        var updated = false
        for i in 0 ..< badges.count {
            if !badges[i].isUnlocked && shouldUnlock(badge: badges[i]) {
                badges[i].isUnlocked = true
                badges[i].unlockedDate = Date()
                newBadge = badges[i]
                showBadgeToast = true
                updated = true
            }
        }
        if updated { saveBadges() }
    }

    private func shouldUnlock(badge: Badge) -> Bool {
        BadgeRules.shouldUnlock(badge.id, progress: BadgeProgress(
            checkInCount:      moodEntries.count,
            streak:            streak,
            journalCount:      journalEntries.count,
            gratitudeCount:    gratitudeEntries.count,
            completedPrograms: programs.filter { $0.currentDay >= 7 }.count,
            sosUsed:           defaults.bool(forKey: StorageKey.sosUsed),
            distinctMoodCount: Set(moodEntries.map { $0.moodIndex }).count
        ))
    }

    func weeklyStats() -> WeeklyStats {
        WeeklyStats.compute(from: moodEntries, streak: streak)
    }

    // MARK: - Notifications
    func scheduleSOSFollowUp() {
        notifications.scheduleSOSFollowUp()
    }

    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        notifications.requestPermission(completion: completion)
    }

    func scheduleAllReminders() {
        var reminders: [NotificationScheduler.DailyReminder] = []
        if lunchReminderEnabled {
            reminders.append(.init(
                id: "lunch_reminder",
                title: L("notification.lunch.title"),
                body: L("notification.lunch.body"),
                hour: lunchReminderHour,
                minute: lunchReminderMinute
            ))
        }
        if eveningReminderEnabled {
            reminders.append(.init(
                id: "evening_reminder",
                title: L("notification.evening.title"),
                body: L("notification.evening.body"),
                hour: eveningReminderHour,
                minute: eveningReminderMinute
            ))
        }
        if affirmationsEnabled {
            let affirmation = dailyAffirmations.randomElement() ?? dailyAffirmations[0]
            reminders.append(.init(
                id: "affirmation_daily",
                title: L("notification.affirmation.title"),
                body: affirmation,
                hour: affirmationHour,
                minute: affirmationMinute
            ))
        }
        notifications.reschedule(reminders, removingIds: [
            "lunch_reminder", "evening_reminder", "affirmation_daily"
        ])
    }

    // Legacy single-reminder for onboarding
    func scheduleStreakReminder() {
        eveningReminderEnabled = true
        scheduleAllReminders()
        save()
    }

    func todayGratitudeEntry() -> GratitudeEntry? {
        let cal = Calendar.current
        return gratitudeEntries.first { cal.isDateInToday($0.date) }
    }

    func todayMoodEntry() -> MoodEntry? {
        let cal = Calendar.current
        return moodEntries.first { cal.isDateInToday($0.date) }
    }

    // MARK: - Apple Health
    var isHealthAvailable: Bool { HealthStore.isAvailable }

    /// Asks for Health permission and pulls a first snapshot. Returns whether
    /// the user is now connected.
    @discardableResult
    func connectHealth() async -> Bool {
        let granted = await health.requestAuthorization()
        healthEnabled = granted
        save()
        if granted { await refreshHealth() }
        return granted
    }

    func disconnectHealth() {
        healthEnabled = false
        healthSnapshot = nil
        defaults.removeObject(forKey: StorageKey.healthSnapshot)
        save()
    }

    /// Re-reads recent Health metrics and persists the snapshot.
    func refreshHealth() async {
        guard healthEnabled else { return }
        let cal = Calendar.current
        let moodByDay = Dictionary(
            moodEntries.map { (cal.startOfDay(for: $0.date), $0.moodIndex) },
            uniquingKeysWith: { a, _ in a }
        )
        let snap = await health.snapshot(moodByDay: moodByDay)
        healthSnapshot = snap
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: StorageKey.healthSnapshot)
        }
    }

    // MARK: - LLM
    private var isAnthropicEndpoint: Bool { llmEndpoint.contains("anthropic.com") }

    var effectiveModel: String {
        guard llmModel.isEmpty else { return llmModel }
        if !Secrets.defaultModel.isEmpty && llmEndpoint == Secrets.defaultEndpoint {
            return Secrets.defaultModel
        }
        return isAnthropicEndpoint ? "claude-sonnet-4-6" : "gpt-4o"
    }

    /// True when AI features can work: either the user brought their own key
    /// or the app ships with a bundled one.
    var isAIConfigured: Bool {
        !claudeAPIKey.isEmpty || !Secrets.defaultAPIKey.isEmpty
    }

    private var llmConfig: LLMClient.Config {
        // No personal key → use the bundled provider as one consistent unit
        // (endpoint + model + key), ignoring any stale saved endpoint.
        if claudeAPIKey.isEmpty && !Secrets.defaultAPIKey.isEmpty {
            return .init(
                endpoint: Secrets.defaultEndpoint,
                model:    Secrets.defaultModel.isEmpty ? effectiveModel : Secrets.defaultModel,
                apiKey:   Secrets.defaultAPIKey,
                reasoningEffort: "none"
            )
        }
        // Personal key: send reasoning_effort only if it points at our host.
        return .init(
            endpoint: llmEndpoint,
            model:    effectiveModel,
            apiKey:   claudeAPIKey,
            reasoningEffort: llmEndpoint == Secrets.defaultEndpoint ? "none" : nil
        )
    }

    /// Compact memory of the user's recent history, injected into AI prompts
    /// so the assistant feels personal. Nil until there's enough data.
    var memorySummary: String? {
        UserContext.summary(
            name: userName,
            moods: moodEntries,
            journals: journalEntries,
            gratitude: gratitudeEntries,
            streak: streak,
            health: healthEnabled ? healthSnapshot : nil
        )
    }

    func fetchLLM(system: String, userPrompt: String, maxTokens: Int) async throws -> String {
        try await fetchLLMChat(
            system: system,
            messages: [.init(role: "user", content: userPrompt)],
            maxTokens: maxTokens
        )
    }

    func fetchLLMChat(system: String, messages: [LLMClient.Message], maxTokens: Int) async throws -> String {
        try await LLMClient().complete(
            system: system,
            messages: messages,
            maxTokens: maxTokens,
            config: llmConfig
        )
    }

    // MARK: - Face ID
    /// Whether the device can verify its owner (biometrics or passcode).
    var isDeviceAuthAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Nothing to verify against (passcode removed) — the lock can't
            // protect anything, so switch it off honestly rather than keep
            // showing an enabled toggle that waves everyone through.
            faceLockEnabled = false
            save()
            completion(true)
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: L("facelock.reason")
        ) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}

// MARK: - BreathingViewModel
// Fires a timer only at phase boundaries; the ring fill in between is
// interpolated by the SwiftUI animation system, not by 20 Hz ticks.
class BreathingViewModel: ObservableObject {
    @Published var phaseLabel: String = ""
    @Published var phaseDuration: Double = 0
    @Published var phaseId: Int = 0          // increments on every phase start, drives the ring animation
    @Published var isRunning: Bool = false
    @Published var currentCycle: Int = 0
    @Published var totalCycles: Int = 4
    @Published var selectedExerciseId: String = "box"

    private var timer: Timer?
    private var phaseIndex: Int = 0

    var currentExercise: BreathingExerciseModel {
        BreathingExerciseModel.allExercises.first { $0.id == selectedExerciseId }
            ?? BreathingExerciseModel.allExercises[0]
    }

    func start() {
        isRunning    = true
        phaseIndex   = 0
        currentCycle = 0
        beginPhase()
    }

    func stop() {
        timer?.invalidate()
        timer      = nil
        isRunning  = false
        phaseLabel = ""
        phaseDuration = 0
    }

    private func beginPhase() {
        let phases = currentExercise.phases
        guard phaseIndex < phases.count else { return }
        phaseLabel    = phases[phaseIndex].name
        phaseDuration = Double(phases[phaseIndex].duration)
        phaseId      += 1

        timer?.invalidate()
        let t = Timer(timeInterval: phaseDuration, repeats: false) { [weak self] _ in
            self?.advancePhase()
        }
        RunLoop.main.add(t, forMode: .common)  // keep firing during scroll
        timer = t
    }

    private func advancePhase() {
        phaseIndex += 1
        if phaseIndex >= currentExercise.phases.count {
            phaseIndex    = 0
            currentCycle += 1
            if currentCycle >= totalCycles {
                stop()
                return
            }
        }
        beginPhase()
    }
}

// MARK: - Daily Affirmations
let dailyAffirmations: [String] = (1...15).map { L("affirmation.\($0)") }
