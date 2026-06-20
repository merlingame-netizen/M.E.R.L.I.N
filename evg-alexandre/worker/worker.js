/* =========================================================================
   Cloudflare Worker — compteur cagnotte EVG (AUTO OnParticipe + override)
   -------------------------------------------------------------------------
   GET  /  → lecture PUBLIQUE : { montant, objectif, source, updated }
             • mode "manual" → renvoie la valeur forcée
             • sinon (auto)  → lit le total sur la page OnParticipe
               (cache KV ~120 s), fallback sur le dernier cache si échec.
   POST /  → écriture PROTÉGÉE : Authorization: Bearer <ADMIN_SECRET>
             • { montant, objectif? } → force une valeur (mode manuel)
             • { mode: "auto" }        → repasse en lecture auto OnParticipe
   Stockage : KV (binding CAGNOTTE_KV). Source auto : env ONPARTICIPE_URL.
   Secret   : env ADMIN_SECRET (jamais dans le repo). Déploiement : ../SETUP.md
   ========================================================================= */

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};
const TTL_MS = 120000;            // fraîcheur du cache auto
const FALLBACK = { montant: 0, objectif: 750 };

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...CORS },
  });

const onlyDigits = (s) => parseInt(String(s).replace(/[^\d]/g, ""), 10) || 0;

// Extrait "Objectif : 0 € / 750 €" (montant / objectif) du HTML OnParticipe.
function parseOnParticipe(html) {
  const clean = html.replace(/&nbsp;/g, " ").replace(/ /g, " ");
  const m = clean.match(/Objectif\s*:\s*([\d\s.,]+?)\s*€\s*\/\s*([\d\s.,]+?)\s*€/i);
  if (!m) return null;
  return { montant: onlyDigits(m[1]), objectif: onlyDigits(m[2]) };
}

async function fetchAuto(env) {
  const url = env.ONPARTICIPE_URL;
  if (!url) return null;
  const r = await fetch(url, {
    headers: { "User-Agent": "Mozilla/5.0 (cagnotte-evg-sync)" },
    cf: { cacheTtl: 60 },
  });
  if (!r.ok) return null;
  return parseOnParticipe(await r.text());
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });

    // ----------------- LECTURE PUBLIQUE -----------------
    if (request.method === "GET") {
      const mode = await env.CAGNOTTE_KV.get("mode");
      const updated = (await env.CAGNOTTE_KV.get("updated")) || null;

      if (mode === "manual") {
        const montant = Number((await env.CAGNOTTE_KV.get("m_montant")) || "0");
        const objectif = Number(
          (await env.CAGNOTTE_KV.get("m_objectif")) ||
          (await env.CAGNOTTE_KV.get("c_objectif")) ||
          String(FALLBACK.objectif)
        );
        return json({ montant, objectif, source: "manual", updated });
      }

      // auto : cache puis scrape
      const ts = Number((await env.CAGNOTTE_KV.get("c_ts")) || "0");
      const cMontant = await env.CAGNOTTE_KV.get("c_montant");
      if (cMontant !== null && Date.now() - ts < TTL_MS) {
        const objectif = Number((await env.CAGNOTTE_KV.get("c_objectif")) || String(FALLBACK.objectif));
        return json({ montant: Number(cMontant), objectif, source: "auto-cache", updated });
      }
      try {
        const data = await fetchAuto(env);
        if (data) {
          await env.CAGNOTTE_KV.put("c_montant", String(data.montant));
          await env.CAGNOTTE_KV.put("c_objectif", String(data.objectif));
          await env.CAGNOTTE_KV.put("c_ts", String(Date.now()));
          return json({ ...data, source: "auto", updated });
        }
      } catch (e) { /* on tombe sur le secours */ }

      // secours : dernier cache connu sinon valeurs par défaut
      if (cMontant !== null) {
        const objectif = Number((await env.CAGNOTTE_KV.get("c_objectif")) || String(FALLBACK.objectif));
        return json({ montant: Number(cMontant), objectif, source: "auto-stale", updated });
      }
      return json({ ...FALLBACK, source: "fallback", updated });
    }

    // ----------------- ÉCRITURE PROTÉGÉE -----------------
    if (request.method === "POST") {
      const token = (request.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
      if (!env.ADMIN_SECRET || token !== env.ADMIN_SECRET) {
        return json({ error: "Mot de passe invalide" }, 401);
      }
      let body;
      try { body = await request.json(); } catch { return json({ error: "JSON invalide" }, 400); }

      // repasser en auto
      if (body.mode === "auto") {
        await env.CAGNOTTE_KV.delete("mode");
        await env.CAGNOTTE_KV.delete("m_montant");
        await env.CAGNOTTE_KV.delete("m_objectif");
        await env.CAGNOTTE_KV.delete("c_ts"); // force un refetch immédiat
        await env.CAGNOTTE_KV.put("updated", new Date().toISOString());
        return json({ ok: true, mode: "auto" });
      }

      // forcer une valeur (manuel)
      const montant = Number(body.montant);
      if (!Number.isFinite(montant) || montant < 0) {
        return json({ error: "montant invalide" }, 400);
      }
      await env.CAGNOTTE_KV.put("mode", "manual");
      await env.CAGNOTTE_KV.put("m_montant", String(Math.round(montant)));
      if (body.objectif != null && Number.isFinite(Number(body.objectif))) {
        await env.CAGNOTTE_KV.put("m_objectif", String(Math.round(Number(body.objectif))));
      }
      await env.CAGNOTTE_KV.put("updated", new Date().toISOString());
      const objectif = Number(
        (await env.CAGNOTTE_KV.get("m_objectif")) ||
        (await env.CAGNOTTE_KV.get("c_objectif")) ||
        String(FALLBACK.objectif)
      );
      return json({ ok: true, mode: "manual", montant: Math.round(montant), objectif });
    }

    return json({ error: "Méthode non supportée" }, 405);
  },
};
