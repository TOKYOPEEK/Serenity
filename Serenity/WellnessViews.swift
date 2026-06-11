import SwiftUI

// MARK: - GratitudeView
struct GratitudeView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var newText   = ""
    @State private var showSaved = false

    private var todayEntry: GratitudeEntry? { appVM.todayGratitudeEntry() }
    private var streak: Int {
        Streaks.consecutiveDays(containing: appVM.gratitudeEntries.map { $0.date })
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                gratitudeHeader
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s16) {
                        streakCard
                        todayCard
                        recentEntries
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, DS.s20)
                    .padding(.top, DS.s16)
                }
            }

            if showSaved {
                VStack {
                    Spacer()
                    HStack(spacing: DS.s10) {
                        Image(systemName: "heart.fill").foregroundStyle(appVM.selectedTheme.gradient)
                        Text(L("gratitude.saved"))
                            .font(.app(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textPrimary)
                    }
                    .padding(.horizontal, DS.s24).padding(.vertical, DS.s14)
                    .background(Capsule().fill(.regularMaterial).overlay(Capsule().strokeBorder(DS.strokeMedium, lineWidth: 1)))
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var gratitudeHeader: some View {
        SheetHeader(title: L("gratitude.title"))
    }

    private var streakCard: some View {
        GlassCard {
            HStack(spacing: DS.s16) {
                ZStack {
                    Circle().fill(appVM.selectedTheme.primaryColor.opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: "heart.fill").font(.app(size: 22)).foregroundStyle(appVM.selectedTheme.gradient)
                }
                VStack(alignment: .leading, spacing: DS.s4) {
                    Text(L("gratitude.streak_title"))
                        .font(.app(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                    HStack(alignment: .lastTextBaseline, spacing: DS.s4) {
                        Text("\(streak)").font(.app(size: 32, weight: .bold, design: .rounded)).foregroundStyle(appVM.selectedTheme.gradient)
                        Text(L("gratitude.days")).font(.app(size: 13, weight: .medium, design: .rounded)).foregroundColor(DS.textTertiary)
                    }
                }
                Spacer()
            }
            .padding(DS.s16)
        }
    }

    private var todayCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DS.s14) {
                Text(todayEntry == nil ? L("gratitude.today_prompt") : L("gratitude.today_done"))
                    .font(.app(size: 16, weight: .semibold)).foregroundColor(DS.textPrimary)

                if let entry = todayEntry {
                    Text(entry.text).font(.app(size: 15, design: .rounded)).foregroundColor(DS.textSecondary).lineSpacing(4)
                } else {
                    TextField(L("gratitude.placeholder"), text: $newText, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.app(size: 15, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                        .tint(appVM.selectedTheme.primaryColor)
                    if !newText.trimmingCharacters(in: .whitespaces).isEmpty {
                        PrimaryButton(title: L("gratitude.save")) { saveGratitude() }
                    }
                }
            }
            .padding(DS.s20)
        }
    }

    private var recentEntries: some View {
        let past = appVM.gratitudeEntries.filter { !Calendar.current.isDateInToday($0.date) }.prefix(10)
        return Group {
            if !past.isEmpty {
                VStack(alignment: .leading, spacing: DS.s12) {
                    SectionHeader(title: L("gratitude.recent"))
                    ForEach(Array(past)) { entry in
                        GratitudeEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    private func saveGratitude() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        appVM.addGratitudeEntry(GratitudeEntry(text: text))
        newText = ""
        HapticManager.notification(.success)
        withAnimation { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showSaved = false } }
    }
}

private struct GratitudeEntryRow: View {
    @EnvironmentObject var appVM: AppViewModel
    let entry: GratitudeEntry

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: DS.s12) {
                ZStack {
                    Circle().fill(appVM.selectedTheme.primaryColor.opacity(0.12)).frame(width: 28, height: 28)
                    Image(systemName: "heart.fill").font(.app(size: 11)).foregroundStyle(appVM.selectedTheme.gradient)
                }
                .padding(.top, 1)
                VStack(alignment: .leading, spacing: DS.s4) {
                    Text(entry.text)
                        .font(.app(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                    Text(relativeDate(entry.date))
                        .font(.app(size: 11, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                }
            }
            .padding(DS.s14)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - WeeklyReportView (available any day)
struct WeeklyReportView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var report    = ""
    @State private var isLoading = false
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                reportHeader
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s20) {
                        statsSection
                        narrativeSection
                        if !isLoading && !hasLoaded { generateButton }
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, DS.s20)
                    .padding(.top, DS.s16)
                }
            }
        }
    }

    private var reportHeader: some View {
        SheetHeader(title: L("report.title"))
    }

    private var statsSection: some View {
        let stats = appVM.weeklyStats()
        return GlassCard {
            VStack(spacing: DS.s16) {
                Text(L("report.week_of") + " " + weekRange)
                    .font(.app(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                HStack(spacing: 0) {
                    WeekStatItem(value: String(format: "%.1f", stats.averageMood), label: L("report.avg_mood"))
                    Divider().background(DS.strokeSubtle).frame(width: 1, height: 40)
                    WeekStatItem(value: "\(stats.totalEntries)", label: L("report.check_ins"))
                    Divider().background(DS.strokeSubtle).frame(width: 1, height: 40)
                    WeekStatItem(value: "\(stats.streak)", label: L("report.streak"))
                }
            }
            .padding(DS.s20)
        }
    }

    private var narrativeSection: some View {
        Group {
            if isLoading || !report.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: DS.s12) {
                        HStack(spacing: DS.s8) {
                            ZStack {
                                Circle().fill(appVM.selectedTheme.primaryColor.opacity(0.15)).frame(width: 28, height: 28)
                                Image(systemName: "sparkles").font(.app(size: 12)).foregroundStyle(appVM.selectedTheme.gradient)
                            }
                            Text(L("report.ai_summary")).font(.app(size: 15, weight: .semibold)).foregroundColor(DS.textPrimary)
                        }
                        if isLoading {
                            HStack(spacing: DS.s12) {
                                ProgressView().tint(appVM.selectedTheme.primaryColor)
                                Text(L("report.generating")).font(.app(size: 14, design: .rounded)).foregroundColor(DS.textTertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, DS.s20)
                        } else {
                            TypewriterText(fullText: report, speed: 0.018)
                                .font(.app(size: 15, design: .rounded))
                                .foregroundColor(DS.textSecondary)
                                .lineSpacing(5)
                        }
                    }
                    .padding(DS.s20)
                }
            }
        }
    }

    private var generateButton: some View {
        PrimaryButton(title: L("report.generate")) { loadReport() }
    }

    private var weekRange: String {
        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .day, value: -7, to: end) ?? end
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMd")  // "Jun 3" en, "3 июн." ru
        return f.string(from: start) + " – " + f.string(from: end)
    }

    private func loadReport() {
        hasLoaded = true
        isLoading = true
        let stats = appVM.weeklyStats()
        let moodNames = ["very bad", "bad", "neutral", "good", "great"]
        let topMoodName = moodNames[min(stats.topMood, 4)]
        let prompt = """
        Weekly mental wellness summary:
        - Average mood: \(String(format: "%.1f", stats.averageMood))/4
        - Most frequent mood: \(topMoodName)
        - Check-ins this week: \(stats.totalEntries)
        - Current streak: \(stats.streak) days
        - Top themes: \(stats.topTags.joined(separator: ", "))

        Write a warm, personal 2-3 paragraph narrative summary of this person's week.
        Be supportive, insightful, and suggest one focus for next week.
        Respond in the user's language (Russian or English — match the themes/tags language).
        """
        let system = "You are a compassionate wellness coach writing a warm weekly summary."
            + UserContext.systemPreamble(appVM.memorySummary)
        Task {
            do {
                report = try await appVM.fetchLLM(system: system, userPrompt: prompt, maxTokens: 500)
            } catch {
                report = L("report.ai_unavailable")
            }
            isLoading = false
        }
    }
}

private struct WeekStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: DS.s4) {
            Text(value).font(.app(size: 24, weight: .bold, design: .rounded)).foregroundColor(DS.textPrimary)
            Text(label).font(.app(size: 10, weight: .medium, design: .rounded)).foregroundColor(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

