// PRD v4.3 — CCKS 15 keywords → Naver DataLab → CTI snapshot (2h cache).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const CACHE_TTL_MS = 2 * 60 * 60 * 1000; // PO §8: 2h stale OK

interface KeywordDef {
  id: string;
  keyword: string;
  category: string;
  poPriority: number;
  headline: string;
  narrativeTemplate: string;
}

const CORE_KEYWORDS: KeywordDef[] = [
  { id: "K01", keyword: "홍조", category: "barrier_sensitive", poPriority: 100, headline: "홍조 검색 급증", narrativeTemplate: "요즘 '홍조' 검색이 {surge}% 올랐어요. 장벽·진정 쪽 먼저 여쭤보시면 고객이 트렌드까지 아는 샵이라고 느낍니다." },
  { id: "K02", keyword: "피부장벽", category: "barrier_sensitive", poPriority: 95, headline: "피부장벽 관심↑", narrativeTemplate: "'피부장벽' 고민 검색이 {surge}% 증가했습니다. TEWL·민감 반응을 짚어 주시면 신뢰가 빨리 쌓입니다." },
  { id: "K03", keyword: "트러블", category: "trouble_sebum", poPriority: 90, headline: "트러블 수요 활발", narrativeTemplate: "'트러블' 검색이 {surge}% 올랐어요. 활성 여부와 홈케어 루틴부터 가볍게 확인해 보세요." },
  { id: "K04", keyword: "모공", category: "trouble_sebum", poPriority: 85, headline: "모공 고민 트렌드", narrativeTemplate: "'모공' 검색이 {surge}% 증가 중입니다. 과도한 각질 제거보다 피지 밸런스 관점으로 상담하세요." },
  { id: "K05", keyword: "각질", category: "trouble_sebum", poPriority: 80, headline: "각질 케어 수요", narrativeTemplate: "'각질' 검색이 {surge}% 올랐습니다. 계절·장벽 상태에 맞는 각질 케어 강도를 먼저 맞춰 주세요." },
  { id: "K06", keyword: "수분폭탄", category: "hydration", poPriority: 75, headline: "수분폭탄 인기", narrativeTemplate: "'수분폭탄' 검색이 {surge}% 급증했어요. 속건조·TEWL과 연결해 패키지 제안 포인트를 잡으세요." },
  { id: "K07", keyword: "속건조", category: "hydration", poPriority: 70, headline: "속건조 관심↑", narrativeTemplate: "'속건조' 검색이 {surge}% 올랐습니다. 겉유분과 속당김을 구분해 질문하면 전문성이 드러납니다." },
  { id: "K08", keyword: "탄력리프팅", category: "lifting_body", poPriority: 65, headline: "탄력리프팅 수요", narrativeTemplate: "'탄력리프팅' 검색이 {surge}% 증가했습니다. HIFU·리프팅 기대치를 먼저 듣고 강도를 맞추세요." },
  { id: "K09", keyword: "주름", category: "lifting_body", poPriority: 60, headline: "주름 상담 트렌드", narrativeTemplate: "'주름' 검색이 {surge}% 올랐어요. 표정습관·선택 부위를 함께 짚어 주시면 만족도가 올라갑니다." },
  { id: "K10", keyword: "뱃살관리", category: "lifting_body", poPriority: 55, headline: "뱃살관리 관심", narrativeTemplate: "'뱃살관리' 검색이 {surge}% 증가 중입니다. 바디 프로그램 연계 시 기대 기간을 명확히 안내하세요." },
  { id: "K11", keyword: "셀룰라이트", category: "lifting_body", poPriority: 50, headline: "셀룰라이트 수요", narrativeTemplate: "'셀룰라이트' 검색이 {surge}% 올랐습니다. 생활습관·림프 순환 관점의 질문으로 상담을 시작하세요." },
  { id: "K12", keyword: "기미잡티", category: "pigment_tone", poPriority: 45, headline: "기미잡티 검색↑", narrativeTemplate: "'기미잡티' 검색이 {surge}% 급증했어요. 자외선·색소 타입을 먼저 확인하고 레이저 강도를 조절하세요." },
  { id: "K13", keyword: "색소침착", category: "pigment_tone", poPriority: 40, headline: "색소침착 관심", narrativeTemplate: "'색소침착' 검색이 {surge}% 올랐습니다. PIH 이력과 홈케어 SPF 습관을 함께 점검하세요." },
  { id: "K14", keyword: "피부결", category: "pigment_tone", poPriority: 35, headline: "피부결 트렌드", narrativeTemplate: "'피부결' 검색이 {surge}% 증가했습니다. 결·광채 목표를 구체화하면 시술 플랜이 명확해집니다." },
  { id: "K15", keyword: "두피각질", category: "scalp", poPriority: 30, headline: "두피각질 수요", narrativeTemplate: "'두피각질' 검색이 {surge}% 올랐어요. 두피·모발 동시 고민인지 가볍게 확인해 보세요." },
];

