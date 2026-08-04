/**
 * Mirrors public.telemetry INSERT RLS
 * (supabase/migrations/20260324121000_harden_telemetry_insert_rls.sql).
 */

const EVENT_RE = /^[a-z0-9]+([._:-][a-z0-9]+)*$/;
const MAX_EVENT_LEN = 120;
const MAX_DATA_BYTES = 16384;

export type TelemetryPayload = {
  event: string;
  timestamp: string;
  data: Record<string, unknown> | null;
};

export type TelemetryValidation =
  | { ok: true; value: TelemetryPayload }
  | { ok: false; error: string };

function utf8ByteLength(value: string): number {
  return new TextEncoder().encode(value).length;
}

export function validateTelemetryBody(body: unknown): TelemetryValidation {
  if (body == null || typeof body !== "object" || Array.isArray(body)) {
    return { ok: false, error: "Invalid JSON body" };
  }
  const raw = body as Record<string, unknown>;
  const event = typeof raw.event === "string" ? raw.event.trim() : "";
  if (!event) {
    return { ok: false, error: "Missing 'event' field" };
  }
  if (event.length > MAX_EVENT_LEN || !EVENT_RE.test(event)) {
    return { ok: false, error: "Invalid 'event' field" };
  }

  let timestamp: string;
  if (raw.timestamp == null || raw.timestamp === "") {
    timestamp = new Date().toISOString();
  } else if (typeof raw.timestamp === "string") {
    timestamp = raw.timestamp;
  } else {
    return { ok: false, error: "Invalid 'timestamp' field" };
  }

  const ts = Date.parse(timestamp);
  if (Number.isNaN(ts)) {
    return { ok: false, error: "Invalid 'timestamp' field" };
  }
  const now = Date.now();
  const min = now - 24 * 60 * 60 * 1000;
  const max = now + 5 * 60 * 1000;
  if (ts < min || ts > max) {
    return { ok: false, error: "timestamp out of allowed window" };
  }

  let data: Record<string, unknown> | null = null;
  if (raw.data != null) {
    if (typeof raw.data !== "object" || Array.isArray(raw.data)) {
      return { ok: false, error: "Invalid 'data' field" };
    }
    data = raw.data as Record<string, unknown>;
    if (utf8ByteLength(JSON.stringify(data)) > MAX_DATA_BYTES) {
      return { ok: false, error: "data payload too large" };
    }
  }

  return { ok: true, value: { event, timestamp: new Date(ts).toISOString(), data } };
}
