# Serenity AI proxy (Cloudflare Workers)

Keeps the real provider key off the phone and caps your spending. The app calls
the worker with a throwaway app token; the worker adds the real key and enforces
a per-IP daily request limit.

## Why
Right now the real `codex.sale` key is bundled (obfuscated) in the app. Anyone
who extracts it can spend your balance. With this proxy:
- the binary ships only a harmless **app token**, not the real key;
- a **daily limit** caps cost even if the token leaks;
- streaming (token-by-token chat) still works.

## One-time setup (free tier is plenty)

1. Create a free account at https://dash.cloudflare.com and install the CLI:
   ```
   npm install -g wrangler
   wrangler login
   ```

2. From this `proxy/` folder, create the project files. A minimal
   `wrangler.toml`:
   ```toml
   name = "serenity-proxy"
   main = "worker.js"
   compatibility_date = "2024-11-01"

   kv_namespaces = [{ binding = "RL", id = "PUT_KV_ID_HERE" }]

   [vars]
   DAILY_LIMIT = "50"
   ```

3. Create the KV namespace for rate-limiting and copy its id into `wrangler.toml`:
   ```
   wrangler kv namespace create RL
   ```

4. Set the secrets (these are NOT stored in code):
   ```
   wrangler secret put UPSTREAM_KEY     # paste your real codex.sale key
   wrangler secret put APP_TOKEN        # invent any random string, e.g. 32 chars
   ```

5. Deploy:
   ```
   wrangler deploy
   ```
   You'll get a URL like `https://serenity-proxy.<you>.workers.dev`.

## Point the app at the proxy

Edit `Serenity/Secrets.swift` (gitignored):
```swift
static let defaultEndpoint = "https://serenity-proxy.<you>.workers.dev"
static let defaultModel    = "gpt-5.4-mini"
// Put your APP_TOKEN here (NOT the real provider key) and regenerate the
// obfuscated bytes the same way as before.
```
The app sends `Authorization: Bearer <APP_TOKEN>`; the worker swaps it for the
real key. Now the real key never ships in the binary.

## Tune the limit
Change `DAILY_LIMIT` in `wrangler.toml` (requests per IP per day) and redeploy.
For a friends-only beta, 30–50 is plenty.
