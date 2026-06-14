# Architecture

Serenity is a single-target SwiftUI iOS app (iOS 16+) with **zero third-party
dependencies**. This document explains how it is put together, with extra depth
on the parts most relevant to language-technology work: context/memory
management, streaming inference, the multi-provider client, and per-task prompt
design.

---

## 1. The big picture

```
                       SwiftUI Views  (ContentView, HomeView, CheckInView,
                                        PsychologistChatView, AnalyticsViews, …)
                              │  @EnvironmentObject
                              ▼
                    ┌───────────────────────┐
                    │     AppViewModel       │   single @MainActor source of truth
                    │  (ObservableObject)    │   — @Published app state + intents
                    └───────────────────────┘
            ┌─────────────┬───────────┴───────────┬──────────────┐
            ▼             ▼                         ▼              ▼
   PersistenceStore   HealthStore           SoundEngine       LLMClient
   (JSON + UserDefaults  (HealthKit,         (AVAudioEngine    (async/await,
    + Keychain)          read-only)           synthesis)        SSE streaming)
            │                                                       │
            ▼                                                       ▼
   ── Pure, unit-tested logic modules (no UI, no I/O) ──    optional Cloudflare
   Streaks · WeeklyStats · BadgeRules · Correlations ·       Worker proxy
   ProactiveInsight · UserContext (AI memory)               (key off-device)
```

The design rule throughout: **push decision logic out of views and the view
model into small pure functions** that take values and return values. Those
modules (`Streaks`, `WeeklyStats`, `BadgeRules`, `Correlations`,
`ProactiveInsight`, `UserContext`) have no dependency on SwiftUI, HealthKit, or
the network, which is exactly why they can be unit-tested in isolation (see
[`SerenityTests`](SerenityTests/SerenityTests.swift)).

### Patterns
- **MVVM with one view model.** [`AppViewModel`](Serenity/AppViewModel.swift) is
  a `@MainActor ObservableObject` injected once as an `@EnvironmentObject`. It
  owns `@Published` state, exposes intent methods (`addMoodEntry`,
  `connectHealth`, `streamLLMChat`, …), and delegates real work to stores.
- **Value types for everything testable.** Models and logic modules are
  `struct`/`enum`; reference types are reserved for things that must be shared
  or long-lived (`AppViewModel`, `SoundEngine`).
- **Dependency seams for tests.** Stores accept their dependencies
  (`PersistenceStore(defaults:directoryName:)`), and pure functions accept
  `now:`/`calendar:` parameters, so tests are deterministic and hermetic.

---

## 2. Data & persistence

Three storage tiers, chosen by the shape of the data:

| Tier | What | Where | Why |
|------|------|-------|-----|
| **JSON files** | Collections: moods, journals, gratitude, programs, badges, chat, CBT records, habits | One `<key>.json` per collection in Application Support | Each collection is written independently; no giant monolithic blob |
| **UserDefaults** | Small scalar prefs: name, theme, reminder times, toggles | Standard defaults | Cheap key/value; not worth a file |
| **Keychain** | The user's own API key | [`KeychainHelper`](Serenity/KeychainHelper.swift) | Secret material never belongs in defaults or files |

[`PersistenceStore`](Serenity/PersistenceStore.swift) is the file tier. Notable
details:
- **Encryption at rest.** Writes use `.completeFileProtection`, so
  mental-health data is encrypted whenever the device is locked.
- **Atomic writes** avoid half-written files on interruption.
- **One-time migration.** Older builds stored collections as blobs inside
  UserDefaults. `load` transparently migrates any legacy blob to a file and
  deletes the old key — covered by `PersistenceStoreTests`.
- **Single source of truth for keys.** All storage keys live in one `StorageKey`
  enum, so there are no stringly-typed typos scattered across the codebase.

**Apple Health is deliberately never persisted.** `healthEnabled` is the only
stored flag; the actual metrics (`HealthSnapshot`) are recomputed from HealthKit
into memory on each launch ([`AppViewModel.refreshHealth`](Serenity/AppViewModel.swift)).
This keeps the app inside Apple's HealthKit guideline that health data may not be
stored outside HealthKit without cause.

