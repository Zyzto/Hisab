// Service worker that re-serves .wasm with Content-Type: application/wasm
// (dev server often serves it as application/octet-stream).
// IMPORTANT: Do a full page reload (F5 / Ctrl+R) once so this SW registers.
self.addEventListener('install', function () {
  self.skipWaiting();
});
self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});
self.addEventListener('fetch', function (event) {
  var url = event.request.url;
  // Match any .wasm request (main thread or worker; may have query string)
  if (event.request.method !== 'GET' || url.indexOf('.wasm') === -1) return;
  event.respondWith(
    fetch(event.request)
      .then(function (response) {
        if (!response.ok) return response;
        return response.blob().then(function (blob) {
          return new Response(blob, {
            status: 200,
            statusText: response.statusText,
            headers: new Headers({ 'Content-Type': 'application/wasm' }),
          });
        });
      })
      .catch(function () {
        return fetch(event.request);
      })
  );
});
