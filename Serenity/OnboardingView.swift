import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var step = 0
    @State private var nameInput = ""
    @State private var selectedGoals: Set<String> = []
    @State private var notifGranted = false
    @State private var animateIn = false
    @State private var apiKeyInput = ""

    let goals = [
        L("onboarding.goal.stress"),
        L("onboarding.goal.sleep"),
        L("onboarding.goal.energy"),
        L("onboarding.goal.balance"),
        L("onboarding.goal.awareness"),
        L("onboarding.goal.mindfulness"),
        L("onboarding.goal.happiness")
    ]

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 56)
                    .padding(.bottom, DS.s32)

                Group {
                    if step == 0 { step0View }
                    else if step == 1 { step1View }
                    else if step == 2 { step2View }
                    else { step3View }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)

                Spacer()
            }
            .padding(.horizontal, DS.s24)
        }
        .opacity(animateIn ? 1 : 0)
        .scaleEffect(animateIn ? 1 : 0.96)
        .onAppear {
            withAnimation(DS.springSmooth) { animateIn = true }
        }
    }

    private var progressDots: some View {
        HStack(spacing: DS.s10) {
            ForEach(0 ..< 4, id: \.self) { i in
                Capsule()
                    .fill(i <= step
                          ? appVM.selectedTheme.primaryColor
                          : Color.white.opacity(0.15))
                    .frame(width: i == step ? 28 : 8, height: 8)
                    .animation(DS.springSnappy, value: step)
            }
        }
    }

    private var step0View: some View {
        VStack(spacing: DS.s28) {
            ZStack {
                Circle()
                    .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                    .frame(width: 96, height: 96)
                Image(systemName: "leaf.fill")
                    .font(.app(size: 44, weight: .light))
                    .foregroundStyle(appVM.selectedTheme.gradient)
            }

            VStack(spacing: DS.s12) {
                Text(L("onboarding.welcome.title"))
                    .font(.app(size: 28, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L("onboarding.welcome.subtitle"))
                    .font(.app(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: DS.s8) {
                    Text(L("onboarding.name.label"))
                        .font(.app(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                    TextField(L("onboarding.name.placeholder"), text: $nameInput)
                        .font(.app(size: 16, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                        .tint(appVM.selectedTheme.primaryColor)
                }
                .padding(DS.s20)
            }

            PrimaryButton(title: L("onboarding.next")) {
                guard !nameInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                appVM.userName = nameInput.trimmingCharacters(in: .whitespaces)
                withAnimation(DS.springSmooth) { step = 1 }
            }
        }
    }

    private var step1View: some View {
        VStack(spacing: DS.s24) {
            ZStack {
                Circle()
                    .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: "target")
                    .font(.app(size: 36, weight: .light))
                    .foregroundStyle(appVM.selectedTheme.gradient)
            }

            VStack(spacing: DS.s8) {
                Text(L("onboarding.goals.title"))
                    .font(.app(size: 24, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                Text(L("onboarding.goals.subtitle"))
                    .font(.app(size: 14, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }

            GoalGrid(goals: goals, selected: $selectedGoals)

            PrimaryButton(title: L("onboarding.next")) {
                appVM.userGoals = Array(selectedGoals)
                withAnimation(DS.springSmooth) { step = 2 }
            }

            SecondaryButton(title: L("onboarding.skip")) {
                withAnimation(DS.springSmooth) { step = 2 }
            }
        }
    }

    private var step2View: some View {
        VStack(spacing: DS.s28) {
            ZStack {
                Circle()
                    .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: "bell.badge.fill")
                    .font(.app(size: 36, weight: .light))
                    .foregroundStyle(appVM.selectedTheme.gradient)
            }

            VStack(spacing: DS.s8) {
                Text(L("onboarding.notifications.title"))
                    .font(.app(size: 24, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L("onboarding.notifications.subtitle"))
                    .font(.app(size: 14, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            notifFeatureList

            PrimaryButton(title: L("onboarding.allow_notifications")) {
                appVM.requestNotificationPermission { granted in
                    notifGranted = granted
                    if granted { appVM.scheduleStreakReminder() }
                    withAnimation(DS.springSmooth) { step = 3 }
                }
            }

            SecondaryButton(title: L("onboarding.skip")) {
                withAnimation(DS.springSmooth) { step = 3 }
            }
        }
    }

    private var step3View: some View {
        VStack(spacing: DS.s28) {
            ZStack {
                Circle()
                    .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: "sparkles")
                    .font(.app(size: 36, weight: .light))
                    .foregroundStyle(appVM.selectedTheme.gradient)
            }

            VStack(spacing: DS.s8) {
                Text(L("onboarding.api.title"))
                    .font(.app(size: 24, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L("onboarding.api.subtitle"))
                    .font(.app(size: 14, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: DS.s10) {
                    TextField(L("onboarding.api.placeholder"), text: $apiKeyInput)
                        .font(.app(size: 15, design: .monospaced))
                        .foregroundColor(DS.textPrimary)
                        .tint(appVM.selectedTheme.primaryColor)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Divider().background(DS.strokeSubtle)
                    HStack(spacing: DS.s6) {
                        Image(systemName: "info.circle")
                            .font(.app(size: 11))
                            .foregroundColor(DS.textTertiary)
                        Text(L("onboarding.api.hint"))
                            .font(.app(size: 11, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                    }
                }
                .padding(DS.s16)
            }

            PrimaryButton(title: L("onboarding.api.continue")) {
                let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    KeychainHelper.save(trimmed, forKey: StorageKey.claudeAPIKey)
                    appVM.claudeAPIKey = trimmed
                }
                finishOnboarding()
            }

            SecondaryButton(title: L("onboarding.api.skip")) {
                finishOnboarding()
            }
        }
    }

    private var notifFeatureList: some View {
        GlassCard {
            VStack(spacing: DS.s16) {
                notifRow(icon: "flame.fill",  color: Color(hex: "FBBF24"),  text: L("onboarding.notif.streak"))
                notifRow(icon: "sparkles",    color: appVM.selectedTheme.primaryColor, text: L("onboarding.notif.insights"))
                notifRow(icon: "heart.fill",  color: Color(hex: "F472B6"),  text: L("onboarding.notif.checkin"))
            }
            .padding(DS.s20)
        }
    }

    private func notifRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: DS.s14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.app(size: 12))
                    .foregroundColor(color)
            }
            Text(text)
                .font(.app(size: 14, design: .rounded))
                .foregroundColor(DS.textSecondary)
            Spacer()
        }
    }

    private func finishOnboarding() {
        appVM.isOnboardingComplete = true
        appVM.save()
    }
}

// MARK: - GoalGrid
private struct GoalGrid: View {
    @EnvironmentObject var appVM: AppViewModel
    let goals: [String]
    @Binding var selected: Set<String>

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.s12) {
            ForEach(goals, id: \.self) { goal in
                GoalChip(title: goal, isSelected: selected.contains(goal)) {
                    HapticManager.impact(.light)
                    if selected.contains(goal) {
                        selected.remove(goal)
                    } else {
                        selected.insert(goal)
                    }
                }
            }
        }
    }
}

private struct GoalChip: View {
    @EnvironmentObject var appVM: AppViewModel
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.app(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? DS.textPrimary : DS.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.s12)
                .background(
                    RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                        .fill(isSelected
                              ? appVM.selectedTheme.primaryColor.opacity(0.22)
                              : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                    ? appVM.selectedTheme.primaryColor.opacity(0.60)
                                    : DS.strokeSubtle,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(DS.springSnappy, value: isSelected)
    }
}
