// M.E.R.L.I.N. — Cloudflare Worker backed by D1 (SQLite) + Workers AI. Free plan, 24/7.
// Routes:
//   GET  /health        -> {ok:true} (used by the fleet dashboard)
//   GET  /items         -> list rows
//   POST /items {key,value} -> upsert a row
//   POST /ai/generate {biome,task} -> a scenario card via Workers AI (free Neurons)
// D1 is SQLite-compatible: a free, always-on store for small services.

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });

const FACTIONS = ["druides", "anciens", "korrigans", "niamh", "ankou"];
const AI_MODEL = "@cf/meta/llama-3.1-8b-instruct";

function extractJson(text) {
  try { return JSON.parse(text); } catch {}
  const m = String(text || "").match(/\{[\s\S]*\}/);
  if (m) { try { return JSON.parse(m[0]); } catch {} }
  return null;
}

async function generateCard(env, body) {
  const biome = (body && body.biome) || "Brocéliande";
  const sys =
    "Tu es M.E.R.L.I.N., conteur druidique. Réponds UNIQUEMENT par un objet JSON, sans texte autour.";
  const user =
    `Génère une carte de jeu narrative pour le biome "${biome}".\n` +
    `Format STRICT: {"text": string, "options": [{"label": string, "verb": string, ` +
    `"effects": [{"type":"ADD_REPUTATION","faction":string,"amount":number}]}]}.\n` +
    `Règles: text = 2 à 4 phrases françaises (40-120 mots), ton druidique celtique, AUCUN mot moderne ` +
    `(pas de "simulation","programme","IA"). EXACTEMENT 3 options. verb à l'infinitif. ` +
    `faction ∈ {${FACTIONS.join(",")}}. amount entre -20 et 20. Pas de commentaire hors JSON.`;
  const out = await env.AI.run(AI_MODEL, {
    messages: [{ role: "system", content: sys }, { role: "user", content: user }],
    max_tokens: 400,
  });
  const card = extractJson(out.response || out.result || "");
  return { card, model: AI_MODEL, biome };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;

    if (pathname === "/health") {
      return json({ ok: true, service: "merlin-svc", store: "d1-sqlite", ai: !!env.AI });
    }

    if (pathname === "/ai/generate" && request.method === "POST") {
      if (!env.AI) return json({ error: "Workers AI binding not configured" }, 501);
      // optional shared-secret guard (set: wrangler secret put GEN_TOKEN)
      if (env.GEN_TOKEN) {
        const tok = request.headers.get("x-gen-token") || "";
        if (tok !== env.GEN_TOKEN) return json({ error: "unauthorized" }, 401);
      }
      let body = {};
      try { body = await request.json(); } catch {}
      try {
        const res = await generateCard(env, body);
        return json(res, res.card ? 200 : 502);
      } catch (e) {
        return json({ error: String(e) }, 500);
      }
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
