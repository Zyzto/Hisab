/** CORS headers for browser-invoked Edge Functions (Flutter web). */
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

export function corsPreflightResponse(): Response {
  return new Response("ok", { headers: corsHeaders });
}
