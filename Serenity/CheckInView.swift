import SwiftUI

// MARK: - CheckInView
struct CheckInView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var moodIndex:     Int    = 2
    @State private var energyLevel:   Double = 0.5
    @State private var stressLevel:   Double = 0.5
    @State private var selectedEmotions: Set<String> = []
    @State private var selectedTags:  Set<String> = []
    @State private var note:          String = ""
    @State private var isLoading      = false
    @State private var insight:       AIInsight?
    @State private var step           = 0
    @State private var hasSubmitted   = false
    @State private var insightTask:   Task<Void, Never>?

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                checkInHeader
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s24) {
                        stepView
                            .padding(.top, DS.s24)
                        navigationButtons
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, DS.s24)
                }
            }
        }
        .onDisappear { insightTask?.cancel() }
    }

    private var checkInHeader: some View {
        SheetHeader(title: L("checkin.title")) {
            StepIndicator(current: step, total: 3)
        }
    }

    @ViewBuilder
    private var stepView: some View {
        if step == 0 { moodStep }
        else if step == 1 { energyStressStep }
        else if step == 2 { tagsNoteStep }
        else { insightStep }
    }

    private var moodStep: some View {
        VStack(spacing: DS.s24) {
            Text(L("checkin.mood.question"))
                .font(.app(size: 22, weight: .bold))
                .foregroundColor(DS.textPrimary)
                .multilineTextAlignment(.center)
            MoodOrbPicker(selected: $moodIndex)
                .onChange(of: moodIndex) { _ in selectedEmotions.removeAll() }

            VStack(spacing: DS.s12) {
                Text(L("checkin.emotion.question"))
                    .font(.app(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                EmotionPicker(moodIndex: moodIndex, selected: $selectedEmotions)
            }
        }
    }

    private var energyStressStep: some View {
        VStack(spacing: DS.s20) {
            Text(L("checkin.energy_stress.question"))
                .font(.app(size: 20, weight: .bold))
                .foregroundColor(DS.textPrimary)
                .multilineTextAlignment(.center)

            MoodPad(energy: $energyLevel, stress: $stressLevel)
                .padding(.horizontal, DS.s4)

            Text(L("moodpad.hint"))
                .font(.app(size: 12, design: .rounded))
                .foregroundColor(DS.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var tagsNoteStep: some View {
        VStack(spacing: DS.s20) {
            Text(L("checkin.tags.question"))
                .font(.app(size: 20, weight: .bold))
                .foregroundColor(DS.textPrimary)
                .multilineTextAlignment(.center)
            TagPicker(selected: $selectedTags)
            GlassCard {
                TextField(L("checkin.note.placeholder"), text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.app(size: 15, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .tint(appVM.selectedTheme.primaryColor)
                    .padding(DS.s16)
            }
        }
    }

    private var insightStep: some View {
        Group {
            if isLoading {
                loadingView
            } else if let insight = insight {
                InsightCard(insight: insight)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: DS.s24) {
            SparkLoader(size: 68)
            Text(L("checkin.ai.loading"))
                .font(.app(size: 15, design: .rounded))
                .foregroundColor(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.s40)
    }

    private var navigationButtons: some View {
        VStack(spacing: DS.s12) {
            if step < 2 {
                PrimaryButton(title: L("common.next")) {
                    withAnimation(DS.springSmooth) { step += 1 }
                }
            } else if step == 2 {
                PrimaryButton(title: L("checkin.get_insight"), action: {
                    saveAndFetchInsight()
                }, isLoading: isLoading)
            } else {
                PrimaryButton(title: L("common.done")) {
                    dismiss()
                }
            }

            if step > 0 && step < 3 {
                SecondaryButton(title: L("common.back")) {
                    withAnimation(DS.springSmooth) { step -= 1 }
                }
            }
        }
    }

    private func saveAndFetchInsight() {
        guard !hasSubmitted else { return }
        hasSubmitted = true

        var entry = MoodEntry(
            moodIndex:   moodIndex,
            energyLevel: energyLevel,
            stressLevel: stressLevel,
            tags:        Array(selectedTags),
            note:        note,
            emotions:    Array(selectedEmotions)
        )

        isLoading = true
        withAnimation { step = 3 }

        insightTask = Task {
            let ai: AIInsight
            do {
                ai = try await fetchMoodInsight(entry: entry, appVM: appVM)
            } catch {
                // Offline or API error — the check-in is still saved, with a local insight
                ai = fallbackInsights.randomElement() ?? fallbackInsights[0]
            }
            entry.aiInsight = ai
            insight   = ai
            isLoading = false
            appVM.addMoodEntry(entry)
        }
    }
}

// MARK: - StepIndicator
private struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        Text("\(min(current + 1, total + 1))/\(total + 1)")
            .font(.app(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(DS.textTertiary)
    }
}

// MARK: - MoodOrbPicker
private struct MoodOrbPicker: View {
    @EnvironmentObject var appVM: AppViewModel
    @Binding var selected: Int

    private let labels = ["mood.veryBad", "mood.bad", "mood.neutral", "mood.good", "mood.great"]

    var body: some View {
        GlassCard {
            VStack(spacing: DS.s16) {
                HStack(spacing: DS.s12) {
                    ForEach(0 ..< 5, id: \.self) { i in
                        Button(action: {
                            HapticManager.impact(.light)
                            withAnimation(DS.springSnappy) { selected = i }
                        }) {
                            VStack(spacing: DS.s8) {
                                MoodOrbView(moodIndex: i, size: selected == i ? 48 : 38, isSelected: selected == i)
                                Text(L(labels[i]))
                                    .font(.app(size: 9, weight: selected == i ? .semibold : .regular, design: .rounded))
                                    .foregroundColor(selected == i ? DS.textPrimary : DS.textTertiary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .animation(DS.springSnappy, value: selected)
                    }
                }
            }
            .padding(DS.s16)
        }
    }
}

// MARK: - MoodPad (2D energy × stress field)
/// One tactile gesture sets both energy (vertical) and stress (horizontal),
/// replacing two separate sliders.
private struct MoodPad: View {
    @EnvironmentObject var appVM: AppViewModel
    @Binding var energy: Double   // 0 = low (bottom) … 1 = high (top)
    @Binding var stress: Double    // 0 = calm (left) … 1 = tense (right)

    var body: some View {
        GeometryReader { geo in
            let side = geo.size.width
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: "6D5DD3").opacity(0.85),
                                 appVM.selectedTheme.primaryColor.opacity(0.5),
                                 Color(hex: "E0856B").opacity(0.8)],
                        startPoint: .bottomLeading, endPoint: .topTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))

                Path { p in
                    p.move(to: CGPoint(x: side / 2, y: 8)); p.addLine(to: CGPoint(x: side / 2, y: side - 8))
                    p.move(to: CGPoint(x: 8, y: side / 2)); p.addLine(to: CGPoint(x: side - 8, y: side / 2))
                }.stroke(Color.white.opacity(0.10), lineWidth: 1)

                cornerLabels

                handle.position(x: stress * side, y: (1 - energy) * side)
            }
            .frame(width: side, height: side)
            .contentShape(RoundedRectangle(cornerRadius: 26))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    stress = min(1, max(0, Double(v.location.x / side)))
                    energy = min(1, max(0, 1 - Double(v.location.y / side)))
                }
                .onEnded { _ in HapticManager.impact(.light) })
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var cornerLabels: some View {
        VStack {
            HStack {
                Text(L("moodpad.flow")); Spacer(); Text(L("moodpad.tense"))
            }
            Spacer()
            HStack {
                Text(L("moodpad.calm")); Spacer(); Text(L("moodpad.drained"))
            }
        }
        .font(.app(size: 11, weight: .medium, design: .rounded))
        .foregroundColor(.white.opacity(0.75))
        .padding(DS.s16)
    }

    private var handle: some View {
        ZStack {
            Circle().fill(appVM.selectedTheme.primaryColor.opacity(0.45))
                .frame(width: 52, height: 52).blur(radius: 8)
            Circle().fill(Color.white).frame(width: 26, height: 26)
            Circle().strokeBorder(appVM.selectedTheme.primaryColor, lineWidth: 2)
                .frame(width: 26, height: 26)
        }
    }
}

// MARK: - EmotionPicker (emotion wheel)
private struct EmotionPicker: View {
    let moodIndex: Int
    @Binding var selected: Set<String>

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.s10) {
            ForEach(EmotionWheel.options(for: moodIndex), id: \.self) { emotion in
                TagChip(
                    title: L("emotion.\(emotion)"),
                    isSelected: selected.contains(emotion)
                ) {
                    HapticManager.impact(.light)
                    if selected.contains(emotion) {
                        selected.remove(emotion)
                    } else {
                        selected.insert(emotion)
                    }
                }
            }
        }
    }
}

// MARK: - TagPicker
private struct TagPicker: View {
    @EnvironmentObject var appVM: AppViewModel
    @Binding var selected: Set<String>

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.s10) {
            ForEach(allMoodTags, id: \.self) { tag in
                TagChip(
                    title: L("tag.\(tag)"),
                    isSelected: selected.contains(tag)
                ) {
                    HapticManager.impact(.light)
                    if selected.contains(tag) {
                        selected.remove(tag)
                    } else {
                        selected.insert(tag)
                    }
                }
            }
        }
    }
}

// MARK: - TagChip
private struct TagChip: View {
    @EnvironmentObject var appVM: AppViewModel
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.app(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? DS.textPrimary : DS.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, DS.s10)
                .padding(.vertical, DS.s8)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? appVM.selectedTheme.primaryColor.opacity(0.22)
                              : Color.white.opacity(0.06))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected
                                    ? appVM.selectedTheme.primaryColor.opacity(0.55)
                                    : DS.strokeSubtle,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(DS.springSnappy, value: isSelected)
    }
}

