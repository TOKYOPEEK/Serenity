import SwiftUI

// MARK: - SparkLoader (AI "thinking" indicator — the splash orb, no name)
/// A calm, on-brand loading visual: the sparkle orb gently breathes with a
/// soft glow instead of a spinner. Reuses the launch aesthetic.
struct SparkLoader: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 64
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(appVM.selectedTheme.primaryColor)
                .frame(width: size * 1.9, height: size * 1.9)
                .blur(radius: size * 0.5)
                .opacity(pulse ? 0.5 : 0.18)

            ZStack {
                Circle()
                    .fill(appVM.selectedTheme.gradient)
                    .frame(width: size, height: size)
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(pulse ? 1.06 : 0.9)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - SplashView (launch animation — "soft spark")
/// Shown over everything at launch: the sparkle orb gently inflates from a
/// point with a soft glow, the name fades up, then the parent dissolves it
/// into the app. Honors Reduce Motion (fades only, no scale).
struct SplashView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    var body: some View {
        ZStack {
            // Brand backdrop: deep navy with a soft lavender bloom up top.
            appBG.ignoresSafeArea()
            RadialGradient(
                colors: [appVM.selectedTheme.primaryColor.opacity(0.18), .clear],
                center: .init(x: 0.5, y: 0.4), startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: DS.s20) {
                ZStack {
                    Circle()
                        .fill(appVM.selectedTheme.primaryColor)
                        .frame(width: 180, height: 180)
                        .blur(radius: 50)
                        .opacity(appear ? 0.5 : 0)

                    ZStack {
                        Circle()
                            .fill(appVM.selectedTheme.gradient)
                            .frame(width: 96, height: 96)
                        Image(systemName: "sparkle")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(appear ? 1 : (reduceMotion ? 1 : 0.2))
                    .opacity(appear ? 1 : 0)
                }

                Text("Serenity")
                    .font(.app(size: 26, weight: .semibold))
                    .foregroundColor(DS.textPrimary)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)
            }
        }
        .onAppear {
            withAnimation(reduceMotion
                          ? .easeOut(duration: 0.5)
                          : .spring(response: 0.75, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}
