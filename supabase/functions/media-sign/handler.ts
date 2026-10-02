// media-sign: short-lived signed URLs for SORI media (P0 S2, plan 3.4 / D6 / D8).
// Two modes (exactly one per request):
//   refs            → logged-in shop owner (or manager after S5) signs objects in their own shop folder.
//   case_chart_ids  → before/after photos of community shared cases (consented only), no login (Q1).
// Pure handler factory; network dependencies are injected (see index.ts).
import { bearerHeader, corsHeaders, gateRequest, jsonResponse, readJsonObject } from "../_shared/http.ts";
import { isUuid, parseStorageRef, shopIdFromPath, type StorageRef } from "../_shared/media_path.ts";

/** Private (or becoming private in S8) buckets. shop_profiles stays public; chart-photos is deleted in S9. */
export const SIGNABLE_BUCKETS: ReadonlySet<string> = new Set(["chart_photos", "consent_pdfs", "chart-signatures"]);
export const MAX_REFS = 50;
export const MAX_CASES = 20;
export const DEFAULT_TTL_SECONDS = 3600; // client cache is 50 min (plan D8)
export const MIN_TTL_SECONDS = 60;
export const MAX_TTL_SECONDS = 3600;
export const CASE_TTL_SECONDS = 3600; // Q1: community photos as 1-hour signed URLs
const MAX_BODY_BYTES = 16384;

export type AuthzMode = "owner" | "manager";

/** `MEDIA_SIGN_AUTHZ=manager` switches to is_shop_manager (only after S5 locks shop_memberships). */
export function parseAuthzMode(raw: string | null | undefined): AuthzMode {
  return (raw ?? "").trim().toLowerCase() === "manager" ? "manager" : "owner";
}

/** `MEDIA_SIGN_PUBLIC_CASES=off` disables case_chart_ids mode. Default on (decision Q1). */
export function parsePublicCases(raw: string | null | undefined): boolean {
  return !["off", "false", "0", "no"].includes((raw ?? "").trim().toLowerCase());
}

export type RefResult =
  | { ok: true; ref: StorageRef; shopId: string }
  | { ok: false; error: "invalid_ref" | "bucket_not_signable" };

/**
 * One client ref → bucket/path/shop. Accepted forms:
 *   "https://<project>/storage/v1/object/public/<bucket>/<path>"   (stored public URL)
 *   { "url": "<same>" }
 *   { "bucket": "chart_photos", "path": "<shop_id>/..." }           (object path)
 */
export function normalizeRef(input: unknown, projectHost: string | null): RefResult {
  let ref: StorageRef | null = null;
  if (typeof input === "string") {
    ref = parseStorageRef(input, { projectHost });
  } else if (input && typeof input === "object" && !Array.isArray(input)) {
    const o = input as Record<string, unknown>;
    if (typeof o.url === "string") {
      ref = parseStorageRef(o.url, { projectHost });
    } else if (typeof o.bucket === "string" && typeof o.path === "string") {
      ref = parseStorageRef(o.path, { projectHost, defaultBucket: o.bucket });
    }
  }
  if (!ref) return { ok: false, error: "invalid_ref" };
  if (!SIGNABLE_BUCKETS.has(ref.bucket)) return { ok: false, error: "bucket_not_signable" };
  const shopId = shopIdFromPath(ref.path);
  if (!shopId) return { ok: false, error: "invalid_ref" };
  return { ok: true, ref, shopId };
}

export function parseTtl(raw: unknown): number | null {
  if (raw === undefined || raw === null) return DEFAULT_TTL_SECONDS;
  if (typeof raw !== "number" || !Number.isInteger(raw)) return null;
  if (raw < MIN_TTL_SECONDS || raw > MAX_TTL_SECONDS) return null;
  return raw;
}

/** Indexes of refs whose shop is not in `allowedShops` (any → whole request is rejected). */
export function forbiddenIndexes(results: RefResult[], allowedShops: ReadonlySet<string>): number[] {
  const out: number[] = [];
  results.forEach((r, i) => {
    if (r.ok && !allowedShops.has(r.shopId)) out.push(i);
  });
  return out;
}

