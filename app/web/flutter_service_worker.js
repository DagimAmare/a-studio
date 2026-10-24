// Kill-switch service worker (lesson from Alfam).
// Builds use --pwa-strategy=none, so Flutter never registers an offline
// cache. If any browser still holds an old worker, this one wipes every
// cache, unregisters itself and reloads open tabs, so a fresh deploy wins.
self.addEventListener('install', () => {
  self.skipWaiting();
});
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((k) => caches.delete(k)));
    await self.registration.unregister();
    const clientList = await self.clients.matchAll({ type: 'window' });
    for (const client of clientList) {
      client.navigate(client.url);
    }
  })());
});
