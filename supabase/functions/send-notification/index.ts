import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import * as jose from "npm:jose@5.2.0";

/** Body sent by the database trigger (notify_group_activity). */
interface TriggerPayload {
  group_id: string;
  actor_user_id: string;
  action: "expense_created" | "expense_updated" | "member_joined";
  expense_title?: string | null;
  amount_cents?: number | null;
  currency_code?: string | null;
}

/** Build notification title and body from trigger payload. */
function buildNotificationText(p: TriggerPayload): { title: string; body: string } {
  const groupId = p.group_id;
  switch (p.action) {
    case "expense_created":
    case "expense_updated": {
      const actionLabel = p.action === "expense_created" ? "New expense" : "Expense updated";
      const title = p.expense_title ?? "Expense";
      const amount =
        p.amount_cents != null && p.currency_code
          ? `${(p.amount_cents / 100).toFixed(2)} ${p.currency_code}`
          : "";
      const body = amount ? `${actionLabel}: ${title} (${amount})` : `${actionLabel}: ${title}`;
      return { title, body };
    }
    case "member_joined":
      return { title: "Group activity", body: "A new member joined the group." };
    default:
      return { title: "Group activity", body: "Something changed in your group." };
  }
}

/** Get OAuth2 access token for FCM using service account JWT. */
async function getFcmAccessToken(serviceAccountKey: string): Promise<string> {
  const key = JSON.parse(serviceAccountKey) as {
    client_email: string;
    private_key: string;
  };
  const privateKey = await jose.importPKCS8(key.private_key, "RS256");
  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(key.client_email)
    .setSubject(key.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(Math.floor(Date.now() / 1000))
    .setExpirationTime("1h")
    .sign(privateKey);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`FCM OAuth2 failed: ${res.status} ${text}`);
  }
  const data = (await res.json()) as { access_token: string };
  return data.access_token;
}

/** Send one FCM v1 message to a single token. */
async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  groupId: string
): Promise<{ ok: boolean; error?: string }> {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data: { group_id: groupId },
      },
    }),
  });
  if (res.ok) return { ok: true };
  const text = await res.text();
  return { ok: false, error: `${res.status} ${text}` };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!serviceRoleKey || !authHeader?.startsWith("Bearer ") || authHeader.slice(7) !== serviceRoleKey) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const projectId = Deno.env.get("FCM_PROJECT_ID");
  const serviceAccountKey = Deno.env.get("FCM_SERVICE_ACCOUNT_KEY");
  if (!projectId || !serviceAccountKey) {
    console.error("send-notification: FCM_PROJECT_ID or FCM_SERVICE_ACCOUNT_KEY not set");
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let payload: TriggerPayload;
  try {
    payload = (await req.json()) as TriggerPayload;
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!payload.group_id || !payload.actor_user_id || !payload.action) {
    return new Response(JSON.stringify({ error: "Missing group_id, actor_user_id, or action" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const { data: members } = await supabase
    .from("group_members")
    .select("user_id")
    .eq("group_id", payload.group_id);
  const userIds = (members ?? [])
    .map((r) => r.user_id as string)
    .filter((id) => id !== payload.actor_user_id);
  if (userIds.length === 0) {
    return new Response(JSON.stringify({ sent: 0, message: "No other members to notify" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: tokenRows } = await supabase
    .from("device_tokens")
    .select("token")
    .in("user_id", userIds);
  const tokens = (tokenRows ?? []).map((r) => r.token as string).filter(Boolean);
  if (tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0, message: "No device tokens for members" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { title, body } = buildNotificationText(payload);
  let accessToken: string;
  try {
    accessToken = await getFcmAccessToken(serviceAccountKey);
  } catch (e) {
    console.error("send-notification: FCM OAuth2 error", e);
    return new Response(JSON.stringify({ error: "Failed to obtain FCM access token" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let sent = 0;
  const errors: string[] = [];
  for (const token of tokens) {
    const result = await sendFcmMessage(
      projectId,
      accessToken,
      token,
      title,
      body,
      payload.group_id
    );
    if (result.ok) sent++;
    else if (result.error) errors.push(result.error);
  }

  return new Response(
    JSON.stringify({
      sent,
      total: tokens.length,
      ...(errors.length > 0 && { errors: errors.slice(0, 5) }),
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }
  );
});
