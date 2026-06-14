# Serenity

A private, AI-assisted mental-wellness companion for iOS, built in SwiftUI.

Serenity helps you check in on how you feel and understand what drives your
mood. Its technically interesting core is the **language-model integration**: an
assistant grounded in a compact, on-device memory of the user's own history,
delivered with token-by-token streaming — all while keeping personal data on the
device.

> Solo project, built end-to-end as an engineering portfolio piece — from
> SwiftUI architecture to a streaming LLM client and a serverless proxy.

---

## Language-technology engineering highlights

The parts most relevant to NLP / language-technology work:

- **Context / memory management.** A pure `UserContext` module distils the
  user's recent history (moods, recurring themes, named emotions, activity
  correlations, Health signals) into a short natural-language summary that is
  injected into every system prompt — so the model behaves as if it "remembers"
  the user, without fine-tuning or a vector store.
- **Streaming inference.** `LLMClient` parses Server-Sent Events and yields the
  reply token-by-token through an `AsyncThrowingStream`, for both
  OpenAI-compatible and Anthropic message formats.
- **Provider abstraction.** One client targets multiple chat-completion APIs;
  request/response shapes, auth and error bodies are normalised behind a small
  `Config`.
- **Prompt design per task.** Distinct system prompts for empathetic chat,
  JSON-structured mood insights, CBT thought-reframing and weekly narratives,
  with graceful offline fallbacks.
- **Cost & safety boundary.** A Cloudflare Worker proxy (`proxy/`) keeps the
  provider key off the device, enforces a per-IP daily limit, and streams
  responses through.

---

## Features (product)

- Mood check-ins with a tactile 2D energy/tension pad and an emotion wheel
- AI chat, insights, weekly reports and affirmations grounded in your history
- Activity & Apple Health correlations ("what lifts vs. weighs on your mood")
- CBT tools (thought reframing, coping plan), habits, breathing, SOS grounding
- Generated soundscapes + text-guided meditations + focus timer (no audio files)
- Analytics, proactive insights, full English + Russian localisation

---

## Tech stack

- **Language / UI:** Swift, SwiftUI (iOS 16+), MVVM with a `@MainActor` view model
- **Persistence:** JSON files + UserDefaults; Keychain for the API key;
  `completeFileProtection` on sensitive data
- **Health:** HealthKit, read-only and never persisted
- **AI:** async/await multi-provider client with SSE streaming; rules-based
  memory & correlations
- **Audio:** AVAudioEngine source node synthesising noise/soundscapes on the fly
- **Infra:** Cloudflare Worker proxy
- **Testing:** XCTest units for streaks, weekly stats, badge rules, correlations,
  AI-memory and codable/persistence migration
- **Tooling:** hand-maintained Xcode project, zero third-party dependencies

---

## Architecture in one minute

```
SwiftUI Views ── @EnvironmentObject ─▶ AppViewModel (@MainActor)
                                         │
        ┌────────────────────────────────┼───────────────────────────┐
   PersistenceStore            HealthStore / SoundEngine        LLMClient
   (JSON + UserDefaults)       (HealthKit / AVAudioEngine)   (async + SSE)
        │                                                          │
   Pure, unit-tested logic: Streaks · WeeklyStats · BadgeRules · UserContext
   Correlations · ProactiveInsight                              (AI memory)
```

Business logic is deliberately separated into small **pure, unit-tested**
modules so it can be reasoned about without the UI or the network.

---

## Privacy by design

No account, no ads, no analytics. Mood/journal/habits stay on the device. Apple
Health is read-only and never persisted. Full policy: [`docs/privacy.html`](docs/privacy.html).

---

## Build & run

```bash
open Serenity.xcodeproj   # Xcode 16+, iOS 16+
```

AI features need a key: add your own in Profile → AI connection, or create
`Serenity/Secrets.swift` from `Secrets.swift.template` (gitignored, never
committed). Run tests with `⌘U`.

---

## About

Built by Amir as part of a portfolio toward a master's in language science &
technology. Feature-complete v1; release prep (proxy, privacy policy, store
copy) lives in `proxy/` and `docs/`.

## License

[MIT](LICENSE)
