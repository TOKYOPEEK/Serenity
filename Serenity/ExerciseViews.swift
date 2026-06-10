import SwiftUI

// MARK: - SOSView
struct SOSView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentStep = 0
    @State private var completed   = false

    private let steps: [SOSStep] = [
        SOSStep(icon: "eye.fill",         title: L("sos.step.1.title"), instruction: L("sos.step.1.instruction"), color: Color(hex: "60A5FA")),
        SOSStep(icon: "hand.raised.fill", title: L("sos.step.2.title"), instruction: L("sos.step.2.instruction"), color: Color(hex: "A78BFA")),
        SOSStep(icon: "ear.fill",         title: L("sos.step.3.title"), instruction: L("sos.step.3.instruction"), color: Color(hex: "22D3EE")),
        SOSStep(icon: "nose.fill",        title: L("sos.step.4.title"), instruction: L("sos.step.4.instruction"), color: Color(hex: "34D399")),
        SOSStep(icon: "mouth.fill",       title: L("sos.step.5.title"), instruction: L("sos.step.5.instruction"), color: Color(hex: "FBBF24"))
    ]

    var body: some View {
        ZStack {
            appBG.ignoresSafeArea()
            // Subtle tinted orb matching current step
            Circle()
                .fill(
                    RadialGradient(
                        colors: [steps[safe: currentStep]?.color.opacity(0.14) ?? .clear, .clear],
                        center: .center, startRadius: 0, endRadius: 280
                    )
                )
                .frame(width: 560, height: 560)
                .ignoresSafeArea()
                .animation(reduceMotion ? .none : DS.springGentle, value: currentStep)

            Group {
                if completed { completedView } else { mainContent }
            }
        }
    }

    // MARK: Main content
    private var mainContent: some View {
        VStack(spacing: 0) {
            sosHeader
            progressBar
            Spacer()
            stepContent
            Spacer()
            actionButtons
                .padding(.horizontal, DS.s24)
                .padding(.bottom, DS.s40)
        }
    }

    private var sosHeader: some View {
        SheetHeader(title: L("sos.title"))
    }

    private var progressBar: some View {
        HStack(spacing: DS.s6) {
            ForEach(0 ..< steps.count, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep
                          ? (steps[safe: i]?.color ?? DS.textSecondary)
                          : Color.white.opacity(0.12))
                    .frame(height: 3)
            }
        }
        .animation(DS.springSmooth, value: currentStep)
        .padding(.horizontal, DS.s24)
        .padding(.bottom, DS.s8)
    }

    private var stepContent: some View {
        SOSStepContent(step: steps[currentStep], index: currentStep, total: steps.count)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            ))
            .id(currentStep)
    }

    private var actionButtons: some View {
        VStack(spacing: DS.s12) {
            PrimaryButton(
                title: currentStep < steps.count - 1 ? L("common.next") : L("sos.complete")
            ) {
                HapticManager.impact(.medium)
                if currentStep < steps.count - 1 {
                    withAnimation(DS.springSmooth) { currentStep += 1 }
                } else {
                    withAnimation(DS.springSmooth) { completed = true }
                    appVM.markSOSUsed()
                }
            }

            if currentStep > 0 {
                SecondaryButton(title: L("common.back")) {
                    withAnimation(DS.springSmooth) { currentStep -= 1 }
                }
            }
        }
    }

    // MARK: Completed
    private var completedView: some View {
        VStack(spacing: DS.s28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(hex: "34D399").opacity(0.15))
                    .frame(width: 110, height: 110)
                Image(systemName: "checkmark.circle.fill")
                    .font(.app(size: 60))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "34D399"), Color(hex: "22D3EE")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            VStack(spacing: DS.s12) {
                Text(L("sos.completed.title"))
                    .font(.app(size: 24, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                Text(L("sos.completed.subtitle"))
                    .font(.app(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, DS.s32)
            }
            PrimaryButton(title: L("common.done")) { dismiss() }
                .padding(.horizontal, DS.s40)
            Spacer()
        }
    }
}

// MARK: - SOSStepContent
private struct SOSStepContent: View {
    @EnvironmentObject var appVM: AppViewModel
    let step: SOSStep
    let index: Int
    let total: Int