function clamp(v: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, v));
}

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function hourBucket(d: Date): string {
  const b = new Date(d);
  b.setUTCMinutes(0, 0, 0);
  b.setUTCMinutes(Math.floor(b.getUTCMinutes() / 120) * 120); // 2h buckets
  return b.toISOString();
}

function minMaxNorm(values: number[]): number[] {
  const min = Math.min(...values);
  const max = Math.max(...values);
  if (max <= min) return values.map(() => 50);
  return values.map((v) => ((v - min) / (max - min)) * 100);
}

function computeCti(
  ratios: number[],
  def: KeywordDef,
): { cti: number; surgePct: number; sparkline: number[]; naverScore: number } {
  const sparkline = ratios.slice(-7);
  const last = sparkline[sparkline.length - 1] ?? 0;
  const avg7 = sparkline.length
    ? sparkline.reduce((a, b) => a + b, 0) / sparkline.length
    : last;
  const surgePct = avg7 > 0 ? Math.round(((last - avg7) / avg7) * 100) : 0;
  const naverNorm = minMaxNorm(sparkline);
  const naverScore = Math.round(naverNorm[naverNorm.length - 1] ?? 50);
  const surgeNorm = clamp((surgePct + 20) * 2.5, 0, 100);
  const rawCti = 0.9 * naverScore; // Naver-only MVP (Google slot reserved)
  const cti = Math.round(clamp(0.7 * rawCti + 0.3 * surgeNorm, 0, 100));
  return { cti, surgePct, sparkline, naverScore };
}

function qualifiesForTop(cti: number, surgePct: number): boolean {
  return surgePct >= 5 || cti >= 40;
}

async function fetchNaverBatch(
  clientId: string,
  clientSecret: string,
  keywords: KeywordDef[],
  startDate: string,
  endDate: string,
): Promise<Map<string, number[]>> {
  const out = new Map<string, number[]>();
  const body = {
    startDate,
    endDate,
    timeUnit: "date",
    keywordGroups: keywords.map((k) => ({
      groupName: k.id,
      keywords: [k.keyword],
    })),
    device: "",
    ages: [],
    gender: "",
  };

  const res = await fetch("https://openapi.naver.com/v1/datalab/search", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Naver-Client-Id": clientId,
      "X-Naver-Client-Secret": clientSecret,
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    throw new Error(`Naver DataLab HTTP ${res.status}`);
  }

  const json = await res.json();
  const results = json?.results ?? [];
  for (const r of results) {
    const id = r?.title ?? "";
    const data = Array.isArray(r?.data) ? r.data : [];
    out.set(
      id,
      data.map((d: { ratio?: number }) => Number(d?.ratio ?? 0)),
    );
  }
  return out;
}

function fallbackRatios(seed: number): number[] {
  const base = 40 + (seed % 30);
  return Array.from({ length: 7 }, (_, i) =>
    Math.round(base + Math.sin(i + seed) * 8 + i * 2)
  );
}

