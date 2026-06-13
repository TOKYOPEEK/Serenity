import SwiftUI

// MARK: - FocusView (#34 — Pomodoro + ambient sound)
/// A focus timer with work/break cycles and optional generated ambient noise.
struct FocusView: View {
    @EnvironmentObject var appVM: AppViewModel
    @StateObject private var sound = SoundEngine()

    private let focusLength = 25 * 60
    private let breakLength = 5 * 60

    @State private var isBreak = false
    @State private var remaining = 25 * 60
    @State private var running = false
    @State private var completedFocus = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var total: Int { isBreak ? breakLength : focusLength }
    private var progress: Double { total == 0 ? 0 : 1 - Double(remaining) / Double(total) }

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                SheetHeader(title: L("focus.title"))
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s28) {
                        timerRing.padding(.top, DS.s24)
                        controls
                        soundPicker
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, DS.s24)
                    .padding(.top, DS.s16)
                }
            }
        }
        .onReceive(ticker) { _ in tick() }
        .onDisappear { sound.stop() }
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(appVM.selectedTheme.gradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)
            VStack(spacing: DS.s6) {
                Text(timeString)
                    .font(.app(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .monospacedDigit()
                Text(isBreak ? L("focus.break") : L("focus.focus"))
                    .font(.app(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                if completedFocus > 0 {
                    Text(String(format: L("focus.sessions"), completedFocus))
                        .font(.app(size: 11, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                }
            }
        }
        .frame(width: 240, height: 240)
    }

    private var controls: some View {
        HStack(spacing: DS.s16) {
            Button(action: reset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.app(size: 18, weight: .medium))
                    .foregroundColor(DS.textSecondary)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .accessibilityLabel(L("focus.reset"))

            Button(action: toggleRun) {
                Image(systemName: running ? "pause.fill" : "play.fill")
                    .font(.app(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(appVM.selectedTheme.gradient))
            }
            .accessibilityLabel(running ? L("focus.pause") : L("focus.start"))

            Button(action: skip) {
                Image(systemName: "forward.fill")
                    .font(.app(size: 18, weight: .medium))
                    .foregroundColor(DS.textSecondary)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .accessibilityLabel(L("focus.skip"))
        }
    }

    private var soundPicker: some View {
        VStack(spacing: DS.s10) {
            Text(L("focus.sound"))
                .font(.app(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(DS.textTertiary)
            HStack(spacing: DS.s8) {
                ForEach(SoundEngine.Sound.allCases) { option in
                    soundChip(option)
                }
            }
        }
    }

    private func soundChip(_ option: SoundEngine.Sound) -> some View {
        let isOn = sound.current == option
        return Button(action: { HapticManager.impact(.light); sound.toggle(option) }) {
            Text(L("sound.\(option.rawValue)"))
                .font(.app(size: 13, weight: isOn ? .semibold : .regular, design: .rounded))
                .foregroundColor(isOn ? DS.textPrimary : DS.textSecondary)
                .padding(.horizontal, DS.s14).padding(.vertical, DS.s8)
                .background(Capsule()
                    .fill(isOn ? appVM.selectedTheme.primaryColor.opacity(0.22) : Color.white.opacity(0.06))
                    .overlay(Capsule().strokeBorder(
                        isOn ? appVM.selectedTheme.primaryColor.opacity(0.55) : DS.strokeSubtle, lineWidth: 1)))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var timeString: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    // MARK: Logic

    private func tick() {
        guard running else { return }
        if remaining > 0 {
            remaining -= 1
        } else {
            advancePhase(auto: true)
        }
    }

    private func toggleRun() {
        HapticManager.impact(.medium)
        running.toggle()
    }

    private func reset() {
        HapticManager.impact(.light)
        running = false
        isBreak = false
        remaining = focusLength
    }

    private func skip() {
        HapticManager.impact(.light)
        advancePhase(auto: false)
    }

    private func advancePhase(auto: Bool) {
        if !isBreak {
            if auto { completedFocus += 1 }
            isBreak = true
            remaining = breakLength
        } else {
            isBreak = false
            remaining = focusLength
        }
        if auto { HapticManager.notification(.success) }
    }
}
