// Storage reference parsing for SORI media (P0 S2).
// Accepts both forms that exist in the DB today and after S7:
//   * public URL  https://<ref>.supabase.co/storage/v1/object/public/<bucket>/<path>
//     (also /object/sign/, /object/authenticated/ and /render/image/... variants)
//   * object path <shop_id>/<customer_id|unbound>/<file>   (bucket known from context)
// Pure module: no network.

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value.trim());
}

/** Buckets that exist in project tieojdbzmqcmlwyqltrk (plan 1.3). */
export const KNOWN_BUCKETS: ReadonlySet<string> = new Set([
  "chart_photos",
  "consent_pdfs",
  "chart-signatures",
  "shop_profiles",
  "chart-photos",
]);

export interface StorageRef {
  bucket: string;
  path: string;
}

const OBJECT_URL_PATH = /^\/storage\/v1\/(?:object|render\/image)\/(?:public|sign|authenticated)\/([^/]+)\/(.+)$/;

/** `https://abc.supabase.co` → `abc.supabase.co` (lower-case), or null. */
export function projectHostFromUrl(supabaseUrl: string | null | undefined): string | null {
  if (!supabaseUrl) return null;
  try {
    return new URL(supabaseUrl).host.toLowerCase() || null;
  } catch {
    return null;
  }
}

/** Rejects traversal, empty segments, absolute paths, backslashes and control characters. */
export function isSafeObjectPath(path: string): boolean {
  if (!path || path.length > 512) return false;
  if (path.startsWith("/") || path.includes("\\")) return false;
  // deno-lint-ignore no-control-regex
  if (/[\u0000-\u001f\u007f]/.test(path)) return false;
  return path.split("/").every((seg) => seg.length > 0 && seg !== "." && seg !== "..");
}

/**
 * Raw DB/client value → { bucket, path }, or null when it is not one of *our* storage objects.
 * - URLs must point at this project's host (other hosts, data: URIs → null).
 * - Bare paths need `defaultBucket` (the column decides the bucket).
 */
export function parseStorageRef(
  raw: unknown,
  opts: { projectHost: string | null; defaultBucket?: string },
): StorageRef | null {
  if (typeof raw !== "string") return null;
  const value = raw.trim();
  if (!value || value.startsWith("data:")) return null;

  if (value.includes("://")) {
    // Reject dot-segments (plain or percent-encoded) instead of letting URL parsing normalize them.
    if (/\/(?:\.|%2e){1,2}(?:\/|[?#]|$)/i.test(value)) return null;
    let url: URL;
    try {
      url = new URL(value);
    } catch {
      return null;
    }
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    if (!opts.projectHost || url.host.toLowerCase() !== opts.projectHost) return null;
    const m = OBJECT_URL_PATH.exec(url.pathname);
    if (!m) return null;
    let bucket: string;
    let path: string;
    try {
      bucket = decodeURIComponent(m[1]);
      path = m[2].split("/").map((s) => decodeURIComponent(s)).join("/");
    } catch {
      return null;
    }
    if (!KNOWN_BUCKETS.has(bucket) || !isSafeObjectPath(path)) return null;
    return { bucket, path };
  }

  if (!opts.defaultBucket || !KNOWN_BUCKETS.has(opts.defaultBucket)) return null;
  const path = value.replace(/^\/+/, "").split(/[?#]/)[0];
  if (!isSafeObjectPath(path)) return null;
  return { bucket: opts.defaultBucket, path };
}

/** First path segment is the owning shop id in every SORI bucket (`{shop_id}/...`). */
export function shopIdFromPath(path: string): string | null {
  const first = path.split("/")[0] ?? "";
  return UUID_RE.test(first) ? first.toLowerCase() : null;
}