async function buildSnapshot(source: string): Promise<Record<string, unknown>> {
  const now = new Date();
  const end = fmtDate(now);
  const start = fmtDate(new Date(now.getTime() - 8 * 86400000));

  const clientId = Deno.env.get("NAVER_DATALAB_CLIENT_ID") ?? "";
  const clientSecret = Deno.env.get("NAVER_DATALAB_CLIENT_SECRET") ?? "";

  const ratioMap = new Map<string, number[]>();

  if (clientId && clientSecret) {
    try {
      for (let i = 0; i < CORE_KEYWORDS.length; i += 5) {
        const batch = CORE_KEYWORDS.slice(i, i + 5);
        const batchMap = await fetchNaverBatch(
          clientId,
          clientSecret,
          batch,
          start,
          end,
        );
        for (const [k, v] of batchMap) ratioMap.set(k, v);
      }
    } catch (e) {
      console.error("Naver fetch failed, using fallback:", e);
    }
  }

  const items = CORE_KEYWORDS.map((def, idx) => {
    const ratios = ratioMap.get(def.id) ?? fallbackRatios(idx * 7 + 13);
    const { cti, surgePct, sparkline, naverScore } = computeCti(ratios, def);
    const narrative = def.narrativeTemplate.replace("{surge}", String(surgePct));
    return {
      id: def.id,
      keyword: def.keyword,
      category: def.category,
      po_priority: def.poPriority,
      cti,
      surge_pct: surgePct,
      naver_score: naverScore,
      google_score: null,
      sparkline_7d: sparkline,
      headline: def.headline,
      narrative,
      qualifies: qualifiesForTop(cti, surgePct),
    };
  });

  const ranked = [...items].sort((a, b) => {
    if (b.cti !== a.cti) return b.cti - a.cti;
    if (b.surge_pct !== a.surge_pct) return b.surge_pct - a.surge_pct;
    return b.po_priority - a.po_priority;
  });

  const top3 = ranked.filter((i) => i.qualifies).slice(0, 3);
  const top1 = top3[0] ?? ranked[0] ?? null;

  return {
    items,
    top3,
    top1,
    has_surge: top3.length > 0,
    fetched_at: now.toISOString(),
    source: ratioMap.size > 0 ? source : "fallback",
    cache_ttl_hours: 2,
  };
}

async function readCachedSnapshot(
  shopId: string,
): Promise<{ trend_json: Record<string, unknown>; fetched_at: string } | null> {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;

  const supabase = createClient(url, key);
  const { data } = await supabase
    .from("shop_clinical_trend_snapshots")
    .select("trend_json, fetched_at")
    .eq("shop_id", shopId)
    .order("hour_bucket", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!data?.fetched_at) return null;
  const age = Date.now() - new Date(data.fetched_at).getTime();
  if (age > CACHE_TTL_MS) return null;
  return data as { trend_json: Record<string, unknown>; fetched_at: string };
}

async function writeSnapshot(
  shopId: string,
  trendJson: Record<string, unknown>,
): Promise<void> {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return;

  const supabase = createClient(url, key);
  const bucket = hourBucket(new Date());
  await supabase.from("shop_clinical_trend_snapshots").upsert(
    {
      shop_id: shopId,
      hour_bucket: bucket,
      trend_json: trendJson,
      fetched_at: trendJson.fetched_at ?? new Date().toISOString(),
      source: trendJson.source ?? "naver",
    },
    { onConflict: "shop_id,hour_bucket" },
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = req.method === "POST" ? await req.json() : {};
    const shopId = body?.shop_id?.toString()?.trim() ?? "";
    const force = body?.force === true;

    if (shopId && !force) {
      const cached = await readCachedSnapshot(shopId);
      if (cached?.trend_json) {
        return new Response(
          JSON.stringify({ ...cached.trend_json, cached: true }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

    const snapshot = await buildSnapshot("naver");
    if (shopId) {
      await writeSnapshot(shopId, snapshot);
    }

    return new Response(JSON.stringify({ ...snapshot, cached: false }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    const fallback = await buildSnapshot("error_fallback");
    return new Response(
      JSON.stringify({ ...fallback, cached: false, error: String(e) }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
