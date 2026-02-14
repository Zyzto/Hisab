import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const WEB_URL = Deno.env.get("SITE_URL") ?? "https://hisab-c8eb1.web.app";

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token");

  // No token → redirect to error page
  if (!token) {
    return new Response(null, {
      status: 302,
      headers: { "Location": `${WEB_URL}/redirect.html?error=missing` },
    });
  }

  // Validate token server-side
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);
    const { data, error } = await supabase.rpc("get_invite_by_token", {
      p_token: token,
    });

    if (error || !data || data.length === 0) {
      return new Response(null, {
        status: 302,
        headers: { "Location": `${WEB_URL}/redirect.html?error=expired` },
      });
    }
  } catch (_) {
    // If DB check fails, proceed anyway — let the app/web handle it
  }

  // Always 302 redirect to the hosted redirect page.
  // The static page (redirect.html on Firebase Hosting) handles:
  //   - Mobile: try app deep link, fallback to web
  //   - Desktop: immediate redirect to web invite page
  const encodedToken = encodeURIComponent(token);
  return new Response(null, {
    status: 302,
    headers: { "Location": `${WEB_URL}/redirect.html?token=${encodedToken}` },
  });
});
