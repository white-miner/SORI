import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-key, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function fail(code: string, message: string, requestId: string, status = 400) {
  return json({ ok: false, code, message, requestId }, status);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();
  try {
    const body = await req.json() as {
      action?: string;
      shop_id?: string;
      request_id?: string;
      payload?: Record<string, unknown>;
    };
    const rid = (body.request_id ?? requestId).toString();
    const action = (body.action ?? "").trim();
    const shopId = (body.shop_id ?? "").trim();
    if (!shopId) return fail("SHOP_REQUIRED", "shop_id가 필요합니다.", rid);

    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ")) {
      return fail("UNAUTHORIZED", "로그인이 필요합니다.", rid, 401);
    }

    const { createClient } = await import("npm:@supabase/supabase-js@2");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData.user) {
      return fail("UNAUTHORIZED", "로그인이 필요합니다.", rid, 401);
    }
    const uid = userData.user.id;

    const { data: shop, error: shopErr } = await supabase
      .from("shops")
      .select("id, owner_user_id")
      .eq("id", shopId)
      .maybeSingle();
    if (shopErr || !shop || shop.owner_user_id !== uid) {
      return fail("FORBIDDEN", "이 샵의 전략 데이터에 접근할 수 없습니다.", rid, 403);
    }

    if (action === "load") {
      const { data, error } = await supabase
        .from("market_strategy_states")
        .select("payload")
        .eq("shop_id", shopId)
        .eq("user_id", uid)
        .maybeSingle();
      if (error) return fail("LOAD_FAILED", "저장본을 읽지 못했습니다.", rid, 500);
      return json({
        ok: true,
        code: "OK",
        message: "ok",
        requestId: rid,
        payload: data?.payload ?? {},
      });
    }

    if (action === "save") {
      const payload = body.payload ?? {};
      const { error } = await supabase.from("market_strategy_states").upsert({
        shop_id: shopId,
        user_id: uid,
        payload,
        updated_at: new Date().toISOString(),
      }, { onConflict: "shop_id,user_id" });
      if (error) return fail("SAVE_FAILED", "저장하지 못했습니다.", rid, 500);
      return json({ ok: true, code: "OK", message: "saved", requestId: rid });
    }

    return fail("BAD_ACTION", "action은 load 또는 save만 가능합니다.", rid);
  } catch {
    return fail("UNHANDLED", "요청을 처리하지 못했습니다.", requestId, 500);
  }
});