    var body: some View {
        VStack(spacing: DS.s32) {
            ZStack {
                Circle()
                    .fill(step.color.opacity(0.12))
                    .frame(width: 110, height: 110)
                Circle()
                    .strokeBorder(step.color.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 110, height: 110)
                Image(systemName: step.icon)
                    .font(.app(size: 42, weight: .light))
                    .foregroundColor(step.color)
            }

            VStack(spacing: DS.s12) {
                Text(String(format: L("sos.step_label"), index + 1, total))
                    .font(.app(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                    .padding(.horizontal, DS.s12)
                    .padding(.vertical, DS.s4)
                    .background(
                        Capsule().fill(Color.white.opacity(0.05))
                    )

                Text(step.title)
                    .font(.app(size: 22, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)

                Text(step.instruction)
                    .font(.app(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, DS.s16)
            }
        }
        .padding(.horizontal, DS.s24)
    }
}

private struct SOSStep {
    let icon: String
    let title: String
    let instruction: String
    let color: Color
}

// MARK: - ExerciseDetailView
struct ExerciseDetailView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var breathVM = BreathingViewModel()
    @State private var ringProgress: CGFloat = 0

    let exerciseId: String

    private var exercise: BreathingExerciseModel {
        BreathingExerciseModel.allExercises.first { $0.id == exerciseId }
            ?? BreathingExerciseModel.allExercises[0]
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                exerciseHeader
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s32) {
                        breathCircle
                        phaseInfoCard
                        cycleControls
                        exercisePicker
                        startButton
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, DS.s24)
                    .padding(.top, DS.s24)
                }
            }
        }
        .onDisappear { breathVM.stop() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            breathVM.stop()
        }
    }

    private var exerciseHeader: some View {
        SheetHeader(title: breathVM.currentExercise.name)
    }

    private var breathCircle: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 10)
                .frame(width: 200, height: 200)

            // Progress arc — animated by the system over the whole phase duration
            Circle()
                .trim(from: 0, to: breathVM.isRunning ? ringProgress : 0)
                .stroke(
                    appVM.selectedTheme.gradient,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))

            // Glow ring
            if breathVM.isRunning {
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        appVM.selectedTheme.primaryColor.opacity(0.20),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 8)
            }

            VStack(spacing: DS.s8) {
                if breathVM.isRunning {
                    Text(breathVM.phaseLabel)
                        .font(.app(size: 18, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                    Text("\(breathVM.currentCycle + 1) / \(breathVM.totalCycles)")
                        .font(.app(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                } else {
                    Image(systemName: breathVM.currentExercise.icon)
                        .font(.app(size: 40, weight: .light))
                        .foregroundStyle(appVM.selectedTheme.gradient)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: breathVM.phaseLabel)
        }
        .onChange(of: breathVM.phaseId) { _ in
            guard breathVM.isRunning else { return }
            ringProgress = 0  // jump back without animation
            withAnimation(.linear(duration: breathVM.phaseDuration)) {
                ringProgress = 1  // single animation for the whole phase
            }
        }
        .onChange(of: breathVM.isRunning) { running in
            if !running { ringProgress = 0 }
        }
    }

    private var phaseInfoCard: some View {
        GlassCard {
            HStack(spacing: 0) {
                let ex = breathVM.currentExercise
                ForEach(0 ..< ex.phases.count, id: \.self) { i in
                    VStack(spacing: DS.s4) {
                        Text("\(ex.phases[i].duration)s")
                            .font(.app(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(appVM.selectedTheme.gradient)
                        Text(ex.phases[i].name)
                            .font(.app(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                    }
                    .frame(maxWidth: .infinity)

                    if i < ex.phases.count - 1 {
                        Divider()
                            .background(DS.strokeSubtle)
                            .frame(height: 30)
                    }
                }
            }
            .padding(DS.s16)
        }
    }

    private var cycleControls: some View {
        HStack(spacing: DS.s20) {
            Text(L("breathing.cycles") + ": \(breathVM.totalCycles)")
                .font(.app(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(DS.textSecondary)
            Stepper("", value: $breathVM.totalCycles, in: 1...10)
                .labelsHidden()
                .tint(appVM.selectedTheme.primaryColor)
                .disabled(breathVM.isRunning)
        }
    }

    private var exercisePicker: some View {
        GlassCard {
            VStack(spacing: DS.s12) {
                Text(L("breathing.choose_exercise"))
                    .font(.app(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: DS.s8) {
                    ForEach(BreathingExerciseModel.allExercises) { ex in
                        ExerciseChip(
                            name: ex.name,
                            isSelected: breathVM.selectedExerciseId == ex.id
                        ) {
                            breathVM.stop()
                            breathVM.selectedExerciseId = ex.id
                        }
                    }
                }
            }
            .padding(DS.s16)
        }
    }

    private var startButton: some View {
        Group {
            if breathVM.isRunning {
                SecondaryButton(title: L("breathing.stop")) { breathVM.stop() }
            } else {
                PrimaryButton(title: L("breathing.start")) {
                    HapticManager.impact(.medium)
                    breathVM.start()
                }
            }
        }
    }
}

// MARK: - ExerciseChip
private struct ExerciseChip: View {
    @EnvironmentObject var appVM: AppViewModel
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.app(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? .white : DS.textSecondary)
                .padding(.horizontal, DS.s12)
                .padding(.vertical, DS.s8)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? appVM.selectedTheme.primaryColor.opacity(0.28)
                              : Color.white.opacity(0.07))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected
                                    ? appVM.selectedTheme.primaryColor.opacity(0.5)
                                    : DS.strokeSubtle,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .animation(DS.springSnappy, value: isSelected)
    }
}
