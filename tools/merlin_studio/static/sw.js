/* Service worker MERLIN OS — volontairement MINIMAL.
   Cache-first sur les assets statiques (offline shell + démarrage instantané),
   réseau pur pour tout le reste : /api, /websockify et la page elle-même ne
   sont JAMAIS interceptés — un portail de pilotage ne doit rien montrer de
   périmé, et le flux VNC ne supporte aucun intermédiaire. */
const VERSION = 'merlin-os-v1';
const ASSETS = ['/static/studio.css', '/static/studio.js', '/static/game.js',
                '/static/icon-192.png', '/static/icon-512.png'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
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
  e.respondWith(
    caches.match(e.request).then((hit) => hit ||
      fetch(e.request).then((res) => {
        if (res.ok) { const cp = res.clone(); caches.open(VERSION).then((c) => c.put(e.request, cp)); }
        return res;
      }))
  );
});