---

## 3. The language-model layer (the interesting part)

This is the technically load-bearing piece and the reason the project exists as
a portfolio. Four concerns are separated cleanly.

### 3.1 Context / memory management — `UserContext`

The assistant should feel like it *remembers* the person without fine-tuning and
without a vector store. [`UserContext`](Serenity/UserContext.swift) is a pure
function that distils the user's recent history into a short natural-language
summary:

- a 14-day window of check-ins (count + average mood as a word),
- the current streak,
- recurring **themes** (top tags) and most-named **feelings** (emotion wheel),
- the **hardest weekday**, but only when ≥7 entries exist and the gap between
  best and worst day is ≥0.8 on the 0–4 scale (so one bad Tuesday isn't "a
  pattern"),
- a trimmed snippet of the latest journal note and gratitude entry,
- Apple Health signals (sleep, resting HR, steps) and body↔mood correlations,
- activity correlations ("mood is usually higher around exercise").

Design choices that matter for LLM work:
- **Terse counts/averages, not raw entries.** This keeps token cost low and,
  importantly, avoids shipping full journal text to a third-party provider.
- **Returns `nil` below 3 check-ins.** No memory is better than a confident
  summary built from noise.
- **`systemPreamble` framing.** The summary is wrapped with an instruction to
  *use it naturally, never recite it verbatim* — prompt hygiene so the model
  doesn't parrot the profile back at the user.

The summary is exposed as `AppViewModel.memorySummary` and injected into **every**
prompt (chat, affirmations, etc.).

### 3.2 Streaming inference — `LLMClient.stream`

[`LLMClient`](Serenity/LLMClient.swift) offers two entry points:
- `complete(...) async throws -> String` for one-shot structured calls,
- `stream(...) -> AsyncThrowingStream<String, Error>` for the chat.

Streaming reads the HTTP body with `URLSession.bytes(for:)`, iterates
`bytes.lines`, and parses **Server-Sent Events** by hand: strip the `data:`
prefix, stop on `[DONE]`, decode each chunk, and `yield` the text delta. The
stream's `onTermination` cancels the underlying `Task`, so navigating away from
the chat tears the network request down cleanly. The chat view consumes the
async stream and appends deltas to the visible message, giving token-by-token
output ([`PsychologistChatView`](Serenity/PsychologistChatView.swift)).

### 3.3 Provider abstraction

One client targets two API families behind a small `Config` (endpoint, model,
key, optional `reasoningEffort`). The endpoint string decides the dialect:

| | Anthropic Messages API | OpenAI-compatible Chat Completions |
|---|---|---|
| Auth header | `x-api-key` + `anthropic-version` | `Authorization: Bearer` |
| System prompt | top-level `system` field | first message with `role: system` |
| Stream delta | `content_block_delta.delta.text` | `choices[].delta.content` |
| Non-stream text | `content[].text` | `choices[].message.content` |

Both shapes are normalised so callers never branch on provider. Errors are
normalised too: HTTP status maps to a typed `LLMError`, and for "other" 4xx the
client decodes the provider's `{"error":{"message":…}}` body and surfaces the
real message. `reasoning_effort` is encoded with `encodeIfPresent` so strict
providers that don't know the field never see it.

### 3.4 Prompt design per task

Each task gets its own purpose-built system prompt, all sharing the same memory
preamble where personalization helps:

| Task | Prompt site | Shape |
|------|-------------|-------|
| Empathetic chat | [`PsychologistChatView.swift`](Serenity/PsychologistChatView.swift) | streamed free text + safety framing + memory |
| Mood insight | [`CheckInView.swift`](Serenity/CheckInView.swift) | **strict JSON only**, decoded into `AIInsight` |
| CBT reframing | [`CBTToolsViews.swift`](Serenity/CBTToolsViews.swift) | guided cognitive-distortion reframe |
| Weekly narrative | [`WellnessViews.swift`](Serenity/WellnessViews.swift) | warm summary over the week's stats |
| Affirmation | [`AppViewModel.swift`](Serenity/AppViewModel.swift) | one line, ≤12 words, user's language |

Every AI feature has a graceful **offline fallback** (built-in affirmations,
rules-based insights) so the app is fully usable with no key and no network.

### 3.5 Cost & safety boundary — the proxy

The provider key never has to live on the phone. [`proxy/worker.js`](proxy/worker.js)
is a Cloudflare Worker that:
1. checks a throwaway **app token** (blocks random callers),
2. enforces a **per-IP daily limit** in Workers KV (caps spend if the token
   leaks),
3. forwards to the upstream provider with the **real key** (a Worker secret),
   streaming the SSE response straight through.

For the bundled out-of-the-box experience, a key can instead be embedded via
[`Secrets.swift`](Serenity/Secrets.swift.template) (gitignored; XOR-obfuscated,
which only slows an attacker — the real guard is a hard spend limit in the
provider console). `AppViewModel.llmConfig` resolves which path to use: a user's
own key wins; otherwise the bundled provider is used as one consistent unit.

---

## 4. Other subsystems

- **Generated audio.** [`SoundEngine`](Serenity/SoundEngine.swift) synthesises
  white/pink/brown noise and rain/ocean/forest soundscapes in an
  `AVAudioSourceNode` render callback — no bundled audio files, no licensing,
  works offline. Pink noise uses the Voss-McCartney approximation; ocean/forest
  add slow LFO envelopes for swell and gusts.
- **Correlations & insights.** [`Correlations`](Serenity/Correlations.swift)
  computes which activities/habits lift or weigh on mood (effect size vs the
  overall mean, with a minimum sample count so rare tags can't masquerade as
  patterns). [`ProactiveInsight`](Serenity/ProactiveInsight.swift) turns the
  same data into one offline observation that can be scheduled into a local
  notification — no server, no LLM at fire-time.
- **Notifications.** [`NotificationScheduler`](Serenity/NotificationScheduler.swift)
  handles reminders, SOS follow-ups, and proactive-insight nudges.
- **Biometric lock.** Face ID gating lives in `AppViewModel`, with a re-entrancy
  guard (`isAuthenticating`) because presenting the biometric sheet briefly
  resigns/reactivates the app and would otherwise loop.
- **Localization.** Full English + Russian via an `L(_:)` helper and
  `.lproj` string tables; correlation tags and insights are localized too.

---

## 5. Testing

[`SerenityTests`](SerenityTests/SerenityTests.swift) covers the pure logic where
correctness actually matters:

- `Streaks` — streak counting incl. "no check-in yet today" and same-day dedupe,
- `WeeklyStats` — averages, top mood/tags, week-window exclusion,
- `BadgeRules` — every unlock threshold incl. unknown-badge safety,
- `UserContext` — that name/streak/themes/journal/health all surface, and that
  empty or too-small inputs produce no memory,
- `Correlations` — lift/weigh detection and rare-tag suppression,
- `AIInsight.parse` — a small **LLM-output eval harness**: that fenced /
  prose-wrapped / whitespace-padded JSON still decodes, and that malformed,
  truncated, or blank replies are rejected so the offline fallback kicks in,
- `ChatMessage` — backward-compatible decoding (legacy string role → enum),
- `UserDefaults` default-aware accessor — the "midnight (hour 0) survives
  relaunch" bug,
- `PersistenceStore` — round-trip, overwrite, and legacy-blob migration.

Run them with `⌘U` in Xcode, or:

```bash
xcodebuild test -scheme Serenity -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## 6. Project conventions

- **No package manager.** The Xcode project is hand-maintained; a helper script
  (`gen_project.py`) regenerates it from the file list when needed.
- **Secrets stay out of git.** Only `Secrets.swift.template` is committed.
- **Comments explain *why*, not *what*** — most non-obvious decisions in the
  code carry a one-line rationale (see the Face ID re-entrancy guard or the
  `reasoning_effort` omission).
