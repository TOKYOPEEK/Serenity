# Serenity — engineering case study

> A short, honest account of the **decisions and trade-offs** behind Serenity,
> written for a technical reader. The product is a mental-wellness iOS app; the
> reason it exists is to demonstrate engineering judgement and hands-on work with
> language models — context/memory management, streaming, multi-provider
> integration, and prompt design. Where I made a compromise, I say so.

For *how* the pieces fit together, see [ARCHITECTURE.md](ARCHITECTURE.md). This
document is about *why*.

---

## 1. Memory without a vector store

**Problem.** The assistant should feel like it knows the user — their recent
mood, recurring themes, what lifts or weighs on them — across separate sessions.
The textbook answer is embeddings + a vector database + retrieval.

**Decision.** I built a deterministic, rules-based "memory" instead: a pure
function ([`UserContext`](Serenity/UserContext.swift)) that distils recent
history into a compact natural-language summary injected into every system
prompt.

**Why.**
- **The corpus is tiny and structured.** A single user's last two weeks of
  check-ins is a handful of records, not a document corpus. Embedding-based
  retrieval solves a problem I don't have; it would add a dependency, an index
  to maintain, and latency, to rank ~20 items.
- **Privacy.** A summary of *counts, averages, and themes* leaks far less than
  shipping raw journal text to a provider for embedding. The summary is
  deliberately terse for this reason.
- **Determinism = testability.** Because it's a pure function, I can unit-test
  that the name, streak, dominant theme, journal snippet, and health signals all
  surface — and that thin input produces *no* memory (`nil` below 3 check-ins).

**Trade-off / limits.** This doesn't scale to a large free-text history and
won't surface a relevant note from three months ago the way semantic search
would. For this product that's the right boundary; if the history grew
unbounded, a retrieval layer would become the better tool. I'd rather ship the
simplest thing that fits the data than cargo-cult an architecture.

**Prompt hygiene.** The summary is wrapped with an explicit instruction to *use
it naturally, never recite it verbatim* — otherwise models tend to open with
"As someone who feels anxious on Mondays…", which is unsettling.

---

## 2. Streaming I parse myself

**Decision.** The chat streams token-by-token. I implemented SSE parsing
directly on `URLSession.bytes(for:)` and exposed it as an
`AsyncThrowingStream<String, Error>` ([`LLMClient.stream`](Serenity/LLMClient.swift)),
rather than pulling in a networking/SSE library.

**Why.** SSE for chat completions is genuinely simple — line-prefixed `data:`
frames terminated by `[DONE]`. Doing it by hand keeps the dependency count at
zero, makes the back-pressure and cancellation story explicit (the stream's
`onTermination` cancels the `Task`, so leaving the chat kills the request), and
maps cleanly onto Swift Concurrency.

**Trade-off.** I'm responsible for the edge cases a library would handle —
partial lines, both providers' chunk shapes, error frames mid-stream. I decode
each provider's delta shape explicitly and fall back to a typed `LLMError`. For a
single screen of chat this is a reasonable amount of code to own; for many
streaming endpoints I'd reach for a library.

---

## 3. One client, two providers

**Decision.** A single [`LLMClient`](Serenity/LLMClient.swift) speaks both the
Anthropic Messages API and OpenAI-compatible Chat Completions, chosen by the
endpoint string, behind a small `Config`.

**Why.** It future-proofs the app against provider changes and lets the bundled
key and a user's own key point at different backends without touching call sites.
The differences are real but small (auth header, where the system prompt goes,
the delta JSON path), so normalising them in one place is cheap.

**Details worth calling out.**
- **Error normalisation.** Status codes map to typed errors; for other 4xx I
  decode the provider's `{"error":{"message":…}}` and surface the actual message
  instead of a generic failure.
- **`reasoning_effort` is conditional.** It's only sent to providers known to
  accept it, encoded with `encodeIfPresent` so a strict provider never sees an
  unknown field — a small thing that prevents a class of 400s.

**Trade-off.** Endpoint-string sniffing (`contains("anthropic.com")`) is pragmatic
but not elegant; a provider enum would be cleaner if a third backend arrived.

---

