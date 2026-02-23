import { onRequest } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";

const supabaseUrl = defineString("SUPABASE_URL");
const siteUrl = defineString("SITE_URL");

const OG_TITLE = "Hisab – Group invite";
const OG_DESCRIPTION =
  "You're invited to join a group in Hisab. Open the link to accept.";

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function buildHtml(token: string | null, baseUrl: string, site: string): string {
  const hasToken = token && token.length > 0 && token.length <= 512;
  const supabaseBase = baseUrl.replace(/\/$/, "");
  const ogImageUrl = hasToken
    ? `${supabaseBase}/functions/v1/og-invite-image?token=${encodeURIComponent(token!)}`
    : `${site.replace(/\/$/, "")}/og-invite.png`;
  const canonicalUrl = hasToken
    ? `${site.replace(/\/$/, "")}/functions/v1/invite-redirect?token=${encodeURIComponent(token!)}`
    : `${site.replace(/\/$/, "")}/functions/v1/invite-redirect`;

  return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>${escapeHtml(OG_TITLE)}</title>
<meta property="og:type" content="website">
<meta property="og:title" content="${escapeHtml(OG_TITLE)}">
<meta property="og:description" content="${escapeHtml(OG_DESCRIPTION)}">
<meta property="og:image" content="${escapeHtml(ogImageUrl)}">
<meta property="og:url" content="${escapeHtml(canonicalUrl)}">
<meta property="og:site_name" content="Hisab">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(OG_TITLE)}">
<meta name="twitter:description" content="${escapeHtml(OG_DESCRIPTION)}">
<meta name="twitter:image" content="${escapeHtml(ogImageUrl)}">
<script>
(function() {
  var base = "${escapeHtml(supabaseBase)}";
  var target = base + "/functions/v1/invite-redirect" + (window.location.search || "");
  window.location.replace(target);
})();
</script>
</head>
<body>
<p>Redirecting...</p>
</body>
</html>`;
}

export const inviteRedirectPage = onRequest(
  {
    region: "us-central1",
  },
  (req, res) => {
    const base = supabaseUrl.value();
    const site = siteUrl.value();
    const rawToken = req.query?.token;
    const token: string | null =
      typeof rawToken === "string"
        ? rawToken
        : Array.isArray(rawToken) && typeof rawToken[0] === "string"
          ? rawToken[0]
          : null;

    if (!token || token.length === 0 || token.length > 512) {
      res.redirect(302, `${site.replace(/\/$/, "")}/redirect.html?error=missing`);
      return;
    }

    res.setHeader("Content-Type", "text/html; charset=utf-8");
    res.setHeader("Cache-Control", "public, max-age=0");
    res.status(200).send(buildHtml(token, base, site));
  }
);
