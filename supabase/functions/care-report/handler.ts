// care-report: customer care report by unguessable token (SORI P0 S2, plan 3.5 / D1).
// Pure handler factory; network dependencies are injected (see index.ts for the real ones).
import { corsHeaders, gateRequest, jsonResponse, readJsonObject } from "../_shared/http.ts";
import { isUuid, parseStorageRef, shopIdFromPath } from "../_shared/media_path.ts";

/** Plan 3.5: report photos are signed for 10 minutes. */
export const REPORT_MEDIA_TTL_SECONDS = 600;
/** Same bounds as public._resolve_customer_token (20..128); issued tokens are 43-char base64url. */
export const TOKEN_RE = /^[A-Za-z0-9_-]{20,128}$/;
const MAX_BODY_BYTES = 4096;

export const MESSAGES = {
  legacy_link: "링크가 갱신되었어요. 샵에 새 링크를 요청해 주세요.",
  link_expired: "링크 유효기간이 지났어요. 샵에 새 링크를 요청해 주세요.",
  not_found: "링크를 찾을 수 없어요. 주소를 다시 확인하거나 샵에 새 링크를 요청해 주세요.",
  invalid_request: "잘못된 요청이에요.",
  server_error: "잠시 후 다시 시도해 주세요.",
} as const;

export type TokenInput =
  | { kind: "token"; token: string }
  | { kind: "legacy" }
  | { kind: "invalid" };

/**
 * Body → token classification.
 * - `{ token: "<43-char base64url>" }` → token
 * - `{ token: "<uuid>" }`, `{ chart_id }` or `{ chartId }` → legacy chartId link (decision Q3)
 */
export function classifyInput(body: Record<string, unknown>): TokenInput {
  const legacyField = body.chart_id ?? body.chartId;
  if (legacyField !== undefined && legacyField !== null && legacyField !== "") return { kind: "legacy" };
  const raw = body.token;
  if (typeof raw !== "string") return { kind: "invalid" };
  const token = raw.trim();
  if (isUuid(token)) return { kind: "legacy" };
  if (TOKEN_RE.test(token)) return { kind: "token", token };
  return { kind: "invalid" };
}

export type RpcResult =
  | { ok: true; data: unknown }
  | { ok: false; status: number; code?: string | null };

/** PostgREST error → client-facing status/body. Never forwards DB messages. */
export function mapRpcFailure(r: { status: number; code?: string | null }): {
  status: number;
  body: Record<string, unknown>;
} {
  const code = r.code ?? "";
  if (code === "PT404" || (!code && r.status === 404)) {
    return {
      status: 404,
      body: { ok: false, error: "not_found", action: "request_new_link", message: MESSAGES.not_found },
    };
  }
  if (code === "PT410" || (!code && r.status === 410)) {
    return {
      status: 410,
      body: { ok: false, error: "link_expired", action: "request_new_link", message: MESSAGES.link_expired },
    };
  }
  if (code === "22023") {
    return { status: 400, body: { ok: false, error: "invalid_request", message: MESSAGES.invalid_request } };
  }
  return { status: 502, body: { ok: false, error: "upstream_error", message: MESSAGES.server_error } };
}

// Keys that must never reach a customer link, wherever they appear (defense in depth:
// the M1 RPC already allow-lists columns; care_report_json is free-form jsonb).
const FORBIDDEN_KEY =
  /(signature|consent_pdf|allergy|side_effect|psycholog|birth|guardian|ai_insight|paid_amount|safety_snapshot|customer_phone|customer_id)/i;
// Allowed only inside the top-level `shop` object (shop business contact).
const SHOP_ONLY_KEYS = new Set(["phone", "address"]);

/** Removes forbidden keys in place; returns how many were removed. */
export function scrubForbidden(value: unknown, insideShop = false): number {
  let removed = 0;
  if (Array.isArray(value)) {
    for (const v of value) removed += scrubForbidden(v, insideShop);
    return removed;
  }
  if (!value || typeof value !== "object") return 0;
  const obj = value as Record<string, unknown>;
  for (const key of Object.keys(obj)) {
    if (FORBIDDEN_KEY.test(key) || (!insideShop && SHOP_ONLY_KEYS.has(key.toLowerCase()))) {
      delete obj[key];
      removed++;
      continue;
    }
    removed += scrubForbidden(obj[key], insideShop);
  }
  return removed;
}

/** Top-level scrub: `shop` may keep its business phone/address, nothing else may. */
export function scrubReport(body: Record<string, unknown>): number {
  let removed = 0;
  for (const key of Object.keys(body)) {
    if (FORBIDDEN_KEY.test(key) || SHOP_ONLY_KEYS.has(key.toLowerCase())) {
      delete body[key];
      removed++;
      continue;
    }
    removed += scrubForbidden(body[key], key === "shop");
  }
  return removed;
}

