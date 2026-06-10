import SwiftUI

// MARK: - ContentView (5-tab root)
struct ContentView: View {
    @EnvironmentObject var appVM: AppViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            // Single shared animated background for all tabs
            AmbientBackground()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $appVM.selectedTab)

            if appVM.showBadgeToast, let badge = appVM.newBadge {
                BadgeToast(badge: badge, isShowing: $appVM.showBadgeToast)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    // Only the active tab exists in the hierarchy; inactive tabs are torn down.
    @ViewBuilder
    private var tabContent: some View {
        switch appVM.selectedTab {
        case 0:  HomeView()
        case 1:  JournalView()
        case 2:  PsychologistChatView()
        case 3:  AnalyticsView()
        default: ProfileView()
        }
    }
}

// MARK: - CustomTabBar (5 items)
struct CustomTabBar: View {
    @EnvironmentObject var appVM: AppViewModel
    @Binding var selectedTab: Int

    private let items: [(icon: String, label: String)] = [
        ("house.fill",           "tab.home"),
        ("book.fill",            "tab.journal"),
        ("bubble.left.fill",     "tab.psychologist"),
        ("chart.xyaxis.line",    "tab.analytics"),
        ("person.fill",          "tab.profile")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< items.count, id: \.self) { i in
                TabBarItem(
                    icon:       items[i].icon,
                    label:      L(items[i].label),
                    isSelected: selectedTab == i,
                    theme:      appVM.selectedTheme
                ) {
                    HapticManager.impact(.light)
                    withAnimation(DS.springSnappy) { selectedTab = i }
                }
            }
        }
        .padding(.horizontal, DS.s8)
        .padding(.vertical, DS.s10)
        .background(tabBarBackground)
        .padding(.horizontal, DS.s16)
        .padding(.bottom, DS.s8)
    }

    private var tabBarBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.r32, style: .continuous)
                .fill(.thinMaterial)
            RoundedRectangle(cornerRadius: DS.r32, style: .continuous)
                .fill(appBG.opacity(0.55))
            RoundedRectangle(cornerRadius: DS.r32, style: .continuous)
                .strokeBorder(DS.strokeSubtle, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.35), radius: 20, y: 8)
    }
}

private struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let theme: AppColorTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.app(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? theme.primaryColor : DS.textTertiary)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(DS.springSnappy, value: isSelected)
                Text(label)
                    .font(.app(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? theme.primaryColor : DS.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

// MARK: - ProfileView
struct ProfileView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var showThemePicker   = false
    @State private var showAPIKeySheet   = false
    @State private var showCustomTags    = false
    @State private var apiKeyInput       = ""
    @State private var showResetAlert    = false
    @State private var showPasscodeAlert = false

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.s20) {
                    profileHeader
                    statsRow
                    apiKeyCard
                    appearanceSection
                    remindersSection
                    affirmationsSection
                    faceLockSection
                    customTagsSection
                    aiDisclaimerCard
                    milestonesSection
                    Spacer(minLength: 110)
                }
                .padding(.horizontal, DS.s20)
                .padding(.top, DS.s16)
            }
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAPIKeySheet) {
            APIKeySheet(apiKey: $apiKeyInput, isPresented: $showAPIKeySheet)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCustomTags) {
            CustomTagsView()
                .presentationDragIndicator(.visible)
        }
    }

    private var profileHeader: some View {
        GlassCard {
            HStack(spacing: DS.s16) {
                SerenityLogo(size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appVM.userName.isEmpty ? "Serenity" : appVM.userName)
                        .font(.app(size: 20, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.app(size: 11))
                            .foregroundColor(appVM.selectedTheme.primaryColor)
                        Text("\(appVM.streak) \(L("profile.days"))")
                            .font(.app(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textSecondary)
                    }
                }
                Spacer()
                Text(L("profile.title"))
                    .font(.app(size: 22, weight: .bold))
                    .foregroundColor(DS.textPrimary)
            }
            .padding(DS.s20)
        }
    }

    private var statsRow: some View {
        HStack(spacing: DS.s12) {
            ProfileStatCard(value: "\(appVM.moodEntries.count)",   label: L("profile.stat.checkins"))
            ProfileStatCard(value: "\(appVM.journalEntries.count)", label: L("profile.stat.entries"))
            ProfileStatCard(value: "\(appVM.badges.filter { $0.isUnlocked }.count)", label: L("profile.stat.badges"))
        }
    }

    // API key always visible
    private var apiKeyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DS.s10) {
                HStack(spacing: DS.s10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(appVM.isAIConfigured
                                  ? appVM.selectedTheme.primaryColor.opacity(0.15)
                                  : Color(hex: "F87171").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: appVM.isAIConfigured ? "key.fill" : "key.slash")
                            .font(.app(size: 14))
                            .foregroundColor(appVM.isAIConfigured
                                             ? appVM.selectedTheme.primaryColor
                                             : Color(hex: "F87171"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("profile.api_key"))
                            .font(.app(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textPrimary)
                        Text(appVM.isAIConfigured
                             ? L("profile.api_key_set")
                             : L("profile.api_key_empty"))
                            .font(.app(size: 11, design: .rounded))
                            .foregroundColor(appVM.isAIConfigured
                                             ? appVM.selectedTheme.primaryColor
                                             : Color(hex: "F87171"))
                    }
                    Spacer()
                    Button(action: {
                        apiKeyInput = appVM.claudeAPIKey
                        showAPIKeySheet = true
                    }) {
                        Text(appVM.claudeAPIKey.isEmpty ? L("profile.api_key_add") : L("profile.api_key_edit"))
                            .font(.app(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(appVM.selectedTheme.primaryColor)
                            .padding(.horizontal, DS.s10)
                            .padding(.vertical, DS.s6)
                            .background(
                                Capsule().fill(appVM.selectedTheme.primaryColor.opacity(0.12))
                            )
                    }
                }
            }
            .padding(DS.s16)
        }
    }

    private var appearanceSection: some View {
        GlassCard {
            ProfileRow(
                icon: "paintpalette.fill",
                color: appVM.selectedTheme.primaryColor,
                title: L("profile.theme")
            ) { showThemePicker = true }
            .padding(.vertical, DS.s4)
        }
    }

    private var remindersSection: some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack(spacing: DS.s14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "FBBF24").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "bell.fill")
                            .font(.app(size: 14))
                            .foregroundColor(Color(hex: "FBBF24"))
                    }
                    Text(L("profile.reminders"))
                        .font(.app(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, DS.s20)
                .padding(.top, DS.s16)
                .padding(.bottom, DS.s10)

                Divider().background(DS.strokeSubtle)

                Toggle(isOn: $appVM.lunchReminderEnabled) {
                    Text(L("profile.lunch_reminder"))
                        .font(.app(size: 14, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                }
                .tint(appVM.selectedTheme.primaryColor)
                .padding(.horizontal, DS.s20)
                .padding(.vertical, DS.s12)
                .onChange(of: appVM.lunchReminderEnabled) { _ in
                    appVM.save(); appVM.scheduleAllReminders()
                }

                if appVM.lunchReminderEnabled {
                    Divider().background(DS.strokeSubtle).padding(.horizontal, DS.s20)
                    TimePickerRow(
                        title: L("profile.reminder_time"),
                        icon: "sun.max.fill",
                        color: Color(hex: "FBBF24"),
                        hour: $appVM.lunchReminderHour,
                        minute: $appVM.lunchReminderMinute
                    )
                    .onChange(of: appVM.lunchReminderHour)   { _ in appVM.save(); appVM.scheduleAllReminders() }
                    .onChange(of: appVM.lunchReminderMinute) { _ in appVM.save(); appVM.scheduleAllReminders() }
                }

                Divider().background(DS.strokeSubtle)

                Toggle(isOn: $appVM.eveningReminderEnabled) {
                    Text(L("profile.evening_reminder"))
                        .font(.app(size: 14, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                }
                .tint(appVM.selectedTheme.primaryColor)
                .padding(.horizontal, DS.s20)
                .padding(.vertical, DS.s12)
                .onChange(of: appVM.eveningReminderEnabled) { _ in
                    appVM.save(); appVM.scheduleAllReminders()
                }

                if appVM.eveningReminderEnabled {
                    Divider().background(DS.strokeSubtle).padding(.horizontal, DS.s20)
                    TimePickerRow(
                        title: L("profile.reminder_time"),
                        icon: "moon.fill",
                        color: appVM.selectedTheme.primaryColor,
                        hour: $appVM.eveningReminderHour,
                        minute: $appVM.eveningReminderMinute
                    )
                    .onChange(of: appVM.eveningReminderHour)   { _ in appVM.save(); appVM.scheduleAllReminders() }
                    .onChange(of: appVM.eveningReminderMinute) { _ in appVM.save(); appVM.scheduleAllReminders() }
                    .padding(.bottom, DS.s4)
                }
            }
        }
    }

    private var affirmationsSection: some View {
        GlassCard {
            VStack(spacing: 0) {
                Toggle(isOn: $appVM.affirmationsEnabled) {
                    HStack(spacing: DS.s14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "A78BFA").opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "sparkles")
                                .font(.app(size: 14))
                                .foregroundColor(Color(hex: "A78BFA"))
                        }
                        Text(L("profile.affirmations"))
                            .font(.app(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textPrimary)
                    }
                }
                .tint(appVM.selectedTheme.primaryColor)
                .padding(.horizontal, DS.s20)
                .padding(.vertical, DS.s14)
                .onChange(of: appVM.affirmationsEnabled) { _ in
                    appVM.save(); appVM.scheduleAllReminders()
                }

                if appVM.affirmationsEnabled {
                    Divider().background(DS.strokeSubtle).padding(.horizontal, DS.s20)
                    TimePickerRow(
                        title: L("profile.reminder_time"),
                        icon: "sun.horizon.fill",
                        color: Color(hex: "A78BFA"),
                        hour: $appVM.affirmationHour,
                        minute: $appVM.affirmationMinute
                    )
                    .onChange(of: appVM.affirmationHour)   { _ in appVM.save(); appVM.scheduleAllReminders() }
                    .onChange(of: appVM.affirmationMinute) { _ in appVM.save(); appVM.scheduleAllReminders() }
                    .padding(.bottom, DS.s4)
                }
            }
        }
    }

    private var faceLockSection: some View {
        GlassCard {
            Toggle(isOn: $appVM.faceLockEnabled) {
                HStack(spacing: DS.s14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "34D399").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "faceid")
                            .font(.app(size: 14))
                            .foregroundColor(Color(hex: "34D399"))
                    }
                    Text(L("profile.face_id"))
                        .font(.app(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                }
            }
            .tint(appVM.selectedTheme.primaryColor)
            .padding(.horizontal, DS.s20)
            .padding(.vertical, DS.s14)
            .onChange(of: appVM.faceLockEnabled) { _ in
                if appVM.faceLockEnabled {
                    if appVM.isDeviceAuthAvailable {
                        appVM.isUnlocked = true
                    } else {
                        // No passcode on the device — the lock would be fake.
                        appVM.faceLockEnabled = false
                        showPasscodeAlert = true
                    }
                }
                appVM.save()
            }
            .alert(L("profile.face_id.unavailable.title"), isPresented: $showPasscodeAlert) {
                Button(L("common.done"), role: .cancel) {}
            } message: {
                Text(L("profile.face_id.unavailable.body"))
            }
        }
    }

    private var customTagsSection: some View {
        GlassCard {
            ProfileRow(
                icon: "tag.fill",
                color: appVM.selectedTheme.secondaryColor,
                title: L("profile.custom_tags")
            ) { showCustomTags = true }
            .padding(.vertical, DS.s4)
        }
    }

    private var aiDisclaimerCard: some View {
        GlassCard(level: .subtle) {
            VStack(alignment: .leading, spacing: DS.s8) {
                HStack(spacing: DS.s8) {
                    Image(systemName: "info.circle")
                        .font(.app(size: 14))
                        .foregroundColor(DS.textTertiary)
                    Text(L("profile.disclaimer_title"))
                        .font(.app(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                }
                Text(L("profile.disclaimer_body"))
                    .font(.app(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                    .lineSpacing(3)
            }
            .padding(DS.s16)
        }
    }

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: DS.s16) {
            SectionHeader(title: L("profile.milestones"))
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: DS.s12
            ) {
                ForEach(appVM.badges) { badge in
                    MilestoneCell(badge: badge)
                }
            }
        }
    }
}

