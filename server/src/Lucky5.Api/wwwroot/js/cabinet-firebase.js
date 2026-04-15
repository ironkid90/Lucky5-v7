/**
 * cabinet-firebase.js  — Firebase Web SDK integration for Lucky5 web cabinet.
 * Handles: FCM token registration, foreground push notifications.
 * Loaded after game.js. Falls back gracefully if Firebase is not configured.
 *
 * Fill in FIREBASE_CONFIG below once the Firebase project is linked, OR
 * expose window.LUCKY5_FIREBASE_CONFIG from a server-rendered snippet.
 */
window.CabinetFirebase = (function () {
    const CONFIG = window.LUCKY5_FIREBASE_CONFIG || null;
    let _messaging = null;
    let _initialized = false;

    async function init() {
        if (!CONFIG || !CONFIG.apiKey) {
            console.info('[Firebase] Not configured — push notifications disabled.');
            return;
        }

        try {
            const { initializeApp } = await import('https://www.gstatic.com/firebasejs/11.0.0/firebase-app.js');
            const { getMessaging, getToken, onMessage } = await import('https://www.gstatic.com/firebasejs/11.0.0/firebase-messaging.js');

            const app = initializeApp(CONFIG);
            _messaging = getMessaging(app);
            _initialized = true;

            onMessage(_messaging, (payload) => {
                const { title, body } = payload.notification || {};
                if (title) _showInAppBanner(title, body || '');
            });

            await _registerToken();
        } catch (err) {
            console.warn('[Firebase] Init error:', err.message);
        }
    }

    async function _registerToken() {
        try {
            const reg = await navigator.serviceWorker.register('/firebase-messaging-sw.js');
            const { getMessaging, getToken } = await import('https://www.gstatic.com/firebasejs/11.0.0/firebase-messaging.js');
            const token = await getToken(_messaging, {
                vapidKey: CONFIG.vapidKey,
                serviceWorkerRegistration: reg
            });
            if (token) {
                await apiCall('POST', '/api/Notification/register-device', { Token: token, Platform: 'web' });
                console.info('[Firebase] FCM token registered');
            }
        } catch (err) {
            console.warn('[Firebase] Token registration failed:', err.message);
        }
    }

    function _showInAppBanner(title, body) {
        const banner = document.createElement('div');
        banner.style.cssText = [
            'position:fixed;top:16px;right:16px;z-index:9999',
            'background:#1a472a;border:2px solid #ffd700;border-radius:8px',
            'padding:12px 16px;color:#fff;font-family:monospace;max-width:280px',
            'box-shadow:0 4px 16px rgba(0,0,0,0.4);cursor:pointer'
        ].join(';');
        banner.innerHTML = `<strong style="color:#ffd700">${title}</strong><div style="font-size:12px;margin-top:4px">${body}</div>`;
        banner.onclick = () => banner.remove();
        document.body.appendChild(banner);
        setTimeout(() => banner.remove(), 6000);
    }

    return { init };
})();
