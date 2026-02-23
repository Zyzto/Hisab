/** @jsxImportSource https://esm.sh/react@18.2.0 */
import React from "https://esm.sh/react@18.2.0";
import { ImageResponse } from "https://deno.land/x/og_edge@0.0.6/mod.ts";
import { qrcode } from "https://deno.land/x/qrcode@v2.0.0/mod.ts";

const SITE_URL = (Deno.env.get("SITE_URL") ?? "https://hisab.shenepoy.com").replace(/\/$/, "");
const ACCENT = "#22c55e";
const BG = "#fafafa";
const TEXT = "#333333";

export async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const token = url.searchParams.get("token");
  if (!token || token.length > 512) {
    return new Response("Missing or invalid token", { status: 400 });
  }

  const inviteUrl = `${SITE_URL}/functions/v1/invite-redirect?token=${encodeURIComponent(token)}`;
  let qrDataUrl: string;
  try {
    qrDataUrl = await qrcode(inviteUrl, { size: 380 });
  } catch {
    return new Response("QR generation failed", { status: 500 });
  }

  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          backgroundColor: BG,
          fontFamily: "system-ui, sans-serif",
          padding: 48,
        }}
      >
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: "white",
            borderRadius: 24,
            padding: 40,
            boxShadow: "0 4px 24px rgba(0,0,0,0.08)",
            border: `3px solid ${ACCENT}`,
          }}
        >
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 16,
              marginBottom: 24,
            }}
          >
            <img
              src={`${SITE_URL}/icons/Icon-192.png`}
              width={72}
              height={72}
              alt=""
              style={{ borderRadius: 16 }}
            />
            <span
              style={{
                fontSize: 48,
                fontWeight: 700,
                color: TEXT,
              }}
            >
              Hisab
            </span>
          </div>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              backgroundColor: "white",
              padding: 16,
              borderRadius: 12,
            }}
          >
            <img src={qrDataUrl} width={380} height={380} alt="" />
          </div>
          <div
            style={{
              marginTop: 16,
              fontSize: 22,
              color: "#666",
              textAlign: "center",
            }}
          >
            Scan to join the group
          </div>
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
      headers: {
        "Cache-Control": "public, max-age=86400",
      },
    }
  );
}