// MARK: - CustomTagsView
struct CustomTagsView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newTag = ""

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                SheetHeader(title: L("profile.custom_tags"))
                Divider().background(DS.strokeSubtle)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s16) {
                        // Add new tag
                        GlassCard {
                            HStack(spacing: DS.s10) {
                                TextField(L("tags.custom.placeholder"), text: $newTag)
                                    .font(.app(size: 15, design: .rounded))
                                    .foregroundColor(DS.textPrimary)
                                    .tint(appVM.selectedTheme.primaryColor)
                                Button(action: addTag) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.app(size: 22))
                                        .foregroundColor(appVM.selectedTheme.primaryColor)
                                }
                                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(DS.s16)
                        }

                        if !appVM.customTags.isEmpty {
                            VStack(alignment: .leading, spacing: DS.s12) {
                                SectionHeader(title: L("tags.custom.title"))
                                FlowLayout(spacing: DS.s8) {
                                    ForEach(appVM.customTags, id: \.self) { tag in
                                        HStack(spacing: DS.s6) {
                                            Text(tag)
                                                .font(.app(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(DS.textSecondary)
                                            Button(action: { appVM.removeCustomTag(tag) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.app(size: 14))
                                                    .foregroundColor(DS.textTertiary)
                                            }
                                            .accessibilityLabel("\(L("common.delete")): \(tag)")
                                        }
                                        .padding(.horizontal, DS.s12)
                                        .padding(.vertical, DS.s8)
                                        .background(
                                            Capsule()
                                                .fill(appVM.selectedTheme.primaryColor.opacity(0.10))
                                                .overlay(Capsule().strokeBorder(appVM.selectedTheme.primaryColor.opacity(0.25), lineWidth: 1))
                                        )
                                    }
                                }
                                .padding(DS.s16)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.r20, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                        .overlay(RoundedRectangle(cornerRadius: DS.r20).strokeBorder(DS.strokeSubtle, lineWidth: 1))
                                )
                            }
                        }
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, DS.s20)
                    .padding(.top, DS.s16)
                }
            }
        }
    }

    private func addTag() {
        appVM.addCustomTag(newTag)
        newTag = ""
    }
}

