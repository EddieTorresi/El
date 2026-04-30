// Bump BUILD on every release to invalidate the SW cache automatically.
// Keep this string in sync with EL_BUILD in index.html and the
// "<!-- El fix build: ... -->" comment in index.html.
const BUILD = '2026-04-29-bug-fixes-v10';
const EL_CACHE = 'el-pages-' + BUILD;
const APP_SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './el-icon.svg',
  './el-icon-180.png',
  './el-icon-192.png',
  './el-icon-512.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(EL_CACHE)
      .then(cache => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== EL_CACHE).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(response => {
        if (response && response.ok) {
          const copy = response.clone();
          caches.open(EL_CACHE).then(cache => cache.