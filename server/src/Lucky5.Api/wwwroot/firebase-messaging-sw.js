/* firebase-messaging-sw.js
 * Firebase Cloud Messaging service worker for the Lucky5 web cabinet.
 * The firebaseConfig is injected at runtime via the /api/config/firebase endpoint
 * (or hardcoded below once you have the real values from the Firebase console).
 *
 * To activate: populate FIREBASE_CONFIG below with real values from
 * Firebase Console → Project settings → Your apps → Web app.
 */

importScripts('https://www.gstatic.com/firebasejs/11.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.0/firebase-messaging-compat.js');

// These will be replaced at build/deploy time via environment substitution.
// Temporarily hardcoded as empty — fill in after Firebase project is linked.
const FIREBASE_CONFIG = {
    apiKey: self.LUCKY5_FIREBASE_API_KEY || '',
    authDomain: '',
    projectId: 'lucky5-v7',
    storageBucket: '',
    messagingSenderId: self.LUCKY5_MESSAGING_SENDER_ID || '',
    appId: self.LUCKY5_APP_ID || ''
};

if (FIREBASE_CONFIG.apiKey) {
    firebase.initializeApp(FIREBASE_CONFIG);
    const messaging = firebase.messaging();

    messaging.onBackgroundMessage(function (payload) {
        const { title, body } = payload.notification || {};
        if (title) {
            self.registration.showNotification(title, {
                body: body || '',
                icon: '/assets/images/icon-192.png',
                badge: '/assets/images/icon-72.png',
                data: payload.data
            });
        }
    });
}
