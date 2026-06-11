import SwiftUI

// MARK: - AnalyticsView
struct AnalyticsView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var showMoodDNA      = false
    @State private var showMoodCalendar = false

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.s20) {
                    analyticsHeader
                    statsGrid
                    moodChartSection
                    if appVM.isHealthAvailable { healthSection }
                    calendarBanner
                    moodDNABanner
                    tagsSection
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, DS.s20)
                .padding(.top, DS.s8)
            }
        }
        .sheet(isPresented: $showMoodDNA) {
            MoodDNAView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMoodCalendar) {
            MoodCalendarView()
                .presentationDragIndicator(.visible)
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            SectionHeader(title: L("analytics.health.title"))
            GlassCard {
                VStack(spacing: DS.s12) {
                    if let snap = appVM.healthEnabled ? appVM.healthSnapshot : nil, snap.hasAnything {
                        HStack(spacing: DS.s12) {
                            if let s = snap.avgSleepHours {
                                HealthMetric(icon: "bed.double.fill", color: Color(hex: "818CF8"),
                                             value: String(format: "%.1f", s),
                                             unit: L("analytics.health.sleep_unit"),
                                             label: L("analytics.health.sleep"))
                            }
                            if let hr = snap.restingHeartRate {
                                HealthMetric(icon: "heart.fill", color: Color(hex: "FB7185"),
                                             value: "\(Int(hr))",
                                             unit: L("analytics.health.heart_unit"),
                                             label: L("analytics.health.heart"))
                            }
                            if let steps = snap.avgSteps {
                                HealthMetric(icon: "figure.walk", color: Color(hex: "34D399"),
                                             value: stepsShort(steps),
                                             unit: L("analytics.health.steps_unit"),
                                             label: L("analytics.health.steps"))
                            }
                        }
                        if snap.shortSleepLowersMood == true {
                            HStack(spacing: DS.s8) {
                                Image(systemName: "sparkles")
                                    .font(.app(size: 12)).foregroundColor(appVM.selectedTheme.primaryColor)
                                Text(L("analytics.health.signal"))
                                    .font(.app(size: 12, design: .rounded))
                                    .foregroundColor(DS.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    } else {
                        Text(L("analytics.health.empty"))
                            .font(.app(size: 13, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(DS.s16)
            }
        }
    }

    private func stepsShort(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    private var analyticsHeader: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            Text(L("analytics.title"))
                .font(.app(size: 26, weight: .bold))
                .foregroundColor(DS.textPrimary)
            Text(L("analytics.subtitle"))
                .font(.app(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(DS.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.s16)
    }

    private var statsGrid: some View {
        let stats = appVM.weeklyStats()
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.s12) {
            AnalyticsStat(value: String(format: "%.1f", stats.averageMood), label: L("analytics.avg_mood"),  icon: "circle.hexagongrid.fill", color: appVM.selectedTheme.primaryColor)
            AnalyticsStat(value: "\(stats.totalEntries)", label: L("analytics.entries"), icon: "checkmark.circle.fill", color: appVM.selectedTheme.secondaryColor)
            AnalyticsStat(value: "\(appVM.streak)",        label: L("analytics.streak"),  icon: "flame.fill",           color: Color(hex: "FBBF24"))
            AnalyticsStat(value: "\(appVM.journalEntries.count)", label: L("analytics.journal"), icon: "book.fill", color: Color(hex: "A78BFA"))
        }
    }

    private var moodChartSection: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            SectionHeader(title: L("analytics.mood_trend"))
            if appVM.moodEntries.isEmpty {
                GlassCard {
                    EmptyStateView(icon: "chart.line.uptrend.xyaxis", title: L("analytics.no_data.title"), subtitle: L("analytics.no_data.subtitle"))
                }
            } else {
                MoodTrendChart(entries: Array(appVM.moodEntries.prefix(14)))
            }
        }
    }

    private var calendarBanner: some View {
        Button(action: { HapticManager.impact(.light); showMoodCalendar = true }) {
            GlassCard {
                HStack(spacing: DS.s16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.r12).fill(appVM.selectedTheme.secondaryColor.opacity(0.15)).frame(width: 44, height: 44)
                        Image(systemName: "calendar").font(.app(size: 20)).foregroundStyle(appVM.selectedTheme.gradient)
                    }
                    VStack(alignment: .leading, spacing: DS.s4) {
                        Text(L("analytics.calendar.title")).font(.app(size: 15, weight: .semibold)).foregroundColor(DS.textPrimary)
                        Text(L("analytics.calendar.subtitle")).font(.app(size: 12, weight: .regular, design: .rounded)).foregroundColor(DS.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.app(size: 13, weight: .medium)).foregroundColor(DS.textTertiary)
                }
                .padding(DS.s20)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var moodDNABanner: some View {
        Button(action: { HapticManager.impact(.light); showMoodDNA = true }) {
            GlassCard {
                HStack(spacing: DS.s16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.r12).fill(appVM.selectedTheme.primaryColor.opacity(0.15)).frame(width: 44, height: 44)
                        Image(systemName: "circle.hexagongrid.fill").font(.app(size: 20)).foregroundStyle(appVM.selectedTheme.gradient)
                    }
                    VStack(alignment: .leading, spacing: DS.s4) {
                        Text(L("analytics.mood_dna.title")).font(.app(size: 15, weight: .semibold)).foregroundColor(DS.textPrimary)
                        Text(L("analytics.mood_dna.subtitle")).font(.app(size: 12, weight: .regular, design: .rounded)).foregroundColor(DS.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.app(size: 13, weight: .medium)).foregroundColor(DS.textTertiary)
                }
                .padding(DS.s20)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var tagsSection: some View {
        let allTags  = appVM.moodEntries.flatMap { $0.tags }
        let tagCount = allTags.reduce(into: [String: Int]()) { c, t in c[t, default: 0] += 1 }
        let sorted   = tagCount.sorted { $0.value > $1.value }.prefix(8)
        return Group {
            if !sorted.isEmpty {
                VStack(alignment: .leading, spacing: DS.s12) {
                    SectionHeader(title: L("analytics.top_tags"))
                    TopTagsCloud(tags: Array(sorted.map { ($0.key, $0.value) }))
                }
            }
        }
    }
}

// MARK: - HealthMetric
private struct HealthMetric: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: DS.s4) {
            Image(systemName: icon)
                .font(.app(size: 16))
                .foregroundColor(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.app(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                Text(unit)
                    .font(.app(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
            }
            Text(label)
                .font(.app(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(DS.textTertiary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - AnalyticsStat
private struct AnalyticsStat: View {
    @EnvironmentObject var appVM: AppViewModel
    let value: String; let label: String; let icon: String; let color: Color

    var body: some View {
        GlassCard {
            HStack(spacing: DS.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.r12).fill(color.opacity(0.12)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.app(size: 16)).foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: DS.s4) {
                    Text(value).font(.app(size: 22, weight: .bold, design: .rounded)).foregroundColor(DS.textPrimary)
                    Text(label).font(.app(size: 11, weight: .medium, design: .rounded)).foregroundColor(DS.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, DS.s16).padding(.vertical, DS.s14)
        }
    }
}

// MARK: - MoodTrendChart
private struct MoodTrendChart: View {
    @EnvironmentObject var appVM: AppViewModel
    let entries: [MoodEntry]

    var body: some View {
        GlassCard {
            VStack(spacing: DS.s12) {
                HStack(alignment: .bottom, spacing: DS.s6) {
                    ForEach(entries.reversed()) { entry in
                        VStack(spacing: DS.s6) {
                            moodDot(for: entry.moodIndex)
                            MoodBar(value: Double(entry.moodIndex + 1) / 5.0, height: 72)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(entry.moodName)
                    }
                }
                HStack {
                    Text(L("analytics.chart.14days")).font(.app(size: 10, weight: .medium, design: .rounded)).foregroundColor(DS.textTertiary)
                    Spacer()
                    Text("\(entries.count) \(L("analytics.entries"))").font(.app(size: 10, weight: .medium, design: .rounded)).foregroundColor(DS.textTertiary)
                }
            }
            .padding(DS.s16)
        }
    }

    private func moodDot(for index: Int) -> some View {
        Circle().fill(DS.moodColor(index)).frame(width: 5, height: 5)
    }
}

// MARK: - TopTagsCloud
private struct TopTagsCloud: View {
    @EnvironmentObject var appVM: AppViewModel
    let tags: [(String, Int)]

    var body: some View {
        GlassCard {
            FlowLayout(spacing: DS.s8) {
                ForEach(tags, id: \.0) { tag, count in
                    HStack(spacing: DS.s4) {
                        Text(L("tag.\(tag)"))
                            .font(.app(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textSecondary)
                        Text("×\(count)")
                            .font(.app(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(appVM.selectedTheme.primaryColor)
                    }
                    .padding(.horizontal, DS.s10).padding(.vertical, DS.s6)
                    .background(
                        Capsule().fill(appVM.selectedTheme.primaryColor.opacity(0.10))
                            .overlay(Capsule().strokeBorder(appVM.selectedTheme.primaryColor.opacity(0.20), lineWidth: 1))
                    )
                }
            }
            .padding(DS.s16)
        }
    }
}

// MARK: - FlowLayout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > w && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, s.height); x += s.width + spacing
        }
        return CGSize(width: w, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            rowH = max(rowH, s.height); x += s.width + spacing
        }
    }
}

// MARK: - MoodDNAView
struct MoodDNAView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                dnaHeader
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s24) {
                        if appVM.moodEntries.count < 7 { notEnoughDataView }
                        else { weekdaySection; timeOfDaySection; insightsSection }
                        Spacer(minLength: 110)
                    }
                    .padding(.horizontal, DS.s20).padding(.top, DS.s16)
                }
            }
        }
    }

    private var dnaHeader: some View {
        SheetHeader(title: L("analytics.mood_dna.title"))
    }

    private var notEnoughDataView: some View {
        GlassCard {
            EmptyStateView(icon: "chart.bar.xaxis", title: L("analytics.dna.not_enough.title"), subtitle: L("analytics.dna.not_enough.subtitle"))
        }
        .padding(.top, DS.s24)
    }

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            SectionHeader(title: L("analytics.dna.weekday"))
            WeekdayHeatmap(entries: appVM.moodEntries)
        }
    }

    private var timeOfDaySection: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            SectionHeader(title: L("analytics.dna.time_of_day"))
            TimeOfDayChart(entries: appVM.moodEntries)
        }
    }

    private var insightsSection: some View {
        let insights = generateInsights()
        return VStack(alignment: .leading, spacing: DS.s12) {
            SectionHeader(title: L("analytics.dna.insights"))
            ForEach(insights.indices, id: \.self) { i in
                GlassCard(level: .subtle) {
                    HStack(alignment: .top, spacing: DS.s12) {
                        Image(systemName: "sparkle").font(.app(size: 13)).foregroundColor(appVM.selectedTheme.primaryColor).padding(.top, 2)
                        Text(insights[i]).font(.app(size: 14, weight: .regular, design: .rounded)).foregroundColor(DS.textSecondary).lineSpacing(3)
                    }
                    .padding(DS.s16)
                }
            }
        }
    }

    private func generateInsights() -> [String] {
        var insights: [String] = []
        let entries = appVM.moodEntries
        guard !entries.isEmpty else { return [L("analytics.dna.insight.default")] }
        let avgMood = Double(entries.map { $0.moodIndex }.reduce(0, +)) / Double(entries.count)
        if avgMood > 3.0 { insights.append(L("analytics.dna.insight.positive")) }
        else if avgMood < 2.0 { insights.append(L("analytics.dna.insight.challenging")) }
        let cal = Calendar.current
        let morningEntries = entries.filter { let h = cal.component(.hour, from: $0.date); return h >= 6 && h < 12 }
        if !morningEntries.isEmpty {
            let mAvg = Double(morningEntries.map { $0.moodIndex }.reduce(0, +)) / Double(morningEntries.count)
            if mAvg > avgMood { insights.append(L("analytics.dna.insight.morning_better")) }
        }
        let highStress = entries.filter { $0.stressLevel > 0.7 }
        if Double(highStress.count) / Double(entries.count) > 0.4 { insights.append(L("analytics.dna.insight.high_stress")) }
        return insights.isEmpty ? [L("analytics.dna.insight.default")] : insights
    }
}

// MARK: - WeekdayHeatmap
private struct WeekdayHeatmap: View {
    @EnvironmentObject var appVM: AppViewModel
    let entries: [MoodEntry]

    private var weekdayAverages: [Int: Double] {
        let cal = Calendar.current
        var sums = [Int: Int](); var counts = [Int: Int]()
        for e in entries {
            let wd = cal.component(.weekday, from: e.date)
            sums[wd, default: 0] += e.moodIndex; counts[wd, default: 0] += 1
        }
        return counts.reduce(into: [Int: Double]()) { r, pair in
            r[pair.key] = Double(sums[pair.key, default: 0]) / Double(pair.value)
        }
    }

    var body: some View {
        GlassCard {
            HStack(spacing: DS.s6) {
                ForEach(1 ..< 8, id: \.self) { wd in
                    let avg = weekdayAverages[wd] ?? 0
                    VStack(spacing: DS.s6) {
                        MoodBar(value: avg / 4.0, height: 64)
                        Text(weekdayName(wd)).font(.app(size: 9, weight: .medium, design: .rounded)).foregroundColor(DS.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(DS.s16)
        }
    }
}

// MARK: - TimeOfDayChart
private struct TimeOfDayChart: View {
    @EnvironmentObject var appVM: AppViewModel
    let entries: [MoodEntry]

    private let periods = [
        (L("analytics.dna.morning"), 6, 12),
        (L("analytics.dna.afternoon"), 12, 18),
        (L("analytics.dna.evening"), 18, 24),
        (L("analytics.dna.night"), 0, 6)
    ]

    private func avgMood(start: Int, end: Int) -> Double {
        let cal = Calendar.current
        let filtered = entries.filter { let h = cal.component(.hour, from: $0.date); return start < end ? (h >= start && h < end) : (h >= start || h < end) }
        guard !filtered.isEmpty else { return 0 }
        return Double(filtered.map { $0.moodIndex }.reduce(0, +)) / Double(filtered.count)
    }

    var body: some View {
        GlassCard {
            HStack(spacing: DS.s8) {
                ForEach(0 ..< periods.count, id: \.self) { i in
                    let avg = avgMood(start: periods[i].1, end: periods[i].2)
                    VStack(spacing: DS.s6) {
                        MoodBar(value: avg / 4.0, height: 64)
                        Text(periods[i].0).font(.app(size: 9, weight: .medium, design: .rounded)).foregroundColor(DS.textTertiary).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(DS.s16)
        }
    }
}
