// SORI P0 S2 — media-sign
// POST { "refs": [...] }            (Authorization: Bearer <user JWT>) → signed URLs for the caller's own shop
// POST { "case_chart_ids": [...] }  (no login, decision Q1)            → signed photos of consented shared cases
// Deploy with verify_jwt = false: the function verifies the user JWT itself (auth.getUser) and the
// case mode is public. See supabase/config.toml and handler.ts for the rules.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { parseAllowedOrigins } from "../_shared/http.ts";
import { projectHostFromUrl } from "../_shared/media_path.ts";
import { anonClient, makeSigner, readEdgeEnv, userClient } from "../_shared/supabase_deps.ts";
import { createMediaSignHandler, parseAuthzMode, parsePublicCases, type SharedCase } from "./handler.ts";

const env = readEdgeEnv();
const PAGE = 100; // list_community_shared_cases caps p_limit at 100
const MAX_PAGES = 20;

Deno.serve(createMediaSignHandler({
  async getUserId(authorization) {
    if (!env.url || !env.anonKey) return null;
    const { data, error } = await userClient(env, authorization).auth.getUser();
    if (error || !data?.user?.id) return null;
    return data.user.id;
  },
  async canManageShop(authorization, shopId, mode) {
    const fn = mode === "manager" ? "is_shop_manager" : "is_shop_owner";
    const { data, error } = await userClient(env, authorization).rpc(fn, { p_shop_id: shopId });
    return !error && data === true;
  },
  async listSharedCases(chartIds) {
    // Same consent predicate as the community feed (M1 RPC), so the gate lives in one place.
    const wanted = new Set(chartIds);
    const found: SharedCase[] = [];
    for (let page = 0; page < MAX_PAGES && found.length < wanted.size; page++) {
      const { data, error } = await anonClient(env).rpc("list_community_shared_cases", {
        p_limit: PAGE,
        p_offset: page * PAGE,
      });
      if (error || !Array.isArray(data)) break;
      for (const row of data) {
        const id = String(row?.chart_id ?? "").toLowerCase();
        if (wanted.has(id)) {
          found.push({
            chart_id: id,
            shop_id: String(row.shop_id ?? ""),
            before_image_url: row.before_image_url ?? null,
            after_image_url: row.after_image_url ?? null,
          });
        }
      }
      if (data.length < PAGE) break;
    }
    return found;
  },
  signUrls: makeSigner(env),
  projectHost: projectHostFromUrl(env.url),
  allowedOrigins: parseAllowedOrigins(Deno.env.get("SORI_ALLOWED_ORIGINS")),
  authzMode: parseAuthzMode(Deno.env.get("MEDIA_SIGN_AUTHZ")),
  publicCasesEnabled: parsePublicCases(Deno.env.get("MEDIA_SIGN_PUBLIC_CASES")),
  log: (msg) => console.log(msg),
}));
