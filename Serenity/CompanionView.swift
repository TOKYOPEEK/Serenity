import SwiftUI

// MARK: - CompanionView
/// The Serenity companion ("Лу", a little otter spirit). The creature is drawn
/// entirely in code so it can react to `CompanionState` and animate, and is
/// isolated here so a designed asset can later replace `CompanionCreature`
/// without touching the surrounding logic.
struct CompanionView: View {
    @EnvironmentObject var appVM: AppViewModel
    let state: CompanionState
    var size: CGFloat = 132

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?

    private var glowColor: Color {
        switch state {
        case .blooming, .calm: return appVM.selectedTheme.primaryColor
        case .anxious:         return Color(hex: "E08A6C")
        case .sleepy:          return Color(hex: "6E6C7A")
        }
    }

    var body: some View {
        VStack(spacing: DS.s10) {
            ZStack {
                Circle()
                    .fill(glowColor.opacity(state == .sleepy ? 0.10 : 0.22))
                    .frame(width: size * 1.05, height: size * 1.05)
                    .blur(radius: size * 0.18)

                CompanionCreature(state: state, size: size)
                    .frame(width: size, height: size * 1.12)
                    .offset(y: bob ? -size * 0.03 : size * 0.03)
            }
            .frame(height: size * 1.2)

            if let bubble {
                Text(bubble)
                    .font(.app(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.s16)
                    .padding(.vertical, DS.s10)
                    .background(
                        RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .overlay(RoundedRectangle(cornerRadius: DS.r16).strokeBorder(DS.strokeSubtle, lineWidth: 1))
                    )
                    .padding(.horizontal, DS.s24)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { speak() }
        .accessibilityElement()
        .accessibilityLabel(L("companion.name"))
        .accessibilityValue(bubble ?? L("companion.a11y.\(state.rawValue)"))
        .accessibilityHint(L("companion.a11y.hint"))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { bob = true }
        }
        .onDisappear { bubbleTask?.cancel() }
    }

    private func speak() {
        HapticManager.impact(.light)
        let line = CompanionDialogue.line(for: state, name: appVM.userName, streak: appVM.streak)
        withAnimation(DS.springSnappy) { bubble = line }
        bubbleTask?.cancel()
        bubbleTask = Task {
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation(DS.springSmooth) { bubble = nil } }
        }
    }
}

// MARK: - CompanionCreature (the drawn otter)
private struct CompanionCreature: View {
    let state: CompanionState
    let size: CGFloat

    private func s(_ v: CGFloat) -> CGFloat { v * size / 100 }

    private var furTop: Color   { state == .sleepy ? Color(hex: "6E6C7A") : Color(hex: "B59072") }
    private var furBase: Color  { state == .sleepy ? Color(hex: "565461") : Color(hex: "8E6E50") }
    private var belly: Color    { state == .sleepy ? Color(hex: "C2C3CE") : Color(hex: "EFE0CB") }
    private var darkInk: Color  { Color(hex: "3A2E25") }

    var body: some View {
        ZStack {
            // Tail
            Capsule()
                .fill(furBase)
                .frame(width: s(16), height: s(44))
                .rotationEffect(.degrees(38))
                .offset(x: s(34), y: s(36))

            // Body
            Ellipse()
                .fill(LinearGradient(colors: [furTop, furBase], startPoint: .top, endPoint: .bottom))
                .frame(width: s(78), height: s(86))
                .offset(y: s(14))
            Ellipse()
                .fill(belly)
                .frame(width: s(46), height: s(56))
                .offset(y: s(24))

            // Little feet
             forEachFoot

            // Ears
            Group {
                 Circle().fill(furBase).frame(width: s(22), height: s(22)).offset(x: -s(30), y: -s(34))
                Circle().fill(furBase).frame(width: s(22), height: s(22)).offset(x: s(30), y: -s(34))
                Circle().fill(belly.opacity(0.8)).frame(width: s(10), height: s(10)).offset(x: -s(30), y: -s(34))
                Circle().fill(belly.opacity(0.8)).frame(width: s(10), height: s(10)).offset(x: s(30), y: -s(34))
            }

            // Head
            Ellipse()
                .fill(LinearGradient(colors: [furTop, furBase], startPoint: .top, endPoint: .bottom))
                .frame(width: s(82), height: s(74))
                .offset(y: -s(18))

            // Muzzle patch
            Ellipse()
                .fill(belly)
                .frame(width: s(46), height: s(38))
                .offset(y: -s(6))

            face
        }
        .frame(width: size, height: size * 1.12)
    }

    private var forEachFoot: some View {
        Group {
            Ellipse().fill(furBase).frame(width: s(18), height: s(13)).offset(x: -s(18), y: s(52))
            Ellipse().fill(furBase).frame(width: s(18), height: s(13)).offset(x: s(18), y: s(52))
        }
    }