## 4. Keeping the API key off the device

**Problem.** Shipping AI "out of the box" means a key travels with the app, and
anything in an app binary can be extracted.

**Decision.** Two layers. A Cloudflare Worker proxy
([`proxy/worker.js`](proxy/worker.js)) holds the real key as a server secret,
gates calls behind an app token, and enforces a per-IP daily limit in KV. For the
simplest builds, a key can be embedded via XOR-obfuscated
[`Secrets.swift`](Serenity/Secrets.swift.template) (gitignored).

**Honest about the limit.** I treat obfuscation as a speed bump, not security —
the comment in the file says exactly that. The actual protection is the proxy's
rate limit plus a hard spending cap in the provider console. This is the
realistic threat model for a portfolio/indie app: you can't make a bundled key
un-extractable, so you cap the blast radius.

---

## 5. Persistence: files + UserDefaults, not Core Data

**Decision.** Collections are stored as per-collection JSON files via
[`PersistenceStore`](Serenity/PersistenceStore.swift); scalars in UserDefaults;
the key in Keychain.

**Why.** The data is a few `Codable` arrays. Core Data / SwiftData would bring a
model editor, migrations, and a context lifecycle to manage — overhead with no
payoff at this size. Plain `Codable` + files is transparent, trivially testable
with an injected directory, and easy to encrypt.

**Two decisions I'm glad I made:**
- **`.completeFileProtection`** on every write — mental-health data is encrypted
  at rest whenever the device is locked. Cheap, and the right default for this
  category.
- **A migration path from day one.** An earlier version stored collections as
  blobs inside UserDefaults; `load` migrates any legacy blob to a file and
  removes the old key, with a test pinning the behaviour. Real apps have to
  evolve their storage; I wanted that muscle in the codebase.

**Trade-off.** No querying, no relations, everything loads into memory. Fine for
single-user, bounded data; wrong for anything larger.

---

## 6. The "small bug" tests

Most of the [test suite](SerenityTests/SerenityTests.swift) targets the logic
that's easy to get subtly wrong and annoying to debug by hand:

- **Streaks** — does the streak survive "no check-in *yet* today"? Do multiple
  check-ins in one day count once? Does a gap reset it?
- **A UserDefaults accessor** that distinguishes "unset" from a stored `0`, so a
  reminder set to **midnight (hour 0)** survives a relaunch — a real bug I hit.
- **Backward-compatible decoding** — chats saved when `role` was a plain string
  still decode after it became an enum.

I tested these rather than the UI because this is where correctness lives and
where regressions would be invisible until a user noticed. Keeping the logic in
pure functions is what made them testable in the first place.

**Structured LLM output gets the same treatment.** The mood-insight feature
asks the model for JSON only, but models don't reliably obey — replies come back
fenced in ```` ```json ````, wrapped in a sentence, or truncated. So the parsing
lives in a pure `AIInsight.parse` and has its own small **eval harness**
(`MoodInsightEvalTests`): golden cases assert that reasonable variants still
decode, and that anything unusable is *rejected* so the caller falls back to a
complete built-in insight instead of rendering a half-empty card. This is the
part most likely to drift as models change, so it's the part I most wanted
pinned by tests.

---

## 7. Things I deliberately did *not* do

- **No third-party packages.** Everything (SSE, audio synthesis, persistence,
  charts-style views) is first-party. For a learning/portfolio project the point
  is to understand the layers, not to assemble them.
- **No accounts / no backend for user data.** Mood and journal data never leave
  the device. This removes a whole class of privacy, auth, and sync problems —
  and is a genuine product stance, not just a shortcut.
- **No audio files.** Soundscapes are synthesised at runtime
  ([`SoundEngine`](Serenity/SoundEngine.swift)) — zero licensing, zero app-size
  cost, infinite length.

---

## 8. What I'd do next

- A provider enum to replace endpoint-string sniffing once a third backend is
  real.
- Snapshot tests for a couple of key views now that the logic layer is covered.

---

*Author: Amir — built end-to-end (SwiftUI architecture, streaming LLM client,
serverless proxy) as a portfolio piece toward a master's in language science &
technology.*
