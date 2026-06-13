// Serenity AI proxy — Cloudflare Worker.
//
// Keeps the real provider key OFF the phone: the app calls THIS worker with a
// throwaway app token; the worker checks it, enforces a per-IP daily limit,
// then forwards the request to the provider with the real key (a Worker
// secret). Streaming (SSE) passes straight through.
//
// Deploy: see proxy/README.md. Set secrets UPSTREAM_KEY + APP_TOKEN, bind a KV
// namespace as RL, and (optionally) DAILY_LIMIT.

const UPSTREAM = "https://codex.sale/v1/chat/completions";

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") return cors(new Response(null, { status: 204 }));
    if (request.method !== "POST") return json({ error: { message: "Not found" } }, 404);

    // 1) App token check — blocks random callers.
    const auth = request.headers.get("authorization") || "";
    const token = auth.replace(/^Bearer\s+/i, "").trim();
    if (!env.APP_TOKEN || token !== env.APP_TOKEN) {
      return json({ error: { message: "Unauthorized" } }, 401);
    }

    // 2) Per-IP daily limit — caps your spend if the token ever leaks.
    const limit = parseInt(env.DAILY_LIMIT || "50", 10);
    if (env.RL) {
      const ip = request.headers.get("cf-connecting-ip") || "unknown";
      const day = new Date().toISOString().slice(0, 10);
      const key = `rl:${ip}:${day}`;
      const used = parseInt((await env.RL.get(key)) || "0", 10);
      if (used >= limit) {
        return json({ error: { message: "Daily limit reached. Please try again tomorrow." } }, 429);
      }
      ctx.waitUntil(env.RL.put(key, String(used + 1), { expirationTtl: 90000 }));
    }

    // 3) Forward to the provider with the real key, streaming the reply through.
    const body = await request.text();
    let upstream;
    try {
      upstream = await fetch(UPSTREAM, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "authorization": `Bearer ${env.UPSTREAM_KEY}`,
        },
        body,
      });
    } catch (e) {
      return json({ error: { message: "Upstream unavailable" } }, 502);
    }

    return cors(new Response(upstream.body, {
      status: upstream.status,
      headers: {
        "content-type": upstream.headers.get("content-type") || "application/json",
        "cache-control": "no-cache",
      },
    }));
  },
};

function json(obj, status) {
  return cors(new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json" },
  }));
}

function cors(res) {
  res.headers.set("access-control-allow-origin", "*");
  res.headers.set("access-control-allow-headers", "authorization, content-type");
  res.headers.set("access-control-allow-methods", "POST, OPTIONS");
  return res;
}
