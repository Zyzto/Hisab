import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsPreflightResponse } from "../_shared/cors.ts";
import { jsonResponse } from "../_shared/http.ts";
import { validateTelemetryBody } from "../_shared/telemetry_validate.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return corsPreflightResponse();
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const apikey = req.headers.get("apikey")?.trim();
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!apikey || !anonKey || apikey !== anonKey) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  try {
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return jsonResponse({ error: "Invalid JSON body" }, 400);
    }

    const validated = validateTelemetryBody(body);
    if (!validated.ok) {
      return jsonResponse({ error: validated.error }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    // Anon client so telemetry_insert RLS applies (never service role).
    const supabase = createClient(supabaseUrl, anonKey);

    const { error } = await supabase.from("telemetry").insert({
      event: validated.value.event,
      timestamp: validated.value.timestamp,
      data: validated.value.data,
    });

    if (error) {
      console.error("Telemetry insert error:", error);
      return jsonResponse({ error: "Insert failed" }, 500);
    }

    return jsonResponse({ success: true }, 200, { Connection: "keep-alive" });
  } catch (e) {
    console.error("Telemetry error:", e);
    return jsonResponse({ error: "Internal error" }, 500);
  }
});
