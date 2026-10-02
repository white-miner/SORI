// Shared HTTP helpers for SORI security Edge functions (P0 S2).
// Pure module (no network, no Supabase client) so it can be unit-tested with `deno test`.

/** GitHub Pages origin of the web app (https://white-miner.github.io/SORI/). */
export const DEFAULT_ALLOWED_ORIGINS = ["https://white-miner.github.io"];

/** Local development (flutter run -d chrome / web-server). */
const LOCAL_DEV_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;

/** `SORI_ALLOWED_ORIGINS` (comma separated) replaces the default list when set. */
export function parseAllowedOrigins(raw: string | null | undefined): string[] {
  const list = (raw ?? "")
    .split(",")
    .map((s) => s.trim().replace(/\/+$/, ""))
    .filter((s) => /^https?:\/\/[^/\s]+$/.test(s));
  return list.length > 0 ? list : [...DEFAULT_ALLOWED_ORIGINS];
}

/**
 * Requests without an Origin header (curl, native apps, server-to-server) are not
 * subject to CORS and are allowed; authorization is enforced separately.
 */
export function isOriginAllowed(origin: string | null, allowed: string[]): boolean {
  if (!origin) return true;
  return allowed.includes(origin) || LOCAL_DEV_ORIGIN.test(origin);
}

export function corsHeaders(origin: string | null, allowed: string[]): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "600",
    "Vary": "Origin",
  };
  if (origin && isOriginAllowed(origin, allowed)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

export function jsonResponse(
  body: unknown,
  status: number,
  cors: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...cors,
      "Content-Type": "application/json; charset=utf-8",
      // Responses carry signed URLs / customer report data: never cache.
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

/**
 * Common request gate: CORS preflight, origin allow-list and method.
 * Returns a Response to send immediately, or null to continue.
 */
export function gateRequest(req: Request, allowed: string[]): Response | null {
  const origin = req.headers.get("Origin");
  const cors = corsHeaders(origin, allowed);
  if (!isOriginAllowed(origin, allowed)) {
    return jsonResponse({ ok: false, error: "origin_not_allowed" }, 403, cors);
  }
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }
  if (req.method !== "POST") {
    return jsonResponse({ ok: false, error: "method_not_allowed" }, 405, {
      ...cors,
      "Allow": "POST, OPTIONS",
    });
  }
  return null;
}

export type JsonBodyResult =
  | { ok: true; value: Record<string, unknown> }
  | { ok: false; error: "body_too_large" | "invalid_json" };

/** Reads a small JSON object body. Anything else (array, scalar, oversized) is rejected. */
export async function readJsonObject(req: Request, maxBytes: number): Promise<JsonBodyResult> {
  const declared = Number(req.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(declared) && declared > maxBytes) return { ok: false, error: "body_too_large" };
  let text: string;
  try {
    text = await req.text();
  } catch {
    return { ok: false, error: "invalid_json" };
  }
  if (new TextEncoder().encode(text).length > maxBytes) return { ok: false, error: "body_too_large" };
  try {
    const value = JSON.parse(text);
    if (value && typeof value === "object" && !Array.isArray(value)) {
      return { ok: true, value: value as Record<string, unknown> };
    }
  } catch {
    // fall through
  }
  return { ok: false, error: "invalid_json" };
}

/** `Authorization: Bearer <jwt>` → the raw header, or null when missing/blank. */
export function bearerHeader(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.replace(/^Bearer\s+/i, "").trim();
  if (!token || token === header.trim()) return null;
  return `Bearer ${token}`;
}
