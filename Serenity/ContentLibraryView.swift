import SwiftUI

// MARK: - LibraryView (#content — sounds + guided meditations)
struct LibraryView: View {
    @EnvironmentObject var appVM: AppViewModel
    @StateObject private var sound = SoundEngine()
    @State private var selected: Meditation?
    @State private var sleepMinutes = 0
    @State private var sleepTask: Task<Void, Never>?

    private let soundscapes: [SoundEngine.Sound] = [.rain, .ocean, .forest, .brown]
    private let columns = [GridItem(.flexible(), spacing: DS.s12), GridItem(.flexible(), spacing: DS.s12)]

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                SheetHeader(title: L("library.title"))
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.s20) {
                        SectionHeader(title: L("library.sounds"))
                        LazyVGrid(columns: columns, spacing: DS.s12) {
                            ForEach(soundscapes) { s in
                                SoundscapeCard(sound: s, isPlaying: sound.current == s) {
                                    sound.toggle(s); armSleep()
                                }
                            }
                        }
                        sleepTimerRow

                        SectionHeader(title: L("library.guided")).padding(.top, DS.s4)
                        VStack(spacing: DS.s12) {
                            ForEach(Meditation.all) { med in
                                MeditationRow(med: med) {
                                    sound.stop()
                                    selected = med
                                }
                            }
                        }
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, DS.s20)
                    .padding(.top, DS.s16)
                }
            }
        }
        .sheet(item: $selected) { med in
            MeditationPlayerView(meditation: med)
                .presentationDragIndicator(.visible)
        }
        .onDisappear { sound.stop(); sleepTask?.cancel() }
    }

    private var sleepTimerRow: some View {
        HStack(spacing: DS.s8) {
            Image(systemName: "moon.zzz.fill").font(.app(size: 12)).foregroundColor(DS.textTertiary)
            Text(L("library.sleeptimer")).font(.app(size: 12, weight: .medium, design: .rounded)).foregroundColor(DS.textTertiary)
            Spacer(minLength: 0)
            ForEach([0, 15, 30, 60], id: \.self) { m in
                Button(action: { HapticManager.impact(.light); sleepMinutes = m; armSleep() }) {
                    Text(m == 0 ? L("sound.off") : "\(m)\(L("library.min"))")
                        .font(.app(size: 12, weight: sleepMinutes == m ? .semibold : .regular, design: .rounded))
                        .foregroundColor(sleepMinutes == m ? DS.textPrimary : DS.textSecondary)
                        .padding(.horizontal, DS.s10).padding(.vertical, DS.s6)
                        .background(Capsule().fill(sleepMinutes == m
                            ? appVM.selectedTheme.primaryColor.opacity(0.22) : Color.white.opacity(0.06)))
                }
            }
        }
    }

    private func armSleep() {
        sleepTask?.cancel()
        guard sleepMinutes > 0, sound.current != .off else { return }
        let minutes = sleepMinutes
        sleepTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            sound.stop()
        }
    }
}

private struct SoundscapeCard: View {
    @EnvironmentObject var appVM: AppViewModel
    let sound: SoundEngine.Sound
    let isPlaying: Bool
    let action: () -> Void

    private var icon: String {
        switch sound {
        case .rain: return "cloud.rain.fill"
        case .ocean: return "water.waves"
        case .forest: return "tree.fill"
        default: return "waveform"
        }
    }

    var body: some View {
        Button(action: { HapticManager.impact(.light); action() }) {
            GlassCard {
                HStack(spacing: DS.s12) {
                    Image(systemName: isPlaying ? "speaker.wave.2.fill" : icon)
                        .font(.app(size: 18))
                        .foregroundColor(isPlaying ? appVM.selectedTheme.primaryColor : DS.textSecondary)
                    Text(L("sound.\(sound.rawValue)"))
                        .font(.app(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DS.s14).padding(.vertical, DS.s14)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.r20, style: .continuous)
                    .strokeBorder(isPlaying ? appVM.selectedTheme.primaryColor.opacity(0.45) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct MeditationRow: View {
    @EnvironmentObject var appVM: AppViewModel
    let med: Meditation
    let action: () -> Void

    var body: some View {
        Button(action: { HapticManager.impact(.light); action() }) {
            GlassCard {
                HStack(spacing: DS.s14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                            .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                            .frame(width: 46, height: 46)
                        Image(systemName: med.icon).font(.app(size: 20))
                            .foregroundStyle(appVM.selectedTheme.gradient)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L(med.titleKey))
                            .font(.app(size: 15, weight: .semibold)).foregroundColor(DS.textPrimary)
                        Text(L(med.subtitleKey))
                            .font(.app(size: 12, design: .rounded)).foregroundColor(DS.textTertiary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text("\(med.minutes) \(L("library.min"))")
                        .font(.app(size: 12, weight: .medium, design: .rounded)).foregroundColor(DS.textTertiary)
                }
                .padding(DS.s14)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - MeditationPlayerView (paced text + breathing + ambient sound)
struct MeditationPlayerView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    let meditation: Meditation

    @StateObject private var sound = SoundEngine()
    @State private var elapsed = 0
    @State private var breathe = false
    @State private var finished = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var steps: [String] { meditation.stepKeys.map { L($0) } }
    private var total: Int { meditation.minutes * 60 }
    private var perStep: Int { max(1, total / max(1, steps.count)) }
    private var stepIndex: Int { min(elapsed / perStep, steps.count - 1) }
    private var progress: Double { total == 0 ? 0 : min(1, Double(elapsed) / Double(total)) }

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                SheetHeader(title: L(meditation.titleKey))
                Spacer()
                ZStack {
                    Circle()
                        .fill(appVM.selectedTheme.primaryColor.opacity(0.18))
                        .frame(width: 200, height: 200)
                        .scaleEffect(breathe ? 1.08 : 0.82)
                        .blur(radius: 6)
                    Circle()
                        .stroke(appVM.selectedTheme.gradient, lineWidth: 2)
                        .frame(width: 170, height: 170)
                        .scaleEffect(breathe ? 1.08 : 0.82)
                }
                .frame(height: 220)

                Text(finished ? L("med.complete") : steps[stepIndex])
                    .font(.app(size: 19, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.s32)
                    .id(finished ? -1 : stepIndex)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: stepIndex)
                    .frame(minHeight: 90)

                Spacer()
                ProgressView(value: progress)
                    .tint(appVM.selectedTheme.primaryColor)
                    .padding(.horizontal, DS.s32)
                    .padding(.bottom, DS.s32)
            }
        }
        .onAppear {
            sound.toggle(meditation.sound)
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { breathe = true }
        }
        .onDisappear { sound.stop() }
        .onReceive(ticker) { _ in
            guard !finished else { return }
            let prev = stepIndex
            elapsed += 1
            if stepIndex != prev { HapticManager.impact(.soft) }
            if elapsed >= total {
                finished = true
                HapticManager.notification(.success)
                sound.stop()
            }
        }
    }
}
