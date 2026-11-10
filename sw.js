// Keeps Gift Keeper working offline: serve from the network when we can, the cache when we can't.
const CACHE = 'gift-keeper-v3';
const FILES = ['app.html', 'manifest.webmanifest', 'img/icon-192.png', 'img/icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(fetch(e.request).then(res => {
    if (res.status === 200 && new URL(e.request.url).origin === location.origin) {   // not 206 video ranges — the cache can't store those
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(e.request, copy));
    }
    return res;
  }).catch(() => caches.match(e.request, { ignoreSearch: true })));
});