// MARK: - InsightCard
private struct InsightCard: View {
    @EnvironmentObject var appVM: AppViewModel
    let insight: AIInsight

    var body: some View {
        GlassCard {
            VStack(spacing: DS.s16) {
                ZStack {
                    Circle()
                        .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Text(insight.emoji)
                        .font(.app(size: 32))
                }

                Text(insight.title)
                    .font(.app(size: 20, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)

                TypewriterText(fullText: insight.body, speed: 0.025)
                    .font(.app(size: 15, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Divider().background(DS.strokeSubtle)

                HStack(alignment: .top, spacing: DS.s10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(appVM.selectedTheme.gradient)
                        .font(.app(size: 14))
                    Text(insight.tip)
                        .font(.app(size: 14, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DS.s24)
        }
    }
}

// MARK: - Mood Insight fetch (uses shared AppViewModel LLM client)
@MainActor
private func fetchMoodInsight(entry: MoodEntry, appVM: AppViewModel) async throws -> AIInsight {
    let prompt = """
    User mood check-in:
    - Mood: \(entry.moodEmoji) \(entry.moodName)
    - Feelings: \(entry.emotionNames.joined(separator: ", "))
    - Energy: \(Int(entry.energyLevel * 100))%
    - Stress: \(Int(entry.stressLevel * 100))%
    - Tags: \(entry.tags.joined(separator: ", "))
    - Note: \(entry.note)

    Respond ONLY with valid JSON (no markdown):
    {"emoji":"...","title":"...","body":"...","tip":"...","tone":"..."}
    """
    let system = "You are a compassionate wellness AI. Respond only with the requested JSON."
        + UserContext.systemPreamble(appVM.memorySummary)
    let text = try await appVM.fetchLLM(
        system: system,
        userPrompt: prompt,
        maxTokens: 300
    )
    // Models don't always obey "JSON only"; parse defensively (see AIInsight.parse).
    guard let insight = AIInsight.parse(from: text) else {
        throw LLMError.emptyResponse
    }
    return insight
}
