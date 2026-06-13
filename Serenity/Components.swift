import SwiftUI

// MARK: - Scaled font (Dynamic Type)
extension Font {
    /// System font that scales with the user's Dynamic Type setting,
    /// capped at 1.6× so fixed layouts degrade gracefully at huge sizes.
    static func app(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let scaled = min(UIFontMetrics(forTextStyle: .body).scaledValue(for: size), size * 1.6)
        return Font.system(size: scaled, weight: weight, design: design)
    }
}

// MARK: - Design Tokens

let appBG = Color(hex: "080D18")  // deep navy-blue-black

enum DS {
    // Spacing
    static let s2:  CGFloat = 2
    static let s4:  CGFloat = 4
    static let s6:  CGFloat = 6
    static let s8:  CGFloat = 8
    static let s10: CGFloat = 10
    static let s12: CGFloat = 12
    static let s14: CGFloat = 14
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s28: CGFloat = 28
    static let s32: CGFloat = 32
    static let s40: CGFloat = 40

    // Radius
    static let r12: CGFloat = 12
    static let r16: CGFloat = 16
    static let r20: CGFloat = 20
    static let r24: CGFloat = 24
    static let r32: CGFloat = 32

    // Text colors
    static let textPrimary   = Color(hex: "EDE9F8")   // soft white, slight lavender
    static let textSecondary = Color(hex: "8C84A8")   // muted lavender-gray
    static let textTertiary  = Color(hex: "7A7299")   // muted violet — ≥4.5:1 contrast on appBG (WCAG AA)

    // Stroke
    static let strokeSubtle = Color.white.opacity(0.08)
    static let strokeMedium = Color.white.opacity(0.15)

    // Mood palette (index 0–4: awful → great)
    static let moodColors: [Color] = [
        Color(hex: "6B7280"),
        Color(hex: "818CF8"),
        Color(hex: "A5B4FC"),
        Color(hex: "34D399"),
        Color(hex: "FCD34D")
    ]
    static func moodColor(_ index: Int) -> Color {
        moodColors[safe: index] ?? .white
    }

    // Motion
    static let springSnappy = Animation.spring(response: 0.30, dampingFraction: 0.70)
    static let springSmooth = Animation.spring(response: 0.45, dampingFraction: 0.78)
    static let springGentle = Animation.spring(response: 0.60, dampingFraction: 0.82)
}

// MARK: - Glass Level
enum GlassLevel { case subtle, card, floating, modal }

// MARK: - AmbientBackground
struct AmbientBackground: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var phase: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            appBG.ignoresSafeArea()
            if !reduceMotion { orbLayer }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }

    private var orbLayer: some View {
        ZStack {
            // Top-left primary orb
            Circle()
                .fill(RadialGradient(
                    colors: [appVM.selectedTheme.primaryColor.opacity(0.20), .clear],
                    center: .center, startRadius: 0, endRadius: 170
                ))
                .frame(width: 340, height: 340)
                .offset(
                    x: -100 + CGFloat(sin(phase * 0.55)) * 16,
                    y: -230 + CGFloat(cos(phase * 0.40)) * 22
                )

            // Bottom-right secondary orb
            Circle()
                .fill(RadialGradient(
                    colors: [appVM.selectedTheme.secondaryColor.opacity(0.14), .clear],
                    center: .center, startRadius: 0, endRadius: 140
                ))
                .frame(width: 280, height: 280)
                .offset(
                    x: 130 + CGFloat(cos(phase * 0.65)) * 18,
                    y: 200 + CGFloat(sin(phase * 0.50)) * 16
                )

            // Center-bottom accent orb
            Circle()
                .fill(RadialGradient(
                    colors: [appVM.selectedTheme.orbColor.opacity(0.10), .clear],
                    center: .center, startRadius: 0, endRadius: 110
                ))
                .frame(width: 220, height: 220)
                .offset(
                    x: -20 + CGFloat(sin(phase * 0.75)) * 12,
                    y: 350 + CGFloat(cos(phase * 0.60)) * 18
                )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - GlassCard
struct GlassCard<Content: View>: View {
    let level: GlassLevel
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        level: GlassLevel = .card,
        cornerRadius: CGFloat = DS.r20,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.level = level
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .background(background)
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch level {
        case .subtle:
            shape
                .fill(Color.white.opacity(0.05))
                .overlay(shape.strokeBorder(DS.strokeSubtle, lineWidth: 1))

        case .card:
            ZStack {
                shape.fill(.thinMaterial)
                shape.fill(LinearGradient(
                    colors: [Color.white.opacity(0.055), Color.clear],
                    startPoint: .top, endPoint: .bottom
                ))
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }

        case .floating:
            ZStack {
                shape.fill(.regularMaterial)
                shape.fill(LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    startPoint: .top, endPoint: .center
                ))
                shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.40), radius: 28, x: 0, y: 10)

        case .modal:
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    startPoint: .top, endPoint: .center
                ))
                shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            }
        }
    }
}