export interface CareReportDeps {
  /** rpc('get_care_report_by_token', { p_token }) */
  getCareReport(token: string): Promise<RpcResult>;
  /** Signs object paths in one bucket; result is index-aligned (null = could not sign). */
  signUrls(bucket: string, paths: string[], ttlSeconds: number): Promise<(string | null)[]>;
  projectHost: string | null;
  allowedOrigins: string[];
  now?: () => number;
  log?: (msg: string) => void;
}

const IMAGE_KEYS = ["before_image_url", "after_image_url"] as const;

/**
 * RPC payload → response body. Photos (already gated by consent_photo inside the RPC)
 * are re-signed as short-lived URLs; values that are not this shop's chart_photos objects
 * are dropped.
 */
export async function shapeReport(
  payload: Record<string, unknown>,
  deps: Pick<CareReportDeps, "signUrls" | "projectHost" | "now" | "log">,
): Promise<Record<string, unknown>> {
  const body = structuredClone(payload) as Record<string, unknown>;
  const scrubbed = scrubReport(body);
  if (scrubbed > 0) deps.log?.(`care-report: scrubbed ${scrubbed} forbidden key(s)`);

  const chart = (body.chart && typeof body.chart === "object") ? body.chart as Record<string, unknown> : {};
  const chartShop = typeof chart.shop_id === "string" ? chart.shop_id.toLowerCase() : null;

  const toSign: { key: string; path: string }[] = [];
  let unavailable = 0;
  for (const key of IMAGE_KEYS) {
    const raw = chart[key];
    if (raw === null || raw === undefined || raw === "") {
      chart[key] = null;
      continue;
    }
    const ref = parseStorageRef(raw, { projectHost: deps.projectHost, defaultBucket: "chart_photos" });
    if (!ref || ref.bucket !== "chart_photos" || !chartShop || shopIdFromPath(ref.path) !== chartShop) {
      chart[key] = null;
      unavailable++;
      continue;
    }
    toSign.push({ key, path: ref.path });
  }

  if (toSign.length > 0) {
    let signed: (string | null)[] = [];
    try {
      signed = await deps.signUrls("chart_photos", toSign.map((t) => t.path), REPORT_MEDIA_TTL_SECONDS);
    } catch {
      signed = [];
    }
    toSign.forEach((t, i) => {
      const url = signed[i] ?? null;
      chart[t.key] = url;
      if (!url) unavailable++;
    });
  }

  const nowMs = (deps.now ?? Date.now)();
  const anySigned = IMAGE_KEYS.some((k) => typeof chart[k] === "string");
  return {
    ok: true,
    ...body,
    chart,
    photos_unavailable: unavailable > 0,
    media_expires_in: anySigned ? REPORT_MEDIA_TTL_SECONDS : null,
    media_expires_at: anySigned ? new Date(nowMs + REPORT_MEDIA_TTL_SECONDS * 1000).toISOString() : null,
  };
}

export function createCareReportHandler(deps: CareReportDeps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const gated = gateRequest(req, deps.allowedOrigins);
    if (gated) return gated;
    const cors = corsHeaders(req.headers.get("Origin"), deps.allowedOrigins);

    try {
      const parsed = await readJsonObject(req, MAX_BODY_BYTES);
      if (!parsed.ok) {
        return jsonResponse({ ok: false, error: "invalid_request", message: MESSAGES.invalid_request }, 400, cors);
      }
      const input = classifyInput(parsed.value);
      if (input.kind === "invalid") {
        return jsonResponse({ ok: false, error: "invalid_request", message: MESSAGES.invalid_request }, 400, cors);
      }
      if (input.kind === "legacy") {
        return jsonResponse(
          { ok: false, error: "legacy_link", action: "request_new_link", message: MESSAGES.legacy_link },
          410,
          cors,
        );
      }

      const rpc = await deps.getCareReport(input.token);
      if (!rpc.ok) {
        const mapped = mapRpcFailure(rpc);
        if (mapped.status >= 500) deps.log?.(`care-report: rpc failure status=${rpc.status} code=${rpc.code ?? ""}`);
        return jsonResponse(mapped.body, mapped.status, cors);
      }
      const data = rpc.data;
      if (!data || typeof data !== "object" || Array.isArray(data) || !("chart" in data)) {
        deps.log?.("care-report: unexpected rpc payload shape");
        return jsonResponse({ ok: false, error: "upstream_error", message: MESSAGES.server_error }, 502, cors);
      }
      const body = await shapeReport(data as Record<string, unknown>, deps);
      return jsonResponse(body, 200, cors);
    } catch (e) {
      deps.log?.(`care-report: unhandled ${e instanceof Error ? e.name : "error"}`);
      return jsonResponse({ ok: false, error: "server_error", message: MESSAGES.server_error }, 500, cors);
    }
  };
}