export interface SharedCase {
  chart_id: string;
  shop_id: string;
  before_image_url?: string | null;
  after_image_url?: string | null;
}

export interface MediaSignDeps {
  /** Logged-in user id for this Authorization header, or null (anon key, expired, invalid). */
  getUserId(authorization: string): Promise<string | null>;
  /** is_shop_owner / is_shop_manager evaluated as the calling user. */
  canManageShop(authorization: string, shopId: string, mode: AuthzMode): Promise<boolean>;
  /** Consented community shared cases among `chartIds` (public.list_community_shared_cases). */
  listSharedCases(chartIds: string[]): Promise<SharedCase[]>;
  signUrls(bucket: string, paths: string[], ttlSeconds: number): Promise<(string | null)[]>;
  projectHost: string | null;
  allowedOrigins: string[];
  authzMode: AuthzMode;
  publicCasesEnabled: boolean;
  now?: () => number;
  log?: (msg: string) => void;
}

async function signGrouped(
  deps: Pick<MediaSignDeps, "signUrls">,
  items: { bucket: string; path: string }[],
  ttl: number,
): Promise<(string | null)[]> {
  const out: (string | null)[] = items.map(() => null);
  const byBucket = new Map<string, number[]>();
  items.forEach((it, i) => byBucket.set(it.bucket, [...(byBucket.get(it.bucket) ?? []), i]));
  for (const [bucket, idxs] of byBucket) {
    let signed: (string | null)[] = [];
    try {
      signed = await deps.signUrls(bucket, idxs.map((i) => items[i].path), ttl);
    } catch {
      signed = [];
    }
    idxs.forEach((i, k) => (out[i] = signed[k] ?? null));
  }
  return out;
}

function caseImageRef(raw: unknown, shopId: string, projectHost: string | null): StorageRef | null {
  const ref = parseStorageRef(raw, { projectHost, defaultBucket: "chart_photos" });
  if (!ref || ref.bucket !== "chart_photos") return null;
  return shopIdFromPath(ref.path) === shopId.toLowerCase() ? ref : null;
}

export async function handleCases(
  rawIds: unknown,
  deps: MediaSignDeps,
): Promise<{ status: number; body: Record<string, unknown> }> {
  if (!deps.publicCasesEnabled) return { status: 403, body: { ok: false, error: "public_cases_disabled" } };
  if (!Array.isArray(rawIds) || rawIds.length === 0 || rawIds.length > MAX_CASES || !rawIds.every(isUuid)) {
    return { status: 400, body: { ok: false, error: "invalid_case_chart_ids", max: MAX_CASES } };
  }
  const ids = [...new Set((rawIds as string[]).map((s) => s.trim().toLowerCase()))];
  const cases = await deps.listSharedCases(ids);
  const byId = new Map(cases.map((c) => [String(c.chart_id).toLowerCase(), c]));

  const toSign: { bucket: string; path: string }[] = [];
  const slots: { chartId: string; key: "before" | "after" }[] = [];
  for (const id of ids) {
    const c = byId.get(id);
    if (!c) continue;
    for (const key of ["before", "after"] as const) {
      const ref = caseImageRef(c[`${key}_image_url`], c.shop_id, deps.projectHost);
      if (ref) {
        toSign.push(ref);
        slots.push({ chartId: id, key });
      }
    }
  }
  const signed = await signGrouped(deps, toSign, CASE_TTL_SECONDS);
  const items = ids.filter((id) => byId.has(id)).map((id) => ({
    chart_id: id,
    before_url: null as string | null,
    after_url: null as string | null,
  }));
  const itemById = new Map(items.map((it) => [it.chart_id, it]));
  slots.forEach((s, i) => {
    const it = itemById.get(s.chartId)!;
    if (s.key === "before") it.before_url = signed[i];
    else it.after_url = signed[i];
  });
  const nowMs = (deps.now ?? Date.now)();
  return {
    status: 200,
    body: {
      ok: true,
      mode: "cases",
      expires_in: CASE_TTL_SECONDS,
      expires_at: new Date(nowMs + CASE_TTL_SECONDS * 1000).toISOString(),
      items,
      // not shared, no marketing consent, no signature/consent PDF, or unknown → no URLs
      not_eligible: ids.filter((id) => !byId.has(id)),
    },
  };
}

