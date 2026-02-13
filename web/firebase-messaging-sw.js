// Firebase Cloud Messaging service worker for background push notifications.
// This runs even when the PWA is closed or the tab is in the background.
//
// IMPORTANT: Update the firebaseConfig below with your Firebase project values
// (must match the config in index.html).

importScripts("https://www.gstatic.com/firebasejs/11.4.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/11.4.0/firebase-messaging-compat.js");

// Firebase config — must match index.html
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.firebasestorage.app",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_APP_ID",
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Handle background messages (when PWA is closed or tab is backgrounded).
// FCM automatically shows a notification using the `notification` payload field.
// This handler is for custom processing of the `data` payload if needed.
messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw] Background message:", payload);

  // If FCM already shows a notification (via `notification` field), skip.
  if (payload.notification) {
    return;
  }

  // Fallback: show notification from data payload
  const data = payload.data || {};
  const title = data.title || "Hisab";
  const body = data.body || "You have a new notification";

  return self.registration.showNotification(title, {
    body: body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: data,
  });
});

// Handle notification click — open or focus the app and navigate to the group
self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const data = event.notification.data || {};
  const groupId = data.group_id;

  // Build the URL to navigate to
  let targetUrl = "/";
  if (groupId) {
    targetUrl = `/groups/${groupId}`;
  }

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      // If the app is already open, focus it and navigate
      for (const client of clientList) {
        if ("focus" in client) {
          client.focus();
          client.postMessage({ type: "NOTIFICATION_CLICK", url: targetUrl });
          return;
        }
      }
      // Otherwise, open a new window
      return clients.openWindow(targetUrl);
    })
  );
});
