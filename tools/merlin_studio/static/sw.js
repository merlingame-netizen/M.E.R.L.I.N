/* Service worker MERLIN OS — v2.
   LEÇON (bug réel) : cache-first sur du code non fingerprinté a servi un
   studio.js périmé après déploiement — l'onglet Décider restait invisible.
   Désormais : NETWORK-FIRST pour le code et le CSS (la VM est proche, et le
   cache ne sert qu'en secours hors-ligne) ; cache-first seulement pour ce qui
   ne change jamais (icônes, noVNC vendorisé). /api, la page et le VNC ne sont
   JAMAIS interceptés. */
const VERSION = 'merlin-os-v3';
const PRECACHE = ['/static/icon-192.png', '/static/icon-512.png'];
const IMMUTABLE = (p) => p.startsWith('/vendor/') || p.startsWith('/static/icon-');

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin) return;
  if (!url.pathname.startsWith('/static/') && !url.pathname.startsWith('/vendor/')) return;

  if (IMMUTABLE(url.pathname)) {
    e.respondWith(caches.match(e.request).then((hit) => hit ||
      fetch(e.request).then((res) => {
        if (res.ok) { const cp = res.clone(); caches.open(VERSION).then((c) => c.put(e.request, cp)); }
        return res;
      })));
    return;
  }
  // Code & CSS : le réseau d'abord — le cache n'est qu'un secours hors-ligne.
  e.respondWith(
    fetch(e.request).then((res) => {
      if (res.ok) { const cp = res.clone(); caches.open(VERSION).then((c) => c.put(e.request, cp)); }
      return res;
    }).catch(() => caches.match(e.request))
  );
});
