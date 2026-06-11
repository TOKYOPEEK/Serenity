import SwiftUI

// MARK: - CompanionView (living stage)
/// The Serenity companion ("Лу", a little otter spirit) roaming a small stage.
/// Lu autonomously hops between points along an arc with squash-and-stretch,
/// faces the direction it moves, breathes while idle, and stops to speak when
/// tapped. The drawn `CompanionCreature` is a placeholder — a designed asset
/// can replace it without touching this movement engine.
struct CompanionView: View {
    @EnvironmentObject var appVM: AppViewModel
    let state: CompanionState
    var size: CGFloat = 92

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Movement engine state
    @State private var hopX: CGFloat = 0          // current x within the stage
    @State private var fromX: CGFloat = 0          // hop start x
    @State private var toX: CGFloat = 0            // hop target x
    @State private var hop: CGFloat = 1            // 0→1 progress of the current hop
    @State private var facing: CGFloat = 1         // +1 right, -1 left
    @State private var breathe = false
    @State private var landSquash = false
    @State private var crouch = false
    @State private var roam: Task<Void, Never>?

    // Speech
    @State private var bubble: String?
    @State private var bubbleTask: Task<Void, Never>?
    @State private var paused = false

    private var stageHeight: CGFloat { size * 1.35 }
    private var arc: CGFloat { size * 0.7 }

    private var glowColor: Color {
        switch state {
        case .blooming, .calm: return appVM.selectedTheme.primaryColor
        case .anxious:         return Color(hex: "E08A6C")
        case .sleepy:          return Color(hex: "6E6C7A")
        }
    }

    var body: some View {
        VStack(spacing: DS.s8) {
            bubbleView
            GeometryReader { geo in
                let stageWidth = geo.size.width
                ZStack(alignment: .bottomLeading) {
                    Circle()
                        .fill(glowColor.opacity(state == .sleepy ? 0.10 : 0.20))
                        .frame(width: size * 1.0, height: size * 1.0)
                        .blur(radius: size * 0.2)
                        .offset(x: hopX - size * 0.5 + currentArcOffset.x,
                                y: currentArcOffset.y + size * 0.1)

                    CompanionCreature(state: state, size: size)
                        .frame(width: size, height: size * 1.12)
                        .scaleEffect(x: facing * stretchX, y: stretchY, anchor: .bottom)
                        .offset(x: hopX - size * 0.5 + currentArcOffset.x,
                                y: currentArcOffset.y)
                        .contentShape(Rectangle())
                        .onTapGesture { speak() }
                }
                .frame(width: stageWidth, height: stageHeight, alignment: .bottomLeading)
                .onAppear { startRoaming(width: stageWidth) }
            }
            .frame(height: stageHeight)
        }
        .accessibilityElement()
        .accessibilityLabel(L("companion.name"))
        .accessibilityValue(bubble ?? L("companion.a11y.\(state.rawValue)"))
        .accessibilityHint(L("companion.a11y.hint"))
        .onDisappear { roam?.cancel(); bubbleTask?.cancel() }
    }

    @ViewBuilder private var bubbleView: some View {
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

    // MARK: Squash-and-stretch + arc

    /// Position offset along the parabolic hop (x eases, y arcs up then down).
    private var currentArcOffset: CGPoint {
        let h = sin(.pi * hop)                 // 0 → 1 → 0
        let x = (toX - fromX) * hop
        return CGPoint(x: x, y: -arc * h)
    }

    /// Vertical stretch: tall during fast vertical motion, squashed on landing.
    private var stretchY: CGFloat {
        if landSquash { return 0.82 }
        if crouch { return 0.88 }
        let vy = abs(cos(.pi * hop))           // 1 at take-off/landing, 0 at apex
        let moving = hop < 1 ? vy * 0.16 : 0
        let breath = breathe ? 0.03 : -0.03
        return 1 + moving + (hop >= 1 ? breath : 0)
    }

    private var stretchX: CGFloat {
        if landSquash { return 1.16 }
        if crouch { return 1.10 }
        let vy = abs(cos(.pi * hop))
        let moving = hop < 1 ? vy * 0.12 : 0
        return 1 - moving
    }

    // MARK: Roaming engine

    private func startRoaming(width: CGFloat) {
        let margin = size * 0.6
        let minX = margin
        let maxX = max(margin + 1, width - margin)
        hopX = (minX + maxX) / 2
        fromX = hopX; toX = hopX; hop = 1

        guard !reduceMotion, width > size else {
            // Reduced motion: just breathe gently in place.
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
            return
        }

        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true }

        roam?.cancel()
        roam = Task { @MainActor in
            while !Task.isCancelled {
                let idle = Double.random(in: 1.4...3.2)
                try? await Task.sleep(nanoseconds: UInt64(idle * 1_000_000_000))
                guard !Task.isCancelled, !paused else { continue }

                // Pick a new spot far enough to be worth a hop.
                var target = CGFloat.random(in: minX...maxX)
                if abs(target - hopX) < size * 0.5 {
                    target = abs(target - minX) < abs(target - maxX) ? maxX : minX
                }
                await performHop(to: target)
            }
        }
    }

    private func performHop(to target: CGFloat) async {
        let newFacing: CGFloat = target >= hopX ? 1 : -1
        withAnimation(.easeInOut(duration: 0.18)) { facing = newFacing }

        // Anticipation crouch
        withAnimation(.easeOut(duration: 0.16)) { crouch = true }
        try? await Task.sleep(nanoseconds: 170_000_000)
        guard !Task.isCancelled else { return }
        crouch = false

        // The hop itself — linear so horizontal speed stays constant across the arc.
        fromX = hopX
        toX = target
        hop = 0
        let hopTime = Double.random(in: 0.5...0.66)
        withAnimation(.linear(duration: hopTime)) { hop = 1 }
        try? await Task.sleep(nanoseconds: UInt64(hopTime * 1_000_000_000))
        guard !Task.isCancelled else { return }

        // Land: settle to the target, then a springy squash.
        hopX = target
        fromX = target; toX = target; hop = 1
        HapticManager.impact(.soft)
        withAnimation(.easeOut(duration: 0.08)) { landSquash = true }
        try? await Task.sleep(nanoseconds: 90_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) { landSquash = false }
    }

    private func speak() {
        HapticManager.impact(.light)
        paused = true
        let line = CompanionDialogue.line(for: state, name: appVM.userName, streak: appVM.streak)
        withAnimation(DS.springSnappy) { bubble = line }
        // A little excited hop in place when greeted.
        Task { @MainActor in
            await performHop(to: hopX + (facing * size * 0.01))
        }
        bubbleTask?.cancel()
        bubbleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(DS.springSmooth) { bubble = nil }
            paused = false
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