// MARK: - GradientText
struct GradientText: View {
    @EnvironmentObject var appVM: AppViewModel
    let text: String
    let font: Font

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(appVM.selectedTheme.gradient)
    }
}

// MARK: - SectionHeader
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.app(size: 18, weight: .semibold))
            .foregroundColor(DS.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - SheetHeader
/// Standard modal header: close button, centered title, optional trailing accessory.
struct SheetHeader<Trailing: View>: View {
    private let title: String
    private let onClose: (() -> Void)?
    private let trailing: Trailing
    @Environment(\.dismiss) private var dismiss

    /// `onClose` replaces the default dismiss, e.g. to confirm discarding edits.
    init(title: String,
         onClose: (() -> Void)? = nil,
         @ViewBuilder trailing: () -> Trailing) {
        self.title    = title
        self.onClose  = onClose
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.app(size: 17, weight: .semibold))
                .foregroundColor(DS.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, DS.s40)
            HStack {
                Button(action: { (onClose ?? { dismiss() })() }) {
                    Image(systemName: "xmark")
                        .font(.app(size: 15, weight: .medium))
                        .foregroundColor(DS.textSecondary)
                        .accessibilityLabel(L("common.close"))
                }
                Spacer()
                trailing
            }
        }
        .padding(DS.s20)
    }
}

extension SheetHeader where Trailing == EmptyView {
    init(title: String, onClose: (() -> Void)? = nil) {
        self.init(title: title, onClose: onClose) { EmptyView() }
    }
}

// MARK: - EmptyStateView
struct EmptyStateView: View {
    @EnvironmentObject var appVM: AppViewModel
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: DS.s16) {
            ZStack {
                Circle()
                    .fill(appVM.selectedTheme.primaryColor.opacity(0.22))
                    .frame(width: 96, height: 96)
                    .blur(radius: 22)
                ZStack {
                    Circle()
                        .fill(appVM.selectedTheme.primaryColor.opacity(0.14))
                        .frame(width: 72, height: 72)
                    Image(systemName: icon)
                        .font(.app(size: 28, weight: .regular))
                        .foregroundStyle(appVM.selectedTheme.gradient)
                }
            }
            VStack(spacing: DS.s6) {
                Text(title)
                    .font(.app(size: 17, weight: .semibold))
                    .foregroundColor(DS.textPrimary)
                Text(subtitle)
                    .font(.app(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.s32)
    }
}

// MARK: - MoodBar (mini chart — no emoji)
struct MoodBar: View {
    @EnvironmentObject var appVM: AppViewModel
    let value: Double   // 0-1
    let height: CGFloat

    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            appVM.selectedTheme.secondaryColor.opacity(0.55),
                            appVM.selectedTheme.primaryColor.opacity(0.85)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(height: max(4, height * CGFloat(value)))
            }
        }
        .frame(height: height)
        .background(Color.white.opacity(0.04))
        .cornerRadius(4)
    }
}

// MARK: - MoodOrbView
struct MoodOrbView: View {
    @EnvironmentObject var appVM: AppViewModel
    let moodIndex: Int
    let size: CGFloat
    let isSelected: Bool

    private var moodColor: Color { DS.moodColor(moodIndex) }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        moodColor.opacity(isSelected ? 0.55 : 0.25),
                        moodColor.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                ))
                .frame(width: size, height: size)

            Circle()
                .fill(moodColor.opacity(isSelected ? 0.45 : 0.18))
                .frame(width: size * 0.55, height: size * 0.55)

            if isSelected {
                Circle()
                    .strokeBorder(moodColor.opacity(0.6), lineWidth: 1.5)
                    .frame(width: size * 0.72, height: size * 0.72)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isSelected ? 1.08 : 1.0)
        .animation(DS.springSnappy, value: isSelected)
        .accessibilityLabel(moodLabel)
    }

    private var moodLabel: String {
        [L("mood.veryBad"), L("mood.bad"), L("mood.neutral"),
         L("mood.good"), L("mood.great")][safe: moodIndex] ?? ""
    }
}

// MARK: - SmoothSlider
struct SmoothSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var accentColor: Color = .purple
    var label: String = ""

    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s6) {
            if !label.isEmpty {
                Text(label)
                    .font(.app(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textSecondary)
            }
            GeometryReader { geo in
                let w = geo.size.width
                let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let fillWidth = w * CGFloat(fraction)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)

                    Capsule()
                        .fill(accentColor.opacity(0.7))
                        .frame(width: max(5, fillWidth), height: 5)

                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 20 : 16, height: isDragging ? 20 : 16)
                        .shadow(color: accentColor.opacity(0.5), radius: 6)
                        .offset(x: max(0, fillWidth - (isDragging ? 10 : 8)))
                        .animation(DS.springSnappy, value: isDragging)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            isDragging = true
                            let clamped = min(max(drag.location.x, 0), w)
                            value = range.lowerBound + Double(clamped / w) * (range.upperBound - range.lowerBound)
                        }
                        .onEnded { _ in
                            isDragging = false
                            HapticManager.impact(.light)
                        }
                )
            }
            .frame(height: 24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(fraction * 100))%")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 10
            switch direction {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
        }
    }

    private var fraction: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}

