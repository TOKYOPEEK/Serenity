import SwiftUI
import Combine

private let chatSystemPrompt = """
You are a warm, empathetic supportive companion in a mental wellness app.
Respond in the user's language (Russian or English).
Be supportive, non-judgmental, and practical. Use CBT-informed techniques.
Do not diagnose. Keep replies concise (2-3 short paragraphs). Ask follow-up questions.
You are not a doctor or therapist. If the user is in crisis, gently encourage professional support.
"""

// MARK: - PsychologistViewModel
@MainActor
class PsychologistViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping  = false
    @Published var inputText = ""
    @Published var errorMessage: String?

    private weak var appVM: AppViewModel?

    /// Connects the view model to shared app state; safe to call repeatedly.
    func configure(with appVM: AppViewModel) {
        guard self.appVM !== appVM else { return }
        self.appVM = appVM
        if appVM.chatMessages.isEmpty {
            addWelcomeMessage()
        } else {
            messages = appVM.chatMessages
        }
    }

    private func addWelcomeMessage() {
        let welcome = ChatMessage(role: .assistant, content: L("chat.welcome"))
        messages.append(welcome)
        persist()
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = ChatMessage(role: .user, content: trimmed)
        messages.append(userMsg)
        inputText    = ""
        isTyping     = true
        errorMessage = nil
        persist()

        let context = messages.suffix(20).map { LLMClient.Message(role: $0.role.rawValue, content: $0.content) }
        Task { [weak self] in
            guard let appVM = self?.appVM else { return }
            do {
                let reply = try await appVM.fetchLLMChat(
                    system: chatSystemPrompt, messages: context, maxTokens: 600)
                self?.messages.append(ChatMessage(role: .assistant, content: reply))
            } catch is CancellationError {
                // view model torn down — nothing to show
            } catch {
                self?.errorMessage = error.localizedDescription
            }
            self?.isTyping = false
            self?.persist()
        }
    }

    func clearHistory() {
        messages = []
        addWelcomeMessage()
    }

    private func persist() { appVM?.saveChatMessages(messages) }
}

// MARK: - PsychologistChatView
struct PsychologistChatView: View {
    @EnvironmentObject var appVM: AppViewModel
    @StateObject private var viewModel = PsychologistViewModel()
    @State private var showClearConfirm = false
    @State private var showDisclaimer =
        !UserDefaults.standard.bool(forKey: StorageKey.hasSeenChatDisclaimer)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                chatNavBar
                Divider().background(DS.strokeSubtle)

                if viewModel.messages.count <= 1 && !viewModel.isTyping {
                    emptyStateOverlay
                } else {
                    chatScrollArea
                }