    // MARK: Face (expression by state)
    @ViewBuilder private var face: some View {
        // Cheeks (blush) when blooming
        if state == .blooming {
            Group {
                Circle().fill(Color(hex: "F2A8B0").opacity(0.55)).frame(width: s(13), height: s(13)).offset(x: -s(26), y: -s(8))
                Circle().fill(Color(hex: "F2A8B0").opacity(0.55)).frame(width: s(13), height: s(13)).offset(x: s(26), y: -s(8))
            }
        }

        // Eyes
        eyes

        // Nose
        Ellipse()
            .fill(darkInk)
            .frame(width: s(11), height: s(8))
            .offset(y: -s(10))

        // Mouth
        mouth

        // Whiskers
        whiskers

        // State accessories
        accessories
    }

    @ViewBuilder private var eyes: some View {
        switch state {
        case .calm, .blooming:
            Group {
                eyeOpen.offset(x: -s(17), y: -s(22))
                eyeOpen.offset(x: s(17), y: -s(22))
            }
        case .sleepy:
            Group {
                eyeClosed.offset(x: -s(17), y: -s(22))
                eyeClosed.offset(x: s(17), y: -s(22))
            }
        case .anxious:
            Group {
                eyeOpen.offset(x: -s(17), y: -s(20))
                eyeOpen.offset(x: s(17), y: -s(20))
                // worried brows
                Capsule().fill(darkInk).frame(width: s(14), height: s(2.6))
                    .rotationEffect(.degrees(18)).offset(x: -s(17), y: -s(31))
                Capsule().fill(darkInk).frame(width: s(14), height: s(2.6))
                    .rotationEffect(.degrees(-18)).offset(x: s(17), y: -s(31))
            }
        }
    }

    private var eyeOpen: some View {
        ZStack {
            Circle().fill(darkInk).frame(width: s(12), height: s(12))
            Circle().fill(Color.white).frame(width: s(4), height: s(4)).offset(x: s(1.5), y: -s(2.5))
        }
    }

    private var eyeClosed: some View {
        ClosedEye().stroke(darkInk, style: StrokeStyle(lineWidth: s(2.6), lineCap: .round))
            .frame(width: s(15), height: s(8))
    }

    @ViewBuilder private var mouth: some View {
        switch state {
        case .blooming:
            HappyMouth().stroke(darkInk, style: StrokeStyle(lineWidth: s(2.4), lineCap: .round))
                .frame(width: s(20), height: s(11)).offset(y: -s(1))
        case .calm:
            HappyMouth().stroke(darkInk, style: StrokeStyle(lineWidth: s(2.2), lineCap: .round))
                .frame(width: s(13), height: s(6)).offset(y: -s(2))
        case .sleepy:
            Capsule().fill(darkInk).frame(width: s(7), height: s(2.2)).offset(y: -s(2))
        case .anxious:
            WavyMouth().stroke(darkInk, style: StrokeStyle(lineWidth: s(2.2), lineCap: .round))
                .frame(width: s(15), height: s(6)).offset(y: -s(1))
        }
    }

    private var whiskers: some View {
        Group {
            ForEach(0..<3, id: \.self) { i in
                let dy = s(CGFloat(i) * 5 - 5)
                Capsule().fill(darkInk.opacity(0.45)).frame(width: s(16), height: s(1.6))
                    .offset(x: -s(34), y: -s(9) + dy)
                Capsule().fill(darkInk.opacity(0.45)).frame(width: s(16), height: s(1.6))
                    .offset(x: s(34), y: -s(9) + dy)
            }
        }
    }

    @ViewBuilder private var accessories: some View {
        switch state {
        case .blooming:
            Group {
                Image(systemName: "sparkle").font(.system(size: s(13), weight: .bold))
                    .foregroundColor(Color(hex: "FDE68A")).offset(x: s(40), y: -s(40))
                Image(systemName: "sparkle").font(.system(size: s(8), weight: .bold))
                    .foregroundColor(Color(hex: "FDE68A")).offset(x: -s(42), y: -s(28))
            }
        case .sleepy:
            Group {
                Text("z").font(.app(size: s(15), weight: .bold)).foregroundColor(belly).offset(x: s(34), y: -s(40))
                Text("z").font(.app(size: s(10), weight: .bold)).foregroundColor(belly).offset(x: s(44), y: -s(50))
            }
        case .anxious:
            // sweat drop
            Ellipse().fill(Color(hex: "7FC4E8")).frame(width: s(7), height: s(10))
                .offset(x: s(30), y: -s(26))
        case .calm:
            EmptyView()
        }
    }
}

// MARK: - Expression shapes
private struct ClosedEye: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY))
        return p
    }
}

private struct HappyMouth: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY + r.height))
        return p
    }
}

private struct WavyMouth: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.midY), control: CGPoint(x: r.width * 0.25, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.width * 0.75, y: r.maxY))
        return p
    }
}
