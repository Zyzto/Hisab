/**
 * Hisab in-app browser gate helpers.
 * Detects messaging/social WebViews and helps users escape to Safari/Chrome
 * before Flutter CanvasKit boots (which often hangs in those WebViews).
 */
(function (global) {
  "use strict";

  // Note: do not use bare "X/" — it false-positives on Firefox/NNN (the "x/" in "Firefox/").
  var NAMED_APP_RE =
    /Instagram|FBAN|FBAV|FB_IAB|FBIOS|FBSS|Messenger|WhatsApp|Line\/|MicroMessenger|WeChat|TikTok|musical_ly|BytedanceWebview|Snapchat|LinkedInApp|Twitter|Reddit|Threads/i;

  var strings = {
    en: {
      title: "Open in your browser",
      heading: "Open in your browser",
      message:
        "This in-app browser cannot run Hisab reliably. Open the link in Safari or Chrome to continue.",
      openBrowser: "Open in Safari / Chrome",
      copyLink: "Copy link",
      copied: "Link copied",
      iosHint: "Or tap ··· (top right) → Open in Safari / Chrome.",
      androidHint: "If nothing happens, copy the link and paste it in Chrome.",
      lastResort: "Still stuck? Copy the link and paste it in your browser."
    },
    ar: {
      title: "افتح في المتصفح",
      heading: "افتح في المتصفح",
      message:
        "متصفح التطبيق لا يشغّل حساب بشكل موثوق. افتح الرابط في Safari أو Chrome للمتابعة.",
      openBrowser: "فتح في Safari / Chrome",
      copyLink: "نسخ الرابط",
      copied: "تم نسخ الرابط",
      iosHint: "أو اضغط ··· (أعلى اليمين) ← فتح في Safari / Chrome.",
      androidHint: "إذا لم يحدث شيء، انسخ الرابط والصقه في Chrome.",
      lastResort: "ما زلت عالقًا؟ انسخ الرابط والصقه في متصفحك."
    }
  };

  function ua() {
    return (global.navigator && global.navigator.userAgent) || "";
  }

  function locale() {
    try {
      var lang = (global.navigator && global.navigator.language) || "en";
      return String(lang).toLowerCase().indexOf("ar") === 0 ? "ar" : "en";
    } catch (_) {
      return "en";
    }
  }

  function t() {
    return strings[locale()] || strings.en;
  }

  function isStandalone() {
    try {
      if (global.matchMedia) {
        if (global.matchMedia("(display-mode: standalone)").matches) return true;
        if (global.matchMedia("(display-mode: fullscreen)").matches) return true;
        if (global.matchMedia("(display-mode: minimal-ui)").matches) return true;
      }
    } catch (_) {}
    if (global.navigator && global.navigator.standalone) return true;
    try {
      var ref = global.document && global.document.referrer;
      if (typeof ref === "string" && ref.indexOf("android-app://") === 0) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  function isAndroid() {
    return /android/i.test(ua());
  }

  function isIOS() {
    var u = ua();
    if (/iphone|ipad|ipod/i.test(u)) return true;
    // iPadOS 13+ may report as Macintosh with touch.
    try {
      if (
        /macintosh/i.test(u) &&
        global.navigator &&
        global.navigator.maxTouchPoints > 1
      ) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  function isMobile() {
    return isAndroid() || isIOS() || /mobile/i.test(ua());
  }

  function isInAppBrowser() {
    if (isStandalone()) return false;
    var u = ua();
    if (!u) return false;
    if (NAMED_APP_RE.test(u)) return true;
    // Android System WebView marker (Chrome Custom Tabs usually omit this).
    if (isAndroid() && /;\s*wv\)/i.test(u)) return true;
    return false;
  }

  function androidChromeIntent(httpsUrl) {
    try {
      var parsed = new URL(httpsUrl, global.location && global.location.href);
      if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
        return httpsUrl;
      }
      var full = parsed.toString();
      // Hash fragments must not appear before "#Intent" or the Intent parser breaks.
      // Prefer Chrome navigate when a hash is present (preserves #access_token etc.).
      if (parsed.hash) {
        return "googlechrome://navigate?url=" + encodeURIComponent(full);
      }
      var hostAndPath = parsed.host + parsed.pathname + parsed.search;
      return (
        "intent://" +
        hostAndPath +
        "#Intent;scheme=" +
        parsed.protocol.replace(":", "") +
        ";package=com.android.chrome" +
        ";S.browser_fallback_url=" +
        encodeURIComponent(full) +
        ";end"
      );
    } catch (_) {
      return httpsUrl;
    }
  }

  function iosSafariUrl(httpsUrl) {
    try {
      var parsed = new URL(httpsUrl, global.location && global.location.href);
      if (parsed.protocol === "https:") {
        return "x-safari-https://" + parsed.host + parsed.pathname + parsed.search + parsed.hash;
      }
      if (parsed.protocol === "http:") {
        return "x-safari-http://" + parsed.host + parsed.pathname + parsed.search + parsed.hash;
      }
    } catch (_) {}
    return httpsUrl;
  }

  function escapeUrl(httpsUrl) {
    if (isAndroid()) return androidChromeIntent(httpsUrl);
    if (isIOS()) return iosSafariUrl(httpsUrl);
    return httpsUrl;
  }

  function openInSystemBrowser(httpsUrl) {
    var target = escapeUrl(httpsUrl);
    try {
      global.location.href = target;
    } catch (_) {
      try {
        global.open(httpsUrl, "_blank");
      } catch (__) {}
    }
  }

  function copyLink(httpsUrl) {
    if (
      global.navigator &&
      global.navigator.clipboard &&
      typeof global.navigator.clipboard.writeText === "function"
    ) {
      return global.navigator.clipboard.writeText(httpsUrl).then(
        function () {
          return true;
        },
        function () {
          return fallbackCopy(httpsUrl);
        }
      );
    }
    return Promise.resolve(fallbackCopy(httpsUrl));
  }

  function fallbackCopy(text) {
    try {
      var ta = global.document.createElement("textarea");
      ta.value = text;
      ta.setAttribute("readonly", "");
      ta.style.cssText = "position:fixed;left:-9999px;top:0";
      global.document.body.appendChild(ta);
      ta.select();
      var ok = global.document.execCommand("copy");
      global.document.body.removeChild(ta);
      return !!ok;
    } catch (_) {
      return false;
    }
  }

  /**
   * Mount a clickable interstitial. Does not navigate same-WebView as primary CTA.
   * @param {{ targetUrl: string, container?: HTMLElement, onMounted?: function }} opts
   */
  function mountGate(opts) {
    opts = opts || {};
    var targetUrl = opts.targetUrl || (global.location && global.location.href) || "";
    var container = opts.container || null;
    var copy = t();
    var root = global.document.createElement("div");
    root.id = "hisab-inapp-gate";
    root.setAttribute("role", "dialog");
    root.setAttribute("aria-modal", "true");
    root.setAttribute("aria-labelledby", "hisab-inapp-heading");

    var hint = isIOS() ? copy.iosHint : isAndroid() ? copy.androidHint : copy.lastResort;

    root.innerHTML =
      '<div class="hisab-inapp-card">' +
      '<img class="hisab-inapp-logo" src="/icons/Icon-192.png" alt="Hisab">' +
      '<h3 id="hisab-inapp-heading">' +
      escapeHtml(copy.heading) +
      "</h3>" +
      "<p>" +
      escapeHtml(copy.message) +
      "</p>" +
      '<button type="button" class="hisab-inapp-btn hisab-inapp-btn-primary" id="hisab-inapp-open">' +
      escapeHtml(copy.openBrowser) +
      "</button>" +
      '<button type="button" class="hisab-inapp-btn hisab-inapp-btn-outline" id="hisab-inapp-copy">' +
      escapeHtml(copy.copyLink) +
      "</button>" +
      '<p class="hisab-inapp-hint">' +
      escapeHtml(hint) +
      "</p>" +
      '<p class="hisab-inapp-hint" id="hisab-inapp-copy-status" style="display:none"></p>' +
      "</div>";

    ensureStyles();

    if (container) {
      container.innerHTML = "";
      container.appendChild(root);
    } else if (global.document.body) {
      global.document.body.appendChild(root);
    }

    try {
      global.document.documentElement.lang = locale();
      global.document.documentElement.dir = locale() === "ar" ? "rtl" : "ltr";
      global.document.title = copy.title;
    } catch (_) {}

    var openBtn = root.querySelector("#hisab-inapp-open");
    var copyBtn = root.querySelector("#hisab-inapp-copy");
    var statusEl = root.querySelector("#hisab-inapp-copy-status");

    if (openBtn) {
      openBtn.addEventListener("click", function (e) {
        e.preventDefault();
        openInSystemBrowser(targetUrl);
      });
    }
    if (copyBtn) {
      copyBtn.addEventListener("click", function (e) {
        e.preventDefault();
        copyLink(targetUrl).then(function (ok) {
          if (!statusEl) return;
          statusEl.style.display = "block";
          statusEl.textContent = ok ? copy.copied : copy.lastResort;
        });
      });
    }

    if (typeof opts.onMounted === "function") {
      try {
        opts.onMounted(root);
      } catch (_) {}
    }
    return root;
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function ensureStyles() {
    if (global.document.getElementById("hisab-inapp-styles")) return;
    var style = global.document.createElement("style");
    style.id = "hisab-inapp-styles";
    style.textContent =
      "#hisab-inapp-gate{position:fixed;inset:0;z-index:10000;display:flex;align-items:center;justify-content:center;padding:20px;box-sizing:border-box;background:#fafafa;color:#333;pointer-events:auto;font-family:-apple-system,system-ui,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;text-align:center}" +
      "@media (prefers-color-scheme:dark){#hisab-inapp-gate{background:#1a1a1a;color:#eee}}" +
      ".hisab-inapp-card{max-width:360px;width:100%;padding:40px 24px;background:#fff;border-radius:16px;box-shadow:0 2px 12px rgba(0,0,0,.08);box-sizing:border-box}" +
      "@media (prefers-color-scheme:dark){.hisab-inapp-card{background:#2d2d2d}}" +
      ".hisab-inapp-logo{display:block;max-width:72px;max-height:72px;margin:0 auto 20px}" +
      "#hisab-inapp-gate h3{font-size:1.25rem;margin:0 0 8px;color:inherit}" +
      "#hisab-inapp-gate p{color:#666;margin:0 0 20px;font-size:.95rem}" +
      "@media (prefers-color-scheme:dark){#hisab-inapp-gate p{color:#aaa}}" +
      ".hisab-inapp-btn{display:block;width:100%;padding:12px 24px;border-radius:8px;font-weight:600;font-size:.95rem;cursor:pointer;box-sizing:border-box;margin:0 0 12px}" +
      ".hisab-inapp-btn-primary{background:#22c55e;color:#fff;border:none}" +
      ".hisab-inapp-btn-primary:hover{background:#16a34a}" +
      ".hisab-inapp-btn-outline{background:transparent;color:#22c55e;border:2px solid #22c55e}" +
      ".hisab-inapp-hint{font-size:.85rem!important;margin-top:8px!important;margin-bottom:0!important}";
    (global.document.head || global.document.documentElement).appendChild(style);
  }

  global.HisabInApp = {
    strings: strings,
    locale: locale,
    t: t,
    isStandalone: isStandalone,
    isAndroid: isAndroid,
    isIOS: isIOS,
    isMobile: isMobile,
    isInAppBrowser: isInAppBrowser,
    escapeUrl: escapeUrl,
    openInSystemBrowser: openInSystemBrowser,
    copyLink: copyLink,
    mountGate: mountGate
  };
})(typeof window !== "undefined" ? window : this);
