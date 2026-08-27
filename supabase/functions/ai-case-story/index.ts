// SORI — Internal AI case story for B/A feed (P0a)
// Secrets: OPENAI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type DeIdentifiedPayload = {
  age_band: string | null;
  gender_label: string | null;
  care_name: string;
  concern_chips: string[];
  care_tags: string[];
  device_info: string | null;
  treatment_summary: string;
  director_insight: string;
  skin_sensitivity: string;
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Exact age → Korean age band. Never send raw age to the model. */
function ageBandFromBirthDate(birthDate: string | null | undefined): string | null {
  if (!birthDate) return null;
  const d = new Date(birthDate);
  if (Number.isNaN(d.getTime())) return null;
  const now = new Date();
  let age = now.getFullYear() - d.getFullYear();
  const m = now.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age -= 1;
  if (age < 0 || age > 120) return null;
  const decade = Math.floor(age / 10) * 10;
  const rem = age % 10;
  if (decade < 10) return "10대";
  if (rem <= 2) return `${decade}대 초반`;
  if (rem <= 5) return `${decade}대 중반`;
  return `${decade}대 후반`;
}

function genderLabel(raw: string | null | undefined): string | null {
  const v = (raw ?? "").toLowerCase().trim();
  if (v === "female" || v === "f" || v === "여" || v === "여성") return "여성";
  if (v === "male" || v === "m" || v === "남" || v === "남성") return "남성";
  return null;
}

function asStringArray(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.map((x) => String(x).trim()).filter(Boolean);
}

function buildDeIdentified(chart: Record<string, unknown>, customer: Record<string, unknown> | null): DeIdentifiedPayload {
  // Explicitly omit: name, phone, signature_url, consent_pdf, chart_no, addresses
  return {
    age_band: ageBandFromBirthDate(
      customer?.birth_date != null ? String(customer.birth_date) : null,
    ),
    gender_label: genderLabel(
      customer?.gender != null ? String(customer.gender) : null,
    ),
    care_name: String(chart.care_name ?? "").trim(),
    concern_chips: asStringArray(chart.concern_chips),
    care_tags: asStringArray(chart.care_tags),
    device_info: String(chart.device_info ?? "").trim() || null,
    treatment_summary: String(chart.treatment_summary ?? "").trim(),
    director_insight: String(chart.director_insight ?? "").trim(),
    skin_sensitivity: String(chart.skin_sensitivity ?? "").trim(),
  };
}

