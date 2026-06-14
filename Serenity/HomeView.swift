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
    @State private var showReframe      = false
    @State private var showCopingPlan   = false
    @State private var showHabits       = false
    @State private var affirmationLoading = false
    @State private var showFocus        = false
    @State private var showLibrary      = false
    @State private var selectedProgram: WellnessProgram?

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.s20) {
                    // Сегодня — приветствие, аффирмация, чек-ин, быстрые действия, инсайт
                    headerSection
                        .padding(.top, DS.s8).appear(0.0)
                    affirmationCard.appear(0.05)
                    moodHeroCard.appear(0.10)
                    quickActionsRow.appear(0.15)
                    insightCard.appear(0.20)

                    // AI-чат — флагман, сразу под личной зоной
                    aiCompanionCard.appear(0.25)

                    // Практики — медитации/звуки, инструменты, фокус
                    practicesSection.appear(0.30)

                    // Твоя динамика — тренд, привычки, программы
                    progressSection.appear(0.35)

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, DS.s20)
            }
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
        .sheet(isPresented: $showReframe) {
            ThoughtReframeView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCopingPlan) {
            CopingPlanView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHabits) {
            HabitsView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFocus) {
            FocusView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLibrary) {
            LibraryView()
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

    // MARK: - Affirmation (#20)
    private var affirmationCard: some View {
        GlassCard {
            HStack(spacing: DS.s14) {
                Image(systemName: "quote.opening")
                    .font(.app(size: 16))
                    .foregroundStyle(appVM.selectedTheme.gradient)
                Text(appVM.currentAffirmation)
                    .font(.app(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if appVM.isAIConfigured {
                    Button(action: refreshAffirmation) {
                        Image(systemName: "sparkles")
                            .font(.app(size: 15, weight: .medium))
                            .foregroundColor(appVM.selectedTheme.primaryColor)
                            .opacity(affirmationLoading ? 0.4 : 1)
                            .rotationEffect(.degrees(affirmationLoading ? 360 : 0))
                            .animation(affirmationLoading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: affirmationLoading)
                    }
                    .disabled(affirmationLoading)
                    .accessibilityLabel(L("home.affirmation.personalize"))
                }
            }
            .padding(DS.s16)
        }
    }

    private func refreshAffirmation() {
        HapticManager.impact(.light)
        affirmationLoading = true
        Task {
            await appVM.generatePersonalAffirmation()
            affirmationLoading = false
        }
    }

    // MARK: - Habits (#48)
    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(title: L("home.habits"))
                Button(action: { HapticManager.impact(.light); showHabits = true }) {
                    Image(systemName: appVM.habits.isEmpty ? "plus.circle.fill" : "slider.horizontal.3")
                        .font(.app(size: 15, weight: .medium))
                        .foregroundColor(appVM.selectedTheme.primaryColor)
                }
                .accessibilityLabel(L("habits.title"))
            }
            if appVM.habits.isEmpty {
                Button(action: { HapticManager.impact(.light); showHabits = true }) {
                    GlassCard {
                        HStack(spacing: DS.s12) {
                            Image(systemName: "checklist")
                                .font(.app(size: 18))
                                .foregroundColor(appVM.selectedTheme.primaryColor)
                            Text(L("home.habits.empty"))
                                .font(.app(size: 14, design: .rounded))
                                .foregroundColor(DS.textSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(DS.s16)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                VStack(spacing: DS.s10) {
                    ForEach(appVM.habits) { habit in
                        HabitTodayRow(habit: habit) { appVM.toggleHabitToday(habit) }
                    }
                }
            }
        }
    }

    // MARK: - Proactive insight
    @ViewBuilder private var insightCard: some View {
        if let insight = appVM.proactiveInsight {
            GlassCard {
                VStack(alignment: .leading, spacing: DS.s10) {
                    HStack(spacing: DS.s8) {
                        Image(systemName: "sparkles")
                            .font(.app(size: 13)).foregroundStyle(appVM.selectedTheme.gradient)
                        Text(L("home.insight.title"))
                            .font(.app(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                        Spacer(minLength: 0)
                    }
                    Text(insight)
                        .font(.app(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: {
                        HapticManager.impact(.light)
                        withAnimation(DS.springSmooth) { appVM.selectedTab = 2 }
                    }) {
                        HStack(spacing: DS.s4) {
                            Text(L("home.insight.discuss"))
                            Image(systemName: "arrow.right").font(.app(size: 11, weight: .semibold))
                        }
                        .font(.app(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(appVM.selectedTheme.primaryColor)
                    }
                }
                .padding(DS.s16)
            }
        }
    }

    // MARK: - Library (meditations + sounds)
    private var libraryCard: some View {
        Button(action: { HapticManager.impact(.light); showLibrary = true }) {
            GlassCard {
                HStack(spacing: DS.s16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                            .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "headphones")
                            .font(.app(size: 20))
                            .foregroundStyle(appVM.selectedTheme.gradient)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("home.library"))
                            .font(.app(size: 15, weight: .semibold))
                            .foregroundColor(DS.textPrimary)
                        Text(L("home.library.sub"))
                            .font(.app(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.app(size: 13, weight: .medium))
                        .foregroundColor(DS.textTertiary)
                }
                .padding(DS.s20)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Практики (meditations & sounds + CBT tools + focus)
    private var practicesSection: some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            SectionHeader(title: L("home.section.practices"))
            libraryCard
            HStack(spacing: DS.s12) {
                ToolCard(icon: "arrow.triangle.2.circlepath",
                         title: L("cbt.reframe.title"),
                         color: appVM.selectedTheme.primaryColor) { showReframe = true }
                ToolCard(icon: "list.bullet.clipboard.fill",
                         title: L("cbt.coping.title"),
                         color: appVM.selectedTheme.secondaryColor) { showCopingPlan = true }
            }
            ToolCard(icon: "timer",
                     title: L("focus.title"),
                     color: appVM.selectedTheme.primaryColor) { showFocus = true }
        }
    }

    // MARK: - Quick actions
    private var quickActionsRow: some View {
        HStack(spacing: DS.s12) {
            HomeQuickAction(icon: "wind",               label: L("home.breathe"),   color: appVM.selectedTheme.primaryColor)  { showBreathing = true }
            HomeQuickAction(icon: "heart.text.square.fill", label: L("home.gratitude"), color: appVM.selectedTheme.secondaryColor) { showGratitude = true }
            HomeQuickAction(icon: "waveform.path.ecg", label: "SOS",               color: Color(hex: "F87171"))              { showSOS = true }
        }
    }

    // MARK: - Твоя динамика (trend + habits + programs)
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: DS.s20) {
            SectionHeader(title: L("home.section.progress"))
            if !appVM.moodEntries.isEmpty {
                TrendBarChart(entries: Array(appVM.moodEntries.prefix(7)))
            }
            habitsSection
            programsSection
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
private struct HabitTodayRow: View {
    @EnvironmentObject var appVM: AppViewModel
    let habit: Habit
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            GlassCard {
                HStack(spacing: DS.s14) {
                    Image(systemName: habit.icon)
                        .font(.app(size: 17))
                        .foregroundColor(habit.doneToday ? appVM.selectedTheme.primaryColor : DS.textTertiary)
                        .frame(width: 26)
                    Text(habit.name)
                        .font(.app(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(habit.doneToday ? DS.textPrimary : DS.textSecondary)
                        .strikethrough(habit.doneToday, color: DS.textTertiary)
                    Spacer(minLength: 0)
                    if habit.streak > 1 {
                        Text("\(habit.streak)🔥")
                            .font(.app(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                    }
                    Image(systemName: habit.doneToday ? "checkmark.circle.fill" : "circle")
                        .font(.app(size: 22))
                        .foregroundStyle(habit.doneToday
                            ? AnyShapeStyle(appVM.selectedTheme.gradient)
                            : AnyShapeStyle(DS.textTertiary))
                }
                .padding(.horizontal, DS.s16)
                .padding(.vertical, DS.s12)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(DS.springSnappy, value: habit.doneToday)
    }
}

private struct ToolCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: { HapticManager.impact(.light); action() }) {
            HStack(spacing: DS.s10) {
                Image(systemName: icon)
                    .font(.app(size: 18))
                    .foregroundColor(color)
                Text(title)
                    .font(.app(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(DS.s14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                    .fill(color.opacity(0.09))
                    .overlay(RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                        .strokeBorder(color.opacity(0.22), lineWidth: 1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

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
