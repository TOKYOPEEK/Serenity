import SwiftUI
import LocalAuthentication

@main
struct SerenityApp: App {
    @StateObject private var appVM = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appVM)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var isResigningActive = false

    var body: some View {
        ZStack {
            if appVM.isOnboardingComplete {
                if appVM.faceLockEnabled && !appVM.isUnlocked {
                    FaceLockView()
                } else {
                    ContentView()
                }
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appVM.isOnboardingComplete)
        .animation(.easeInOut(duration: 0.3), value: appVM.isUnlocked)
        .overlay {
            if isResigningActive {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            withAnimation(.easeIn(duration: 0.15)) { isResigningActive = true }
            if appVM.faceLockEnabled { appVM.isUnlocked = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isResigningActive = false }
            if appVM.faceLockEnabled && !appVM.isUnlocked {
                appVM.authenticateWithBiometrics { success in
                    appVM.isUnlocked = success
                }
            }
        }
    }
}

// MARK: - FaceLockView
struct FaceLockView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            appBG.ignoresSafeArea()
            VStack(spacing: DS.s32) {
                Spacer()
                SerenityLogo(size: 80)
                VStack(spacing: DS.s12) {
                    Text("Serenity")
                        .font(.app(size: 28, weight: .bold))
                        .foregroundColor(DS.textPrimary)
                    Text(L("facelock.subtitle"))
                        .font(.app(size: 14, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                }
                Spacer()
                Button(action: authenticate) {
                    HStack(spacing: DS.s10) {
                        Image(systemName: "faceid")
                            .font(.app(size: 20))
                        Text(L("facelock.unlock"))
                            .font(.app(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                            .fill(appVM.selectedTheme.gradient)
                    )
                }
                .padding(.horizontal, DS.s40)
                .padding(.bottom, DS.s40)
                .disabled(isAuthenticating)
            }
        }
        .onAppear { authenticate() }
    }

    private func authenticate() {
        isAuthenticating = true
        appVM.authenticateWithBiometrics { success in
            isAuthenticating = false
            appVM.isUnlocked = success
        }
    }
}