// MARK: - TypewriterText
struct TypewriterText: View {
    let fullText: String
    let speed: Double

    @State private var displayedCount: Int = 0
    @State private var typingTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var displayed: String { String(fullText.prefix(displayedCount)) }

    var body: some View {
        Group {
            if reduceMotion {
                Text(fullText)
            } else {
                Text(displayed)
                    .onAppear { startTyping() }
                    .onChange(of: fullText) { _ in startTyping() }
                    .onDisappear { typingTask?.cancel() }
            }
        }
    }

    private func startTyping() {
        typingTask?.cancel()
        displayedCount = 0
        let total = fullText.count
        typingTask = Task { @MainActor in
            while displayedCount < total && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                guard !Task.isCancelled else { return }
                displayedCount += 1
            }
        }
    }
}

// MARK: - BadgeToast
struct BadgeToast: View {
    @EnvironmentObject var appVM: AppViewModel
    let badge: Badge
    @Binding var isShowing: Bool

    var body: some View {
        HStack(spacing: DS.s12) {
            Image(systemName: badge.icon)
                .font(.app(size: 22))
                .foregroundStyle(appVM.selectedTheme.gradient)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("badge.unlocked"))
                    .font(.app(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                Text(badge.localizedTitle)
                    .font(.app(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.textPrimary)
            }
        }
        .padding(.horizontal, DS.s20)
        .padding(.vertical, DS.s14)
        .background(
            RoundedRectangle(cornerRadius: DS.r20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r20, style: .continuous)
                        .strokeBorder(DS.strokeMedium, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        .scaleEffect(isShowing ? 1 : 0.85)
        .opacity(isShowing ? 1 : 0)
        .animation(DS.springSmooth, value: isShowing)
        .accessibilityElement(children: .combine)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(DS.springSmooth) { isShowing = false }
            }
        }
    }
}

// MARK: - TypingIndicator
struct TypingIndicator: View {
    @State private var phase: Int = 0
    let timer = Timer.publish(every: 0.38, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0 ..< 3, id: \.self) { i in
                Circle()
                    .fill(DS.textSecondary.opacity(phase == i ? 0.9 : 0.3))
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.25 : 1.0)
                    .animation(DS.springSnappy, value: phase)
            }
        }
        .padding(.horizontal, DS.s16)
        .padding(.vertical, DS.s10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.07))
                .overlay(Capsule().strokeBorder(DS.strokeSubtle, lineWidth: 1))
        )
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - HapticManager
enum HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - PrimaryButton
struct PrimaryButton: View {
    @EnvironmentObject var appVM: AppViewModel
    let title: String
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View {
        Button(action: {
            HapticManager.impact(.medium)
            action()
        }) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.app(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                    .fill(appVM.selectedTheme.gradient)
                    .shadow(
                        color: appVM.selectedTheme.primaryColor.opacity(0.30),
                        radius: 10, x: 0, y: 4
                    )
            )
        }
        .disabled(isLoading)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - ScaleButtonStyle
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

// MARK: - SecondaryButton
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            Text(title)
                .font(.app(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(DS.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

// MARK: - Array safe subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - SerenityLogo
struct SerenityLogo: View {
    @EnvironmentObject var appVM: AppViewModel
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(appVM.selectedTheme.gradient)
                .frame(width: size, height: size)
                .shadow(color: appVM.selectedTheme.primaryColor.opacity(0.45), radius: size * 0.25, x: 0, y: size * 0.1)

            // Leaf shape
            Image(systemName: "leaf.fill")
                .font(.app(size: size * 0.38, weight: .medium))
                .foregroundColor(.white.opacity(0.92))
                .offset(x: -size * 0.04, y: size * 0.04)

            // Sparkle accent
            Image(systemName: "sparkle")
                .font(.app(size: size * 0.22, weight: .bold))
                .foregroundColor(.white)
                .offset(x: size * 0.18, y: -size * 0.18)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - TimePickerRow
struct TimePickerRow: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var hour: Int
    @Binding var minute: Int

    @State private var showPicker = false

    private var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { showPicker.toggle() }) {
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
                    Text(timeString)
                        .font(.app(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                    Image(systemName: showPicker ? "chevron.up" : "chevron.down")
                        .font(.app(size: 11, weight: .medium))
                        .foregroundColor(DS.textTertiary)
                }
                .padding(.horizontal, DS.s20)
                .padding(.vertical, DS.s14)
            }

            if showPicker {
                Divider().background(DS.strokeSubtle).padding(.horizontal, DS.s20)
                HStack(spacing: 0) {
                    // Hour picker
                    Picker("Hour", selection: $hour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Text(":")
                        .font(.app(size: 20, weight: .bold))
                        .foregroundColor(DS.textSecondary)

                    // Minute picker
                    Picker("Minute", selection: $minute) {
                        ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 120)
                .padding(.horizontal, DS.s20)
                .padding(.bottom, DS.s8)
            }
        }
    }
}
