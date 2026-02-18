// Firebase Cloud Messaging service worker for background push notifications.
// This runs even when the PWA is closed or the tab is in the background.
//
// IMPORTANT: Update the firebaseConfig below with your Firebase project values
// (must match the config in index.html).

importScripts("https://www.gstatic.com/firebasejs/11.4.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/11.4.0/firebase-messaging-compat.js");

// Firebase config — must match index.html
const firebaseConfig = {
  apiKey: "AIzaSyAHqu53pQGNME24l4XvsZZ3YvT1u--rfxk",
  authDomain: "hisab-c8eb1.firebaseapp.com",
  projectId: "hisab-c8eb1",
  storageBucket: "hisab-c8eb1.firebasestorage.app",
  messagingSenderId: "981938007704",
  appId: "1:981938007704:web:9a607f674d6cdae0b1aaed",
};

function hasPlaceholderFirebaseConfig(config) {
  return Object.values(config).some(
    (v) => typeof v === "string" && v.includes("YOUR_")
  );
}

const isConfigured = !hasPlaceholderFirebaseConfig(firebaseConfig);

if (isConfigured) {
  firebase.initializeApp(firebaseConfig);
}

const messaging = isConfigured ? firebase.messaging() : null;

// Handle background messages (when PWA is closed or tab is backgrounded).
// FCM automatically shows a notification using the `notification` payload field.
// This handler is for custom processing of the `data` payload if needed.
if (messaging) {
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
} else {
  console.warn(
    "[firebase-messaging-sw] Firebase web config uses placeholders; background push notifications are disabled."
  );
}

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
          if ("navigate" in client) {
            client.navigate(targetUrl);
          }
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
