/* =========================================================================
   Cloudflare Worker — compteur de la cagnotte EVG (montant synchronisé)
   -------------------------------------------------------------------------
   GET  /   → lecture PUBLIQUE : { montant, objectif, updated }
   POST /   → écriture PROTÉGÉE : header  Authorization: Bearer <ADMIN_SECRET>
              body JSON { montant: number, objectif?: number }
   Stockage : Cloudflare KV (binding CAGNOTTE_KV).
   Secret   : variable d'env ADMIN_SECRET (jamais dans le repo).
   Déploiement : voir SETUP.md.
   ========================================================================= */

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...CORS },
  });

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });

    // --- Lecture publique ---
    if (request.method === "GET") {
      const montant = Number((await env.CAGNOTTE_KV.get("montant")) || "0");
      const objectif = Number((await env.CAGNOTTE_KV.get("objectif")) || "0");
      const updated = (await env.CAGNOTTE_KV.get("updated")) || null;
      return json({ montant, objectif, updated });
    }

    // --- Écriture protégée ---
    if (request.method === "POST") {
      const auth = request.headers.get("Authorization") || "";
      const token = auth.replace(/^Bearer\s+/i, "");
      if (!env.ADMIN_SECRET || token !== env.ADMIN_SECRET) {
        return json({ error: "Mot de passe invalide" }, 401);
      }
      let body;
      try { body = await request.json(); } catch { return json({ error: "JSON invalide" }, 400); }

      const montant = Number(body.montant);
      if (!Number.isFinite(montant) || montant < 0) {
        return json({ error: "montant invalide" }, 400);
      }
      await env.CAGNOTTE_KV.put("montant", String(Math.round(montant)));
      if (body.objectif != null) {
        const objectif = Number(body.objectif);
        if (Number.isFinite(objectif) && objectif >= 0) {
          await env.CAGNOTTE_KV.put("objectif", String(Math.round(objectif)));
        }
      }
      await env.CAGNOTTE_KV.put("updated", new Date().toISOString());

      const objectif = Number((await env.CAGNOTTE_KV.get("objectif")) || "0");
      return json({ ok: true, montant: Math.round(montant), objectif });
    }

    return json({ error: "Méthode non supportée" }, 405);
  },
};
