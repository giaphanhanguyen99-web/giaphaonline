const CACHE_NAME = "coi-nguon-shell-v1";
const SHELL_FILES = ["./index.html", "./manifest.webmanifest", "./icons/icon-192.svg", "./icons/icon-512.svg"];
self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(SHELL_FILES.map(path => new URL(path, self.registration.scope).href))).catch(() => {}));
  self.skipWaiting();
});
self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith("coi-nguon-shell-") && key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener("fetch", event => {
  const request = event.request, url = new URL(request.url), scope = self.registration.scope;
  if (request.method !== "GET" || url.origin !== self.location.origin || !url.href.startsWith(scope)) return;
  if (request.mode === "navigate") {
    event.respondWith(fetch(request).then(response => {
      if (response.ok) { const copy = response.clone(); caches.open(CACHE_NAME).then(cache => cache.put(request, copy)); }
      return response;
    }).catch(async () => (await caches.match(request)) || (await caches.match(new URL("./index.html", scope).href))));
    return;
  }
  event.respondWith(caches.match(request).then(cached => cached || fetch(request).then(response => {
    if (response.ok) { const copy = response.clone(); caches.open(CACHE_NAME).then(cache => cache.put(request, copy)); }
    return response;
  })));
});
