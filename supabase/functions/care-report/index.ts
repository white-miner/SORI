// SORI P0 S2 — care-report
// POST { "token": "<43-char base64url>" } → safe care report JSON with 10-minute signed photo URLs.
// Deploy with verify_jwt = false (customers open links without logging in); see supabase/config.toml.
// Data access: public.get_care_report_by_token (M1, SECURITY DEFINER, allow-listed columns) via the
// anon key; the service_role key is used only to sign chart_photos objects.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { parseAllowedOrigins } from "../_shared/http.ts";
import { projectHostFromUrl } from "../_shared/media_path.ts";
import { anonClient, makeSigner, readEdgeEnv, rpcFailure } from "../_shared/supabase_deps.ts";
import { createCareReportHandler } from "./handler.ts";

const env = readEdgeEnv();

Deno.serve(createCareReportHandler({
  async getCareReport(token: string) {
    const { data, error, status } = await anonClient(env).rpc("get_care_report_by_token", { p_token: token });
    if (error) return rpcFailure(error, status);
    return { ok: true, data };
  },
  signUrls: makeSigner(env),
  projectHost: projectHostFromUrl(env.url),
  allowedOrigins: parseAllowedOrigins(Deno.env.get("SORI_ALLOWED_ORIGINS")),
  log: (msg) => console.log(msg),
}));
