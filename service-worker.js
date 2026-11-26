const CACHE_NAME = "coi-nguon-shell-v2";
const SHELL_FILES = ["./index.html", "./manifest.webmanifest", "./icons/icon-192.svg", "./icons/icon-512.svg"];
self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(SHELL_FILES.map(path => new URL(path, self.registration.scope).href))).catch(() => {}));
  self.skipWaiting();
});
self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith("coi-nguon-shell-") && key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener("push", event => {
  let payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch (_) {}
  const title = String(payload.title || "Cội Nguồn");
  const options = {
    body: String(payload.body || "Có thông báo mới dành cho gia đình."),
    icon: new URL("./icons/icon-192.svg", self.registration.scope).href,
    badge: new URL("./icons/icon-192.svg", self.registration.scope).href,
    tag: String(payload.tag || "coi-nguon-notification"),
    renotify: false,
    data: { url: String(payload.url || "./index.html?source=push") }
  };
  event.waitUntil(self.registration.showNotification(title, options));
});
self.addEventListener("notificationclick", event => {
  event.notification.close();
  const scope = self.registration.scope;
  let target = new URL("./index.html?source=push", scope).href;
  try {
    const requested = new URL(event.notification.data?.url || target, scope);
    if (requested.origin === self.location.origin && requested.href.startsWith(scope)) target = requested.href;
  } catch (_) {}
  event.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(async clients => {
    const existing = clients.find(client => new URL(client.url).origin === self.location.origin);
    if (existing) {
      await existing.navigate(target);
      return existing.focus();
    }
    return self.clients.openWindow(target);
  }));
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