                if let err = viewModel.errorMessage { errorBanner(err) }
                quickChips
                inputArea
            }

            if showDisclaimer { disclaimerOverlay }
        }
        .onAppear { viewModel.configure(with: appVM) }
        .confirmationDialog(L("chat.clear.title"), isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button(L("chat.clear.confirm"), role: .destructive) { viewModel.clearHistory() }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("chat.clear.body"))
        }
    }

    // MARK: First-run disclaimer
    // Shown once before the first conversation: the AI companion is not a
    // substitute for professional care (App Store guideline 1.4 territory).
    private var disclaimerOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            GlassCard {
                VStack(spacing: DS.s16) {
                    ZStack {
                        Circle()
                            .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "heart.text.square.fill")
                            .font(.app(size: 24))
                            .foregroundStyle(appVM.selectedTheme.gradient)
                    }
                    Text(L("profile.disclaimer_title"))
                        .font(.app(size: 18, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                    Text(L("profile.disclaimer_body"))
                        .font(.app(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(title: L("chat.disclaimer.accept")) {
                        UserDefaults.standard.set(true, forKey: StorageKey.hasSeenChatDisclaimer)
                        withAnimation(DS.springSmooth) { showDisclaimer = false }
                    }
                }
                .padding(DS.s24)
            }
            .padding(.horizontal, DS.s24)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Nav bar
    private var chatNavBar: some View {
        HStack(spacing: DS.s12) {
            ZStack {
                Circle()
                    .fill(appVM.selectedTheme.gradient)
                    .frame(width: 38, height: 38)
                    .blur(radius: 3).opacity(0.5)
                Circle()
                    .fill(RadialGradient(
                        colors: [appVM.selectedTheme.primaryColor.opacity(0.9), appVM.selectedTheme.secondaryColor.opacity(0.5)],
                        center: .center, startRadius: 0, endRadius: 19
                    ))
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkle")
                    .font(.app(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(L("psychologist.name"))
                    .font(.app(size: 15, weight: .semibold))
                    .foregroundColor(DS.textPrimary)
                Text(L("psychologist.specialty"))
                    .font(.app(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            Button(action: { showClearConfirm = true }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.app(size: 15))
                    .foregroundColor(DS.textTertiary)
            }
            .accessibilityLabel(L("chat.clear.title"))
        }
        .padding(.horizontal, DS.s20)
        .padding(.vertical, DS.s14)
    }

    // MARK: Empty state
    private var emptyStateOverlay: some View {
        VStack(spacing: DS.s24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(appVM.selectedTheme.gradient)
                    .frame(width: 70, height: 70)
                    .blur(radius: 6).opacity(0.4)
                Circle()
                    .fill(RadialGradient(
                        colors: [appVM.selectedTheme.primaryColor.opacity(0.8), appVM.selectedTheme.secondaryColor.opacity(0.4)],
                        center: .center, startRadius: 0, endRadius: 35
                    ))
                    .frame(width: 64, height: 64)
                Image(systemName: "sparkle")
                    .font(.app(size: 26, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(spacing: DS.s8) {
                Text(L("chat.empty.title"))
                    .font(.app(size: 19, weight: .semibold))
                    .foregroundColor(DS.textPrimary)
                Text(L("chat.empty.subtitle"))
                    .font(.app(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                    .multilineTextAlignment(.center).lineSpacing(3)
            }
            Spacer()
        }
        .padding(.horizontal, DS.s40)
    }

    // MARK: Scroll area
    private var chatScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: DS.s12) {
                    ForEach(viewModel.messages) { msg in
                        ChatBubble(message: msg).id(msg.id)
                    }
                    if viewModel.isTyping {
                        HStack { TypingIndicator(); Spacer() }
                            .padding(.horizontal, DS.s20)
                            .id("typing")
                    }
                }
                .padding(.horizontal, DS.s20)
                .padding(.vertical, DS.s16)
                Spacer(minLength: DS.s8)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation {
                    if let lastId = viewModel.messages.last?.id { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.isTyping) { _ in
                if viewModel.isTyping { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    // MARK: Error banner
    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: DS.s8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.app(size: 13))
                .foregroundColor(Color(hex: "FBBF24"))
            Text(text)
                .font(.app(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DS.textSecondary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DS.s16).padding(.vertical, DS.s10)
        .background(
            RoundedRectangle(cornerRadius: DS.r12).fill(Color(hex: "FBBF24").opacity(0.09))
                .overlay(RoundedRectangle(cornerRadius: DS.r12).strokeBorder(Color(hex: "FBBF24").opacity(0.20), lineWidth: 1))
        )
        .padding(.horizontal, DS.s20).padding(.bottom, DS.s4)
    }

    // MARK: Quick chips
    private var quickChips: some View {
        let prompts = [
            L("psychologist.chip.anxiety"),
            L("psychologist.chip.stress"),
            L("psychologist.chip.sleep"),
            L("psychologist.chip.motivation"),
            L("psychologist.chip.unpack")
        ]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.s8) {
                ForEach(prompts, id: \.self) { prompt in
                    QuickChip(text: prompt) { viewModel.sendMessage(prompt) }
                }
            }
            .padding(.horizontal, DS.s20).padding(.vertical, DS.s8)
        }
    }

    // MARK: Input area
    private var inputArea: some View {
        HStack(spacing: DS.s10) {
            TextField(L("psychologist.input_placeholder"), text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...4)
                .font(.app(size: 15, design: .rounded))
                .foregroundColor(DS.textPrimary)
                .tint(appVM.selectedTheme.primaryColor)
                .padding(.horizontal, DS.s14).padding(.vertical, DS.s10)
                .background(
                    RoundedRectangle(cornerRadius: DS.r20).fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: DS.r20).strokeBorder(DS.strokeSubtle, lineWidth: 1))
                )

            Button(action: { viewModel.sendMessage(viewModel.inputText) }) {
                ZStack {
                    Circle()
                        .fill(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? Color.white.opacity(0.07)
                              : appVM.selectedTheme.primaryColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.up")
                        .font(.app(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                         ? DS.textTertiary : .white)
                }
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTyping)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, DS.s16).padding(.vertical, DS.s12)
        .background(ZStack { Rectangle().fill(.thinMaterial); Rectangle().fill(appBG.opacity(0.5)) })
    }
}

// MARK: - ChatBubble
private struct ChatBubble: View {
    @EnvironmentObject var appVM: AppViewModel
    let message: ChatMessage
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.s8) {
            if isUser { Spacer(minLength: 50) }
            if !isUser {
                ZStack {
                    Circle().fill(appVM.selectedTheme.primaryColor.opacity(0.20)).frame(width: 28, height: 28)
                    Circle().fill(RadialGradient(
                        colors: [appVM.selectedTheme.primaryColor.opacity(0.6), appVM.selectedTheme.secondaryColor.opacity(0.3)],
                        center: .center, startRadius: 0, endRadius: 14
                    )).frame(width: 24, height: 24)
                    Image(systemName: "sparkle").font(.app(size: 9, weight: .medium)).foregroundColor(.white)
                }
                .frame(width: 28, height: 28)
            }
            Text(message.content)
                .font(.app(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(DS.textPrimary)
                .padding(.horizontal, DS.s14).padding(.vertical, DS.s10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isUser ? appVM.selectedTheme.primaryColor.opacity(0.28) : Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(isUser ? appVM.selectedTheme.primaryColor.opacity(0.35) : DS.strokeSubtle, lineWidth: 1)
                        )
                )
                .textSelection(.enabled)
            Spacer(minLength: 50)
        }
    }
}

// MARK: - QuickChip
private struct QuickChip: View {
    @EnvironmentObject var appVM: AppViewModel
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: { HapticManager.impact(.light); action() }) {
            Text(text)
                .font(.app(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(DS.textSecondary)
                .padding(.horizontal, DS.s14).padding(.vertical, DS.s8)
                .background(Capsule().fill(Color.white.opacity(0.07)).overlay(Capsule().strokeBorder(DS.strokeSubtle, lineWidth: 1)))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

