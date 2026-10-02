// Real network dependencies for the S2 Edge functions (Supabase JS client).
// Kept out of the handlers so `deno test` runs without network or secrets.
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

export interface EdgeEnv {
  url: string;
  anonKey: string;
  serviceRoleKey: string;
}

/** SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected by the Edge runtime. */
export function readEdgeEnv(): EdgeEnv {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  return { url, anonKey, serviceRoleKey };
}

const noSession = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };

/** Client with the public anon key (same privileges as the web app before login). */
export function anonClient(env: EdgeEnv): SupabaseClient {
  return createClient(env.url, env.anonKey, noSession);
}

/** Client that acts as the calling user (their JWT), for auth.getUser() and RLS/auth.uid() RPCs. */
export function userClient(env: EdgeEnv, authorization: string): SupabaseClient {
  return createClient(env.url, env.anonKey, { ...noSession, global: { headers: { Authorization: authorization } } });
}

/** service_role client. Used ONLY for Storage signing (createSignedUrls). */
export function serviceClient(env: EdgeEnv): SupabaseClient {
  return createClient(env.url, env.serviceRoleKey, noSession);
}

/** Index-aligned signed URLs for paths in one bucket (null when an object is missing). */
export function makeSigner(env: EdgeEnv) {
  return async (bucket: string, paths: string[], ttlSeconds: number): Promise<(string | null)[]> => {
    if (paths.length === 0) return [];
    if (!env.serviceRoleKey) return paths.map(() => null);
    const { data, error } = await serviceClient(env).storage.from(bucket).createSignedUrls(paths, ttlSeconds);
    if (error || !Array.isArray(data)) return paths.map(() => null);
    const byPath = new Map<string, string | null>();
    for (const row of data) {
      if (row && typeof row.path === "string") byPath.set(row.path, row.error ? null : (row.signedUrl ?? null));
    }
    return paths.map((p) => byPath.get(p) ?? null);
  };
}

/** PostgREST error → { status, code } without leaking messages. */
export function rpcFailure(error: { code?: string } | null, status: number | undefined) {
  return { ok: false as const, status: status ?? 500, code: error?.code ?? null };
}
