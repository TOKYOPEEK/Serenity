import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var showCheckIn      = false
    @State private var showSOS          = false
    @State private var showBreathing    = false
    @State private var showGratitude    = false
    @State private var showWeeklyReport = false
    @State private var showLimitAlert   = false
    @State private var showAllPrograms  = false
    @State private var selectedProgram: WellnessProgram?
    @State private var animateIn        = false

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.s20) {
                    headerSection
                        .padding(.top, DS.s8)
                    CompanionView(state: appVM.companionState)
                        .padding(.top, DS.s4)
                    moodHeroCard
                    quickActionsRow
                    if !appVM.moodEntries.isEmpty { recentMoodSection }
                    programsSection
                    aiCompanionCard
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, DS.s20)
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 16)
        .onAppear {
            withAnimation(DS.springGentle.delay(0.05)) { animateIn = true }
        }
        .sheet(isPresented: $showCheckIn) {
            CheckInView()
        }
        .sheet(isPresented: $showSOS) {
            SOSView()
        }
        .sheet(isPresented: $showBreathing) {
            ExerciseDetailView(exerciseId: "box")
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGratitude) {
            GratitudeView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWeeklyReport) {
            WeeklyReportView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAllPrograms) {
            ProgramsView()
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedProgram) { prog in
            ProgramDetailView(programId: prog.id)
                .presentationDragIndicator(.visible)
        }
        .alert(L("checkin.limit.title"), isPresented: $showLimitAlert) {
            Button(L("common.done"), role: .cancel) {}
        } message: {
            Text(L("checkin.limit.body"))
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            HStack(spacing: DS.s12) {
                SerenityLogo(size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(greetingText)
                        .font(.app(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                    Text(appVM.userName.isEmpty ? "Serenity" : appVM.userName)
                        .font(.app(size: 22, weight: .bold))
                        .foregroundColor(DS.textPrimary)
                }
            }
            Spacer()
            // Weekly report button
            Button(action: { showWeeklyReport = true }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 36, height: 36)
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.app(size: 14, weight: .medium))
                        .foregroundColor(appVM.selectedTheme.primaryColor)
                }
                .overlay(Circle().strokeBorder(appVM.selectedTheme.primaryColor.opacity(0.25), lineWidth: 1))
            }
            .accessibilityLabel(L("home.weekly_report.title"))
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12  { return L("greeting.morning") }
        if hour < 17  { return L("greeting.afternoon") }
        return L("greeting.evening")
    }

    // MARK: - Mood hero card
    private var moodHeroCard: some View {
        Button(action: {
            if appVM.canCheckInToday() {
                showCheckIn = true
            } else {
                showLimitAlert = true
            }
        }) {
            GlassCard {
                HStack(spacing: DS.s16) {
                    VStack(alignment: .leading, spacing: DS.s8) {
                        Text(L("home.checkin.prompt"))
                            .font(.app(size: 18, weight: .semibold))
                            .foregroundColor(DS.textPrimary)

                        if let entry = appVM.todayMoodEntry() {
                            HStack(spacing: DS.s8) {
                                MoodOrbView(moodIndex: entry.moodIndex, size: 28, isSelected: true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.moodName)
                                        .font(.app(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(DS.textSecondary)
                                    if appVM.todayCheckInCount() < 2 {
                                        Text(L("checkin.second_available"))
                                            .font(.app(size: 11, design: .rounded))
                                            .foregroundColor(DS.textTertiary)
                                    } else {
                                        Text(L("checkin.limit.done"))
                                            .font(.app(size: 11, design: .rounded))
                                            .foregroundColor(DS.textTertiary)
                                    }
                                }
                            }
                        } else {
                            Text(L("home.checkin.cta"))
                                .font(.app(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(DS.textTertiary)
                        }
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(appVM.canCheckInToday()
                                  ? appVM.selectedTheme.primaryColor.opacity(0.15)
                                  : Color.white.opacity(0.05))
                            .frame(width: 48, height: 48)
                        Image(systemName: appVM.todayMoodEntry() == nil
                              ? "plus"
                              : appVM.canCheckInToday() ? "plus" : "checkmark")
                            .font(.app(size: 18, weight: .medium))
                            .foregroundStyle(appVM.canCheckInToday()
                                             ? AnyShapeStyle(appVM.selectedTheme.gradient)
                                             : AnyShapeStyle(DS.textTertiary))
                    }
                }
                .padding(DS.s20)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Quick actions
    private var quickActionsRow: some View {
        HStack(spacing: DS.s12) {
            HomeQuickAction(icon: "wind",               label: L("home.breathe"),   color: appVM.selectedTheme.primaryColor)  { showBreathing = true }
            HomeQuickAction(icon: "heart.text.square.fill", label: L("home.gratitude"), color: appVM.selectedTheme.secondaryColor) { showGratitude = true }
            HomeQuickAction(icon: "waveform.path.ecg", label: "SOS",               color: Color(hex: "F87171"))              { showSOS = true }
        }
    }

    // MARK: - Recent mood trend
    private var recentMoodSection: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            SectionHeader(title: L("home.recent_mood"))
            TrendBarChart(entries: Array(appVM.moodEntries.prefix(7)))
        }
    }

    // MARK: - Programs
    // The catalog lives here now (no dedicated tab): active programs with a
    // "see all" link, or a browse card when nothing is in progress yet.
    private var programsSection: some View {
        let active = appVM.programs.filter { $0.isActive }
        return Group {
            if active.isEmpty {
                browseProgramsCard
            } else {
                VStack(alignment: .leading, spacing: DS.s12) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(title: L("home.active_programs"))
                        Button(action: { showAllPrograms = true }) {
                            HStack(spacing: DS.s4) {
                                Text(L("common.see_all"))
                                    .font(.app(size: 13, weight: .medium, design: .rounded))
                                Image(systemName: "chevron.right")
                                    .font(.app(size: 10, weight: .semibold))
                            }
                            .foregroundColor(appVM.selectedTheme.primaryColor)
                        }
                        .accessibilityLabel(L("programs.title"))
                    }
                    ForEach(active.prefix(2)) { prog in
                        Button(action: { HapticManager.impact(.light); selectedProgram = prog }) {
                            HomeProgramCard(program: prog)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private var browseProgramsCard: some View {
        Button(action: { HapticManager.impact(.light); showAllPrograms = true }) {
            GlassCard {
                HStack(spacing: DS.s16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                            .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "rectangle.stack.fill")
                            .font(.app(size: 20))
                            .foregroundStyle(appVM.selectedTheme.gradient)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("programs.title"))
                            .font(.app(size: 15, weight: .semibold))
                            .foregroundColor(DS.textPrimary)
                        Text(L("programs.subtitle"))
                            .font(.app(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.app(size: 13, weight: .medium))
                        .foregroundColor(DS.textTertiary)
                }
                .padding(DS.s20)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - AI companion card
    private var aiCompanionCard: some View {
        Button(action: {
            HapticManager.impact(.light)
            withAnimation(DS.springSmooth) { appVM.selectedTab = 2 }
        }) {
            GlassCard {
                HStack(spacing: DS.s16) {
                    ZStack {
                        Circle()
                            .fill(appVM.selectedTheme.gradient)
                            .frame(width: 48, height: 48)
                            .blur(radius: 2)
                            .opacity(0.6)
                        Circle()
                            .fill(RadialGradient(
                                colors: [
                                    appVM.selectedTheme.primaryColor.opacity(0.8),
                                    appVM.selectedTheme.secondaryColor.opacity(0.4)
                                ],
                                center: .center, startRadius: 0, endRadius: 24
                            ))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkle")
                            .font(.app(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("home.ai_companion.title"))
                            .font(.app(size: 15, weight: .semibold))
                            .foregroundColor(DS.textPrimary)
                        Text(L("home.ai_companion.subtitle"))
                            .font(.app(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.app(size: 13, weight: .medium))
                        .foregroundColor(DS.textTertiary)
                }
                .padding(DS.s20)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - HomeQuickAction
private struct HomeQuickAction: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: { HapticManager.impact(.medium); action() }) {
            VStack(spacing: DS.s8) {
                Image(systemName: icon)
                    .font(.app(size: 22))
                    .foregroundColor(color)
                Text(label)
                    .font(.app(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.s16)
            .background(
                RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                    .fill(color.opacity(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                            .strokeBorder(color.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - TrendBarChart
private struct TrendBarChart: View {
    @EnvironmentObject var appVM: AppViewModel
    let entries: [MoodEntry]

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("Md")  // "6/10" en, "10.06" ru
        return f
    }()

    var body: some View {
        GlassCard {
            HStack(alignment: .bottom, spacing: DS.s8) {
                ForEach(entries.reversed()) { entry in
                    VStack(spacing: DS.s6) {
                        MoodBar(value: Double(entry.moodIndex + 1) / 5.0, height: 52)
                        Text(Self.dayFormatter.string(from: entry.date))
                            .font(.app(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Self.dayFormatter.string(from: entry.date)), \(entry.moodName)")
                }
            }
            .padding(DS.s16)
        }
    }
}

// MARK: - HomeProgramCard
private struct HomeProgramCard: View {
    @EnvironmentObject var appVM: AppViewModel
    let program: WellnessProgram

    private var progress: Double {
        guard program.duration > 0 else { return 0 }
        return Double(program.currentDay) / Double(program.duration)
    }

    var body: some View {
        GlassCard {
            HStack(spacing: DS.s14) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.r12, style: .continuous)
                        .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: program.category.icon)
                        .font(.app(size: 18))
                        .foregroundColor(appVM.selectedTheme.primaryColor)
                }
                VStack(alignment: .leading, spacing: DS.s6) {
                    Text(program.localizedName)
                        .font(.app(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08)).frame(height: 3)
                            Capsule()
                                .fill(appVM.selectedTheme.gradient)
                                .frame(width: geo.size.width * CGFloat(progress), height: 3)
                        }
                    }
                    .frame(height: 3)
                    Text(String(format: L("programs.day_format"), program.currentDay, program.duration))
                        .font(.app(size: 11, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                }
            }
            .padding(DS.s16)
        }
    }
}