// MARK: - ProfileStatCard
private struct ProfileStatCard: View {
    @EnvironmentObject var appVM: AppViewModel
    let value: String
    let label: String

    var body: some View {
        GlassCard {
            VStack(spacing: DS.s4) {
                Text(value)
                    .font(.app(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(appVM.selectedTheme.gradient)
                Text(label)
                    .font(.app(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.s16)
        }
    }
}

// MARK: - ProfileRow
struct ProfileRow: View {
    let icon: String
    let color: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            HStack(spacing: DS.s14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.app(size: 14, weight: .medium))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.app(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.app(size: 12, weight: .medium))
                    .foregroundColor(DS.textTertiary)
            }
            .padding(.horizontal, DS.s20)
            .padding(.vertical, DS.s14)
        }
    }
}

// MARK: - MilestoneCell
private struct MilestoneCell: View {
    @EnvironmentObject var appVM: AppViewModel
    let badge: Badge

    var body: some View {
        VStack(spacing: DS.s8) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked
                          ? appVM.selectedTheme.primaryColor.opacity(0.15)
                          : Color.white.opacity(0.04))
                    .frame(width: 44, height: 44)
                Image(systemName: badge.icon)
                    .font(.app(size: 20))
                    .foregroundColor(badge.isUnlocked
                                     ? appVM.selectedTheme.primaryColor
                                     : DS.textTertiary)
            }
            Text(badge.localizedTitle)
                .font(.app(size: 9.5, weight: .medium, design: .rounded))
                .foregroundColor(badge.isUnlocked ? DS.textSecondary : DS.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.s12)
        .background(
            RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                .fill(badge.isUnlocked
                      ? appVM.selectedTheme.primaryColor.opacity(0.07)
                      : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                        .strokeBorder(
                            badge.isUnlocked
                            ? appVM.selectedTheme.primaryColor.opacity(0.25)
                            : DS.strokeSubtle,
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - ThemePickerView
struct ThemePickerView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: DS.s24) {
                HStack {
                    Text(L("theme.title"))
                        .font(.app(size: 20, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(DS.textTertiary)
                    }
                    .accessibilityLabel(L("common.close"))
                }
                .padding(.horizontal, DS.s24)
                .padding(.top, DS.s28)

                VStack(spacing: DS.s12) {
                    ForEach(AppColorTheme.allCases, id: \.self) { theme in
                        ThemeRow(theme: theme, isSelected: appVM.selectedTheme == theme) {
                            HapticManager.impact(.medium)
                            withAnimation(DS.springSmooth) {
                                appVM.selectedTheme = theme
                                appVM.save()
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.s24)

                Spacer()
            }
        }
    }
}

private struct ThemeRow: View {
    @EnvironmentObject var appVM: AppViewModel
    let theme: AppColorTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.s16) {
                ZStack {
                    Circle()
                        .fill(theme.gradient)
                        .frame(width: 40, height: 40)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.app(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Text(theme.name)
                    .font(.app(size: 15, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.primaryColor)
                        .font(.app(size: 18))
                }
            }
            .padding(DS.s16)
            .background(
                RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                    .fill(isSelected ? theme.primaryColor.opacity(0.12) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                            .strokeBorder(
                                isSelected ? theme.primaryColor.opacity(0.45) : DS.strokeSubtle,
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}

// MARK: - APIKeySheet
struct APIKeySheet: View {
    @EnvironmentObject var appVM: AppViewModel
    @Binding var apiKey: String
    @Binding var isPresented: Bool

    @State private var endpointInput: String = ""
    @State private var modelInput: String = ""

    private let presets: [(name: String, url: String, model: String)] = [
        ("Anthropic",  "https://api.anthropic.com/v1/messages",              "claude-sonnet-4-6"),
        ("OpenAI",     "https://api.openai.com/v1/chat/completions",         "gpt-4o"),
        ("Groq",       "https://api.groq.com/openai/v1/chat/completions",    "llama-3.3-70b-versatile"),
        ("DeepSeek",   "https://api.deepseek.com/v1/chat/completions",       "deepseek-chat"),
        ("Mistral",    "https://api.mistral.ai/v1/chat/completions",         "mistral-large-latest"),
        ("Ollama",     "http://localhost:11434/v1/chat/completions",          "llama3.2"),
    ]

    var body: some View {
        ZStack {
            appBG.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.s20) {
                    HStack {
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(DS.textTertiary)
                        }
                        .accessibilityLabel(L("common.close"))
                    }
                    .padding(.horizontal, DS.s24)
                    .padding(.top, DS.s28)

                    SerenityLogo(size: 48)

                    Text(L("profile.api_key"))
                        .font(.app(size: 22, weight: .bold))
                        .foregroundColor(DS.textPrimary)

                    // Quick presets
                    GlassCard {
                        VStack(alignment: .leading, spacing: DS.s10) {
                            Text(L("profile.presets"))
                                .font(.app(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(DS.textTertiary)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DS.s8) {
                                ForEach(presets, id: \.name) { p in
                                    Button(action: {
                                        endpointInput = p.url
                                        modelInput    = p.model
                                    }) {
                                        Text(p.name)
                                            .font(.app(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(endpointInput == p.url
                                                             ? appVM.selectedTheme.primaryColor
                                                             : DS.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, DS.s8)
                                            .background(
                                                Capsule()
                                                    .fill(endpointInput == p.url
                                                          ? appVM.selectedTheme.primaryColor.opacity(0.15)
                                                          : Color.white.opacity(0.06))
                                                    .overlay(Capsule().strokeBorder(
                                                        endpointInput == p.url
                                                            ? appVM.selectedTheme.primaryColor.opacity(0.4)
                                                            : DS.strokeSubtle,
                                                        lineWidth: 1))
                                            )
                                    }
                                }
                            }
                        }
                        .padding(DS.s16)
                    }
                    .padding(.horizontal, DS.s24)

                    // Fields
                    GlassCard {
                        VStack(alignment: .leading, spacing: DS.s14) {
                            apiField(label: "API Key", placeholder: "Paste your key...", text: $apiKey)
                            Divider().background(DS.strokeSubtle)
                            apiField(label: "Endpoint URL", placeholder: "https://...", text: $endpointInput)
                            Divider().background(DS.strokeSubtle)
                            apiField(label: "Model", placeholder: "e.g. gpt-4o, claude-sonnet-4-6", text: $modelInput)
                        }
                        .padding(DS.s16)
                    }
                    .padding(.horizontal, DS.s24)

                    PrimaryButton(title: L("common.save")) {
                        appVM.claudeAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        appVM.llmEndpoint  = endpointInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        appVM.llmModel     = modelInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        appVM.save()
                        isPresented = false
                    }
                    .padding(.horizontal, DS.s24)

                    Spacer(minLength: 40)
                }
            }
        }
        .onAppear {
            endpointInput = appVM.llmEndpoint
            modelInput    = appVM.llmModel
        }
    }

    private func apiField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DS.s6) {
            Text(label)
                .font(.app(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DS.textTertiary)
            TextField(placeholder, text: text)
                .font(.app(size: 13, design: .monospaced))
                .foregroundColor(DS.textPrimary)
                .tint(appVM.selectedTheme.primaryColor)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}
