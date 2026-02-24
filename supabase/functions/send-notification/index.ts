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

/** Localized strings for push notifications (must match app translations). */
const NOTIFICATION_STRINGS: Record<string, Record<string, string>> = {
  en: {
    new_expense: "New expense",
    expense_updated: "Expense updated",
    group_activity: "Group activity",
    member_joined: "A new member joined the group.",
    expense: "Expense",
  },
  ar: {
    new_expense: "مصروف جديد",
    expense_updated: "تم تحديث المصروف",
    group_activity: "نشاط المجموعة",
    member_joined: "انضم عضو جديد إلى المجموعة.",
    expense: "مصروف",
  },
};

/** Build notification title and body from trigger payload, localized by locale (en/ar; null => en). */
function buildNotificationText(p: TriggerPayload, locale: string | null): { title: string; body: string } {
  const strings = NOTIFICATION_STRINGS[locale ?? "en"] ?? NOTIFICATION_STRINGS.en;
  switch (p.action) {
    case "expense_created":
    case "expense_updated": {
      const actionLabel = p.action === "expense_created" ? strings.new_expense : strings.expense_updated;
      const title = p.expense_title ?? strings.expense;
      const amount =
        p.amount_cents != null && p.currency_code
          ? `${(p.amount_cents / 100).toFixed(2)} ${p.currency_code}`
          : "";
      const body = amount ? `${actionLabel}: ${title} (${amount})` : `${actionLabel}: ${title}`;
      return { title, body };
    }
    case "member_joined":
      return { title: strings.group_activity, body: strings.member_joined };
    default:
      return { title: strings.group_activity, body: strings.member_joined };
  }
}

/** Get OAuth2 access token for FCM using service account JWT. */
async function getFcmAccessToken(serviceAccountKey: string): Promise<string> {
  const key = JSON.parse(serviceAccountKey) as {
    client_email: string;
    private_key: string;
  };
  const privateKey = await jose.importPKCS8(key.private_key, "RS256");
  const jwt = await new jose.SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
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

/** Result of sending one FCM message. */
type SendResult = { ok: true } | { ok: false; error: string; stale?: boolean };

/** Send one FCM v1 message to a single token. */
async function sendFcmMessage(
  projectId: string,
  accessToken: string,
  token: string,
  title: string,
  body: string,
  groupId: string
): Promise<SendResult> {
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
  const stale = res.status === 404 && text.includes("UNREGISTERED");
  return { ok: false, error: `${res.status} ${text}`, ...(stale && { stale: true }) };
}

Deno.serve(async (req: Request) => {
  try {
    return await handleNotificationRequest(req);
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    const stack = e instanceof Error ? e.stack : undefined;
    console.error("send-notification: uncaught error", message, stack ?? "");
    return new Response(
      JSON.stringify({ error: "Internal error", detail: message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});

async function handleNotificationRequest(req: Request): Promise<Response> {
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

  // Normalize actor so joinee is never sent member_joined (handles UUID/casing from trigger).
  const actorNorm = String(payload?.actor_user_id ?? "").trim().toLowerCase();
  if (payload.action === "member_joined" && !actorNorm) {
    console.log("send-notification: member_joined with no actor, skipping");
    return new Response(
      JSON.stringify({ sent: 0, message: "member_joined: no actor, skipping" }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }
  console.log("send-notification: request", { action: payload.action, actor_user_id: payload.actor_user_id });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // For expense_created and expense_updated, the actor is the creator/editor; they must not
  // receive a notification. Only other group members are notified (same as for member_joined).
  const { data: members } = await supabase
    .from("group_members")
    .select("user_id")
    .eq("group_id", payload.group_id);
  const memberCount = (members ?? []).length;
  const userIds = (members ?? [])
    .map((r) => r.user_id as string)
    .filter((id) => String(id ?? "").trim().toLowerCase() !== actorNorm);
  if (userIds.length === 0) {
    console.log("send-notification: No other members to notify", {
      group_id: payload.group_id,
      actor_user_id: payload.actor_user_id,
      action: payload.action,
      memberCount,
    });
    return new Response(JSON.stringify({ sent: 0, message: "No other members to notify" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: tokenRows } = await supabase
    .from("device_tokens")
    .select("token, locale, user_id")
    .in("user_id", userIds);
  // Exclude actor from send list (defense-in-depth so joinee never gets member_joined).
  const rows = (tokenRows ?? []).filter(
    (r) => r.token && r.user_id && String(r.user_id).trim().toLowerCase() !== actorNorm,
  );
  const tokenCount = rows.length;
  if (tokenCount === 0) {
    console.log("send-notification: No device tokens for members", {
      group_id: payload.group_id,
      action: payload.action,
      memberCount: userIds.length,
      tokenCount: 0,
    });
    return new Response(JSON.stringify({ sent: 0, message: "No device tokens for members" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  let accessToken: string;
  try {
    accessToken = await getFcmAccessToken(serviceAccountKey);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("send-notification: FCM OAuth2 error", msg);
    return new Response(
      JSON.stringify({ error: "Failed to obtain FCM access token", detail: msg }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  let sent = 0;
  const errors: string[] = [];
  let deletedStale = 0;
  for (const row of rows) {
    const token = row.token as string;
    const userId = row.user_id as string;
    // Never send to the actor (person who made the change)
    if (String(userId ?? "").trim().toLowerCase() === actorNorm) continue;
    const locale = (row.locale as string | null) ?? null;
    const { title, body } = buildNotificationText(payload, locale);
    const result = await sendFcmMessage(
      projectId,
      accessToken,
      token,
      title,
      body,
      payload.group_id
    );
    if (result.ok) sent++;
    else {
      if (result.error) errors.push(result.error);
      if ("stale" in result && result.stale) {
        const { error: deleteErr } = await supabase
          .from("device_tokens")
          .delete()
          .eq("user_id", userId)
          .eq("token", token);
        if (!deleteErr) deletedStale++;
      }
    }
  }

  if (deletedStale > 0) {
    console.log("send-notification: deleted stale tokens", { count: deletedStale });
  }
  console.log("send-notification: sent", {
    group_id: payload.group_id,
    action: payload.action,
    memberCount: userIds.length,
    tokenCount: rows.length,
    sent,
    ...(errors.length > 0 && { errorSample: errors.slice(0, 2) }),
  });

  return new Response(
    JSON.stringify({
      sent,
      total: rows.length,
      ...(errors.length > 0 && { errors: errors.slice(0, 5) }),
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }
  );
}