export async function handleRefs(
  body: Record<string, unknown>,
  authorization: string | null,
  deps: MediaSignDeps,
): Promise<{ status: number; body: Record<string, unknown> }> {
  if (!authorization) return { status: 401, body: { ok: false, error: "login_required" } };
  const userId = await deps.getUserId(authorization);
  if (!userId) return { status: 401, body: { ok: false, error: "login_required" } };

  const refs = body.refs;
  if (!Array.isArray(refs) || refs.length === 0 || refs.length > MAX_REFS) {
    return { status: 400, body: { ok: false, error: "invalid_refs", max: MAX_REFS } };
  }
  const ttl = parseTtl(body.expires_in);
  if (ttl === null) {
    return {
      status: 400,
      body: { ok: false, error: "invalid_expires_in", min: MIN_TTL_SECONDS, max: MAX_TTL_SECONDS },
    };
  }

  const results = refs.map((r) => normalizeRef(r, deps.projectHost));
  const shops = [...new Set(results.flatMap((r) => (r.ok ? [r.shopId] : [])))];
  const allowed = new Set<string>();
  for (const shopId of shops) {
    if (await deps.canManageShop(authorization, shopId, deps.authzMode)) allowed.add(shopId);
  }
  const forbidden = forbiddenIndexes(results, allowed);
  if (forbidden.length > 0) {
    return { status: 403, body: { ok: false, error: "forbidden", forbidden } };
  }

  const signable = results.flatMap((r, i) => (r.ok ? [{ i, bucket: r.ref.bucket, path: r.ref.path }] : []));
  const signed = await signGrouped(deps, signable, ttl);
  const urlByIndex = new Map(signable.map((s, k) => [s.i, signed[k]]));
  const items = results.map((r, i) =>
    r.ok
      ? {
        index: i,
        bucket: r.ref.bucket,
        path: r.ref.path,
        signed_url: urlByIndex.get(i) ?? null,
        ...(urlByIndex.get(i) ? {} : { error: "not_found" }),
      }
      : { index: i, signed_url: null, error: r.error }
  );
  const nowMs = (deps.now ?? Date.now)();
  return {
    status: 200,
    body: {
      ok: true,
      mode: "refs",
      expires_in: ttl,
      expires_at: new Date(nowMs + ttl * 1000).toISOString(),
      items,
    },
  };
}

export function createMediaSignHandler(deps: MediaSignDeps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    const gated = gateRequest(req, deps.allowedOrigins);
    if (gated) return gated;
    const cors = corsHeaders(req.headers.get("Origin"), deps.allowedOrigins);
    try {
      const parsed = await readJsonObject(req, MAX_BODY_BYTES);
      if (!parsed.ok) return jsonResponse({ ok: false, error: "invalid_request" }, 400, cors);
      const body = parsed.value;
      const hasRefs = body.refs !== undefined;
      const hasCases = body.case_chart_ids !== undefined;
      if (hasRefs === hasCases) {
        return jsonResponse({ ok: false, error: "use_refs_or_case_chart_ids" }, 400, cors);
      }
      const result = hasCases
        ? await handleCases(body.case_chart_ids, deps)
        : await handleRefs(body, bearerHeader(req), deps);
      return jsonResponse(result.body, result.status, cors);
    } catch (e) {
      deps.log?.(`media-sign: unhandled ${e instanceof Error ? e.name : "error"}`);
      return jsonResponse({ ok: false, error: "server_error" }, 500, cors);
    }
  };
}
