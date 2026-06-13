import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var step = 0
    @State private var nameInput = ""
    @State private var selectedGoals: Set<String> = []
    @State private var notifGranted = false
    @State private var animateIn = false

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
                    else if step == 2 { featuresView }
                    else { step2View }
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
                    finishOnboarding()
                }
            }

            SecondaryButton(title: L("onboarding.skip")) {
                finishOnboarding()
            }
        }
    }

    // MARK: - Features showcase
    private var featuresView: some View {
        VStack(spacing: DS.s24) {
            VStack(spacing: DS.s8) {
                Text(L("onboarding.features.title"))
                    .font(.app(size: 24, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L("onboarding.features.subtitle"))
                    .font(.app(size: 14, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DS.s12) {
                featureRow("brain.head.profile", "onboarding.feature.ai")
                featureRow("face.smiling", "onboarding.feature.mood")
                featureRow("headphones", "onboarding.feature.library")
                featureRow("arrow.triangle.2.circlepath", "onboarding.feature.tools")
                featureRow("chart.xyaxis.line", "onboarding.feature.insights")
            }

            PrimaryButton(title: L("common.next")) {
                withAnimation(DS.springSmooth) { step = 3 }
            }
        }
    }

    private func featureRow(_ icon: String, _ key: String) -> some View {
        GlassCard {
            HStack(spacing: DS.s14) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.r12, style: .continuous)
                        .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.app(size: 17))
                        .foregroundStyle(appVM.selectedTheme.gradient)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("\(key).title"))
                        .font(.app(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                    Text(L("\(key).sub"))
                        .font(.app(size: 12, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.s14)
            .padding(.vertical, DS.s12)
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