const SYSTEM_PROMPT = `당신은 한국 1인 에스테틱·뷰티 클리닉 원장의 톤으로 임상 B/A 케이스 스토리를 씁니다.
규칙:
1. 과장·허위·의료 단정(완치, 진단명 확정 등) 금지. 관찰·케어 중심의 따뜻한 전문가 톤.
2. 본문(body)은 한국어 180~420자. 구조: 맥락 → 고민 → 시술/기기 → 결과 체감.
3. 실명·연락처·정확한 나이를 절대 쓰지 말 것. 연령대·성별만 사용.
4. 반드시 JSON만 출력: {"title":"...","body":"...","hashtags":["#a","#b"]}
5. title은 28자 이내. hashtags는 3~6개, # 포함.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const openaiKey = Deno.env.get("OPENAI_API_KEY") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      return jsonResponse({ error: "Server misconfigured" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const anonClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY") ?? serviceKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await anonClient.auth.getUser();
    if (userErr || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => ({}));
    const chartId = String(body.chart_id ?? "").trim();
    if (!chartId) {
      return jsonResponse({ error: "chart_id required" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: chart, error: chartErr } = await admin
      .from("customer_charts")
      .select(
        "id, shop_id, customer_id, care_name, concern_chips, care_tags, device_info, treatment_summary, director_insight, skin_sensitivity",
      )
      .eq("id", chartId)
      .maybeSingle();

    if (chartErr || !chart) {
      return jsonResponse({ error: "Chart not found" }, 404);
    }

    const { data: shop } = await admin
      .from("shops")
      .select("id, owner_user_id")
      .eq("id", chart.shop_id)
      .maybeSingle();

    if (!shop || shop.owner_user_id !== user.id) {
      return jsonResponse({ error: "Forbidden" }, 403);
    }

    const { data: customer } = await admin
      .from("customers")
      .select("gender, birth_date")
      .eq("id", chart.customer_id)
      .maybeSingle();

    const deid = buildDeIdentified(chart as Record<string, unknown>, customer as Record<string, unknown> | null);

    if (!openaiKey) {
      return jsonResponse({
        title: `${deid.care_name || "시술"} · 임상 케이스`,
        body: localFallbackBody(deid),
        hashtags: defaultHashtags(deid),
        source: "fallback",
        deidentified: deid,
      });
    }

    const userPrompt = `다음 비식별 임상 데이터로 SORI B/A 피드용 스토리를 작성하세요.\n${JSON.stringify(deid, null, 2)}`;

    const aiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${openaiKey}`,
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.65,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: userPrompt },
        ],
      }),
    });

    if (!aiRes.ok) {
      const errText = await aiRes.text();
      console.error("OpenAI error", aiRes.status, errText);
      return jsonResponse({
        title: `${deid.care_name || "시술"} · 임상 케이스`,
        body: localFallbackBody(deid),
        hashtags: defaultHashtags(deid),
        source: "fallback_openai_error",
        deidentified: deid,
      });
    }

    const aiJson = await aiRes.json();
    const content = aiJson?.choices?.[0]?.message?.content ?? "{}";
    let parsed: { title?: string; body?: string; hashtags?: unknown };
    try {
      parsed = JSON.parse(content);
    } catch {
      parsed = {};
    }

    const title = String(parsed.title ?? "").trim() ||
      `${deid.care_name || "시술"} · 임상 케이스`;
    let story = String(parsed.body ?? "").trim() || localFallbackBody(deid);
    if (story.length > 420) story = story.slice(0, 420);
    if (story.length < 80) story = localFallbackBody(deid);

    let hashtags: string[] = [];
    if (Array.isArray(parsed.hashtags)) {
      hashtags = parsed.hashtags.map((h) => {
        const t = String(h).trim();
        if (!t) return "";
        return t.startsWith("#") ? t : `#${t}`;
      }).filter(Boolean);
    } else if (typeof parsed.hashtags === "string") {
      hashtags = parsed.hashtags
        .split(/\s+/)
        .map((t: string) => t.trim())
        .filter(Boolean)
        .map((t: string) => (t.startsWith("#") ? t : `#${t}`));
    }
    if (hashtags.length === 0) hashtags = defaultHashtags(deid);

    return jsonResponse({
      title,
      body: story,
      hashtags,
      source: "openai",
      deidentified: deid,
    });
  } catch (e) {
    console.error(e);
    return jsonResponse({ error: "Internal error" }, 500);
  }
});

function defaultHashtags(deid: DeIdentifiedPayload): string[] {
  const tags = ["#SORI", "#비포애프터", "#에스테틱"];
  const care = deid.care_name.replace(/\s+/g, "");
  if (care) tags.push(`#${care.slice(0, 12)}`);
  return tags.slice(0, 6);
}

function localFallbackBody(deid: DeIdentifiedPayload): string {
  const who = [deid.age_band, deid.gender_label].filter(Boolean).join(" ") || "고객";
  const care = deid.care_name || "케어";
  const concern = deid.concern_chips[0] ?? "피부 컨디션";
  const device = deid.device_info ? ` ${deid.device_info}를 활용해` : "";
  const insight = deid.director_insight || deid.treatment_summary;
  const tail = insight
    ? insight.slice(0, 120)
    : "시술 전후 변화를 기록해 두었습니다. 개인 식별 정보는 포함되지 않습니다.";
  return `${who} 분의 ${concern} 고민에 맞춰 ${care}를 진행했습니다.${device} ${tail}`;
}
