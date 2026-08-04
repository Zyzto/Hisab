import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const WEB_URL = Deno.env.get("SITE_URL") ?? "https://hisab.shenepoy.com";

function redirect(location: string): Response {
  return new Response(null, {
    status: 302,
    headers: { Location: location },
  });
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token");

  if (!token) {
    return redirect(`${WEB_URL}/redirect.html?error=missing`);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);
    const { data, error } = await supabase.rpc("get_invite_by_token", {
      p_token: token,
    });

    if (error || !data || data.length === 0) {
      return redirect(`${WEB_URL}/redirect.html?error=expired`);
    }
  } catch (e) {
    console.error("invite-redirect: validation failed", e);
    return redirect(`${WEB_URL}/redirect.html?error=expired`);
  }

  const encodedToken = encodeURIComponent(token);
  return redirect(`${WEB_URL}/redirect.html?token=${encodedToken}`);
});
