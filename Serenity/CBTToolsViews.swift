import SwiftUI

// MARK: - ThoughtReframeView (#17 + #45)
/// Guided CBT reframe: name the anxious thought → spot the distortions →
/// let the AI offer a kinder, balanced perspective. Saved as a ThoughtRecord.
struct ThoughtReframeView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var step = 0
    @State private var thought = ""
    @State private var distortions: Set<String> = []
    @State private var isLoading = false
    @State private var reframe = ""
    @State private var hasSubmitted = false
    @State private var task: Task<Void, Never>?
    @FocusState private var thoughtFocused: Bool

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                SheetHeader(title: L("cbt.reframe.title"))
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s24) {
                        stepView.padding(.top, DS.s24)
                        buttons
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, DS.s24)
                }
            }
        }
        .onDisappear { task?.cancel() }
    }

    @ViewBuilder private var stepView: some View {
        switch step {
        case 0:  thoughtStep
        case 1:  distortionStep
        default: reframeStep
        }
    }

    private var thoughtStep: some View {
        VStack(spacing: DS.s16) {
            Text(L("cbt.reframe.thought.q"))
                .font(.app(size: 20, weight: .bold))
                .foregroundColor(DS.textPrimary)
                .multilineTextAlignment(.center)
            GlassCard {
                TextField(L("cbt.reframe.thought.placeholder"), text: $thought, axis: .vertical)
                    .lineLimit(3...8)
                    .font(.app(size: 16, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .tint(appVM.selectedTheme.primaryColor)
                    .focused($thoughtFocused)
                    .padding(DS.s16)
            }
        }
        .onAppear { thoughtFocused = true }
    }

    private var distortionStep: some View {
        VStack(spacing: DS.s16) {
            Text(L("cbt.reframe.distortion.q"))
                .font(.app(size: 20, weight: .bold))
                .foregroundColor(DS.textPrimary)
                .multilineTextAlignment(.center)
            Text(L("cbt.reframe.distortion.hint"))
                .font(.app(size: 13, design: .rounded))
                .foregroundColor(DS.textTertiary)
                .multilineTextAlignment(.center)
            VStack(spacing: DS.s10) {
                ForEach(CognitiveDistortion.all, id: \.self) { key in
                    distortionChip(key)
                }
            }
        }
    }

    private func distortionChip(_ key: String) -> some View {
        let isOn = distortions.contains(key)
        return Button(action: {
            HapticManager.impact(.light)
            if isOn { distortions.remove(key) } else { distortions.insert(key) }
        }) {
            HStack(spacing: DS.s12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.app(size: 18))
                    .foregroundColor(isOn ? appVM.selectedTheme.primaryColor : DS.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("distortion.\(key)"))
                        .font(.app(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                    Text(L("distortion.\(key).desc"))
                        .font(.app(size: 11, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(DS.s14)
            .background(
                RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                    .fill(isOn ? appVM.selectedTheme.primaryColor.opacity(0.12) : Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: DS.r16)
                        .strokeBorder(isOn ? appVM.selectedTheme.primaryColor.opacity(0.4) : DS.strokeSubtle, lineWidth: 1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var reframeStep: some View {
        Group {
            if isLoading {
                VStack(spacing: DS.s20) {
                    ProgressView().tint(appVM.selectedTheme.primaryColor).scaleEffect(1.4)
                    Text(L("cbt.reframe.loading"))
                        .font(.app(size: 15, design: .rounded)).foregroundColor(DS.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(DS.s40)
            } else {
                GlassCard {
                    VStack(alignment: .leading, spacing: DS.s14) {
                        HStack(spacing: DS.s10) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(appVM.selectedTheme.gradient)
                            Text(L("cbt.reframe.result.title"))
                                .font(.app(size: 17, weight: .semibold))
                                .foregroundColor(DS.textPrimary)
                        }
                        Text("\u{201C}\(thought)\u{201D}")
                            .font(.app(size: 14, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                            .italic()
                        Divider().background(DS.strokeSubtle)
                        TypewriterText(fullText: reframe, speed: 0.02)
                            .font(.app(size: 15, design: .rounded))
                            .foregroundColor(DS.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(DS.s20)
                }
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: DS.s12) {
            switch step {
            case 0:
                PrimaryButton(title: L("common.next")) {
                    thoughtFocused = false
                    withAnimation(DS.springSmooth) { step = 1 }
                }
                .disabled(thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            case 1:
                PrimaryButton(title: L("cbt.reframe.cta"), action: { generate() }, isLoading: isLoading)
                SecondaryButton(title: L("common.back")) { withAnimation(DS.springSmooth) { step = 0 } }
            default:
                PrimaryButton(title: L("common.done")) { dismiss() }
            }
        }
    }

    private func generate() {
        guard !hasSubmitted else { return }
        hasSubmitted = true
        isLoading = true
        withAnimation { step = 2 }

        let names = distortions.map { L("distortion.\($0)") }
        let prompt = """
        The user is reframing an anxious thought using CBT.
        Thought: "\(thought)"
        Patterns they noticed: \(names.isEmpty ? "—" : names.joined(separator: ", "))

        In the user's language, warmly help them see this thought from a kinder,
        more balanced and realistic perspective. 2–3 short sentences, practical and
        non-judgmental, ending with one balanced alternative thought they could tell
        themselves. Plain text only, no markdown.
        """
        let system = "You are a warm, CBT-informed wellness companion. You do not diagnose."
            + UserContext.systemPreamble(appVM.memorySummary)

        task = Task {
            let text: String
            do {
                text = try await appVM.fetchLLM(system: system, userPrompt: prompt, maxTokens: 280)
            } catch {
                text = L("cbt.reframe.fallback")
            }
            reframe = text.trimmingCharacters(in: .whitespacesAndNewlines)
            isLoading = false
            appVM.addThoughtRecord(ThoughtRecord(
                thought: thought, distortions: Array(distortions), reframe: reframe))
        }
    }
}

// MARK: - CopingPlanView (#47 "when it hits")
/// A personal, editable list of what helps when things get hard — ready to
/// reach for in the moment.
struct CopingPlanView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newItem = ""
    @FocusState private var inputFocused: Bool

    private let suggestions = ["breath", "call", "walk", "shower", "write", "music"]

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                SheetHeader(title: L("cbt.coping.title"))
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.s16) {
                        Text(L("cbt.coping.subtitle"))
                            .font(.app(size: 14, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(appVM.copingPlan) { item in
                            planRow(item)
                        }

                        if appVM.copingPlan.isEmpty {
                            suggestionsCard
                        }

                        addRow
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, DS.s20)
                    .padding(.top, DS.s16)
                }
            }
        }
    }

    private func planRow(_ item: CopingItem) -> some View {
        GlassCard {
            HStack(spacing: DS.s12) {
                Image(systemName: "heart.fill")
                    .font(.app(size: 13))
                    .foregroundColor(appVM.selectedTheme.primaryColor)
                Text(item.text)
                    .font(.app(size: 15, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                Spacer(minLength: 0)
                Button(action: {
                    HapticManager.impact(.light)
                    appVM.copingPlan.removeAll { $0.id == item.id }
                    appVM.saveCopingPlan()
                }) {
                    Image(systemName: "xmark")
                        .font(.app(size: 12, weight: .semibold))
                        .foregroundColor(DS.textTertiary)
                }
                .accessibilityLabel(L("common.delete"))
            }
            .padding(.horizontal, DS.s16)
            .padding(.vertical, DS.s12)
        }
    }

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: DS.s10) {
            Text(L("cbt.coping.suggestions"))
                .font(.app(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DS.textTertiary)
            ForEach(suggestions, id: \.self) { key in
                let text = L("cbt.coping.suggest.\(key)")
                Button(action: { add(text) }) {
                    HStack(spacing: DS.s10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(appVM.selectedTheme.primaryColor)
                        Text(text).font(.app(size: 14, design: .rounded)).foregroundColor(DS.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, DS.s6)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.vertical, DS.s4)
    }

    private var addRow: some View {
        HStack(spacing: DS.s10) {
            TextField(L("cbt.coping.placeholder"), text: $newItem)
                .font(.app(size: 15, design: .rounded))
                .foregroundColor(DS.textPrimary)
                .tint(appVM.selectedTheme.primaryColor)
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit { add(newItem) }
                .padding(.horizontal, DS.s14).padding(.vertical, DS.s12)
                .background(RoundedRectangle(cornerRadius: DS.r12).fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: DS.r12).strokeBorder(DS.strokeSubtle, lineWidth: 1)))
            Button(action: { add(newItem) }) {
                Image(systemName: "plus")
                    .font(.app(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(appVM.selectedTheme.primaryColor))
            }
            .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        HapticManager.impact(.light)
        appVM.copingPlan.append(CopingItem(text: trimmed))
        appVM.saveCopingPlan()
        newItem = ""
    }
}
