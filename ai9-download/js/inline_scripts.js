
        // Suppress all console output in production (non-localhost)
        (function () {
          var isLocalDev = (
            window.location.hostname === 'localhost' ||
            window.location.hostname === '127.0.0.1' ||
            window.location.hostname === ''
          );
          if (!isLocalDev) {
            var noop = function () {};
            ['log', 'warn', 'info', 'debug', 'trace', 'dir', 'table',
             'group', 'groupCollapsed', 'groupEnd', 'time', 'timeEnd', 'error']
              .forEach(function (m) {
                if (typeof window.console[m] === 'function') {
                  window.console[m] = noop;
                }
              });
          }
        })();
    


        function removeSplashFromWeb() {
          document.getElementById("splash")?.remove();
          document.getElementById("splash-branding")?.remove();
          document.body.style.background = "transparent";
        }
    


    var scriptLoaded = false;

    function loadMainDartJs() {
      if (scriptLoaded) return;
      scriptLoaded = true;
      var scriptTag = document.createElement("script");
      // ADD VERSION PARAMETER HERE - Change this number with each deployment
      scriptTag.src = "main.dart.js?v=1.0.4." + Date.now();
      scriptTag.type = "application/javascript";
      document.body.appendChild(scriptTag);
    }

    function removeLoader() {
      var loader = document.getElementById("loading-container");
      if (loader) {
        loader.style.display = "none";
      }
    }

    window.addEventListener("flutter-first-frame", function () {
      removeLoader();
      window.parent.postMessage({ type: "LOADING_COMPLETED", }, "*");
    });

    loadMainDartJs();



    // Navigation tracking
    (function (history) {
      const pushState = history.pushState;
      const replaceState = history.replaceState;

      function logNavigation(method, url) {
        // console.log(`[IN FLUTTER APP] - Navigated (${method}): ${url}`);
        window.parent.postMessage({ type: "NAVIGATION", method, url }, "*");
      }

      history.pushState = function (state, title, url) {
        logNavigation("pushState", url);
        return pushState.apply(history, arguments);
      };

      history.replaceState = function (state, title, url) {
        logNavigation("replaceState", url);
        return replaceState.apply(history, arguments);
      };

      window.addEventListener("popstate", function (event) {
        logNavigation("popstate", location.href);
      });
    })(window.history);



    let deferredPrompt;

    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      deferredPrompt = e;
    });

    window.addEventListener('appinstalled', () => {
      deferredPrompt = null;
    });


          var toastElement = Toastify({
            text: 'Invalid phone number or password',
            gravity: 'top',
            position: 'right',
            duration: 1000,
            close: false,
            backgroundColor: "linear-gradient(to right, #00b09b, #96c93d)",
          });
          toastElement.showToast();
        