// PRD v4.3 — Cron entry (2h): force-refresh trend snapshots for all shops.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const fnUrl = Deno.env.get("SUPABASE_URL")?.replace(
    ".supabase.co",
    ".supabase.co/functions/v1/get-clinical-trends",
  );

  if (!url || !serviceKey) {
    return new Response(
      JSON.stringify({ ok: false, error: "Missing Supabase env" }),
      { status: 500, headers: corsHeaders },
    );
  }

  const supabase = createClient(url, serviceKey);
  const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
  const targetShopId = body?.shop_id?.toString()?.trim();

  let shopIds: string[] = [];
  if (targetShopId) {
    shopIds = [targetShopId];
  } else {
    const { data } = await supabase.from("shops").select("id").limit(200);
    shopIds = (data ?? []).map((r: { id: string }) => r.id);
  }

  const getTrendsUrl = `${url}/functions/v1/get-clinical-trends`;
  const results: { shop_id: string; ok: boolean }[] = [];

  for (const shopId of shopIds) {
    try {
      const res = await fetch(getTrendsUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceKey}`,
        },
        body: JSON.stringify({ shop_id: shopId, force: true }),
      });
      results.push({ shop_id: shopId, ok: res.ok });
    } catch {
      results.push({ shop_id: shopId, ok: false });
    }
  }

  return new Response(
    JSON.stringify({
      ok: true,
      refreshed: results.filter((r) => r.ok).length,
      total: results.length,
      results,
      cron_note: "Schedule every 2h via Supabase Cron or GitHub Actions",
      get_trends_url: fnUrl,
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
