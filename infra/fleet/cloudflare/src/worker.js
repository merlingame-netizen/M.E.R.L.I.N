// M.E.R.L.I.N. — Cloudflare Worker backed by D1 (SQLite). Free plan, 24/7.
// Routes:
//   GET  /health        -> {ok:true} (used by the fleet dashboard)
//   GET  /items         -> list rows
//   POST /items {key,value} -> upsert a row
// D1 is SQLite-compatible: a free, always-on store for small services.

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;

    if (pathname === "/health") {
      return json({ ok: true, service: "merlin-svc", store: "d1-sqlite" });
    }

    if (pathname === "/items" && request.method === "GET") {
      const { results } = await env.DB.prepare(
        "SELECT key, value, updated_at FROM items ORDER BY updated_at DESC LIMIT 100"
      ).all();
      return json({ items: results });
    }

    if (pathname === "/items" && request.method === "POST") {
      let body;
      try { body = await request.json(); } catch { return json({ error: "invalid json" }, 400); }
      if (!body.key) return json({ error: "key required" }, 400);
      await env.DB.prepare(
        "INSERT INTO items (key, value, updated_at) VALUES (?1, ?2, unixepoch()) " +
        "ON CONFLICT(key) DO UPDATE SET value=?2, updated_at=unixepoch()"
      ).bind(body.key, body.value ?? "").run();
      return json({ ok: true, key: body.key });
    }

    return json({ error: "not found" }, 404);
  },
};
