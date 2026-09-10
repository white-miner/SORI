// PRD v7.6 Phase 3a — 상가정보 + 행정동 인구 → 경영 ZONE 3
// Secrets: SBIZ_STORE_SERVICE_KEY, MOIS_POP_SERVICE_KEY, KAKAO_REST_API_KEY
// action=resolve_address → 주소만으로 행정동 코드 자동 연결
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface MarketBody {
  /** resolve_address | market(default) */
  action?: string;
  address?: string;
  shop_id?: string;
  latitude?: number;
  longitude?: number;
  /** 행정기관코드(행정동) 10자리 권장 */
  adm_cd?: string;
  /** 업종 라벨 — 클라이언트 필터 힌트 */
  category?: string;
  /** 반경 m (기본 500) */
  radius_m?: number;
  location_label?: string;
}

type AgeBucket = {
  label: string;
  male: number;
  female: number;
  total: number;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function num(v: unknown): number {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  const n = Number(String(v ?? "").replace(/,/g, ""));
  return Number.isFinite(n) ? n : 0;
}

function categoryKeywords(category: string): string[] {
  const c = category.trim();
  if (c.includes("네일")) return ["네일", "손톱"];
  if (c.includes("바버") || c.includes("이발")) return ["바버", "이발", "남성전문"];
  if (c.includes("타투")) return ["타투", "문신"];
  if (c.includes("미용")) return ["미용", "헤어", "두발"];
  // 에스테틱 기본
  return ["피부", "에스테틱", "마사지", "체형", "미용", "네일", "왁싱"];
}

function matchesCategory(item: Record<string, unknown>, keywords: string[]): boolean {
  const blob = [
    item.indsLclsNm,
    item.indsMclsNm,
    item.indsSclsNm,
    item.lclsNm,
    item.mclsNm,
    item.sclsNm,
    item.indutyLclasNm,
    item.indutyMlsfcNm,
    item.indutySclasNm,
  ]
    .map((x) => String(x ?? ""))
    .join(" ");
  if (!blob.trim()) return true; // 업종명 없으면 반경 전체 카운트에 포함
  return keywords.some((k) => blob.includes(k));
}

function extractStoreItems(payload: unknown): Record<string, unknown>[] {
  if (!payload || typeof payload !== "object") return [];
  const root = payload as Record<string, unknown>;
  // sdsc2 JSON 변형 대응
  const body = (root.body ?? root.response ?? root) as Record<string, unknown>;
  const items =
    body.items ??
    (body.body as Record<string, unknown> | undefined)?.items ??
    root.items;
  if (Array.isArray(items)) {
    return items.filter((x) => x && typeof x === "object") as Record<
      string,
      unknown
    >[];
  }
  if (items && typeof items === "object") {
    const item = (items as Record<string, unknown>).item;
    if (Array.isArray(item)) {
      return item.filter((x) => x && typeof x === "object") as Record<
        string,
        unknown
      >[];
    }
    if (item && typeof item === "object") return [item as Record<string, unknown>];
  }
  return [];
}

async function fetchStores(opts: {
  key: string;
  lat: number;
  lng: number;
  radiusM: number;
  category: string;
}): Promise<{
  ok: boolean;
  totalInRadius: number;
  sameCategoryCount: number;
  sampleNames: string[];
  error?: string;
}> {
  const keywords = categoryKeywords(opts.category);
  const url =
    `https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInRadius` +
    `?serviceKey=${encodeURIComponent(opts.key)}` +
    `&pageNo=1&numOfRows=100&radius=${opts.radiusM}` +
    `&cx=${opts.lng}&cy=${opts.lat}&type=json`;

  try {
    const res = await fetch(url);
    const text = await res.text();
    let payload: unknown;
    try {
      payload = JSON.parse(text);
    } catch {
      return {
        ok: false,
        totalInRadius: 0,
        sameCategoryCount: 0,
        sampleNames: [],
        error: `store_non_json status=${res.status}`,
      };
    }
    const items = extractStoreItems(payload);
    const matched = items.filter((it) => matchesCategory(it, keywords));
    const names = matched
      .map((it) => String(it.bizesNm ?? it.bizesNm ?? it.storeNm ?? it.name ?? ""))
      .filter((n) => n.length > 0)
      .slice(0, 5);
    return {
      ok: true,
      totalInRadius: items.length,
      sameCategoryCount: matched.length,
      sampleNames: names,
    };
  } catch (e) {
    return {
      ok: false,
      totalInRadius: 0,
      sameCategoryCount: 0,
      sampleNames: [],
      error: String(e),
    };
  }
}

function yyyymmKst(d = new Date()): string {
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  // 공표 지연 대비 전월
  kst.setUTCMonth(kst.getUTCMonth() - 1);
  const y = kst.getUTCFullYear();
  const m = String(kst.getUTCMonth() + 1).padStart(2, "0");
  return `${y}${m}`;
}

function extractPopRows(payload: unknown): Record<string, unknown>[] {
  if (!payload || typeof payload !== "object") return [];
  const root = payload as Record<string, unknown>;
  // 흔한 래핑: response.body.items.item | data | row
  const candidates: unknown[] = [];
  const walk = (node: unknown, depth: number) => {
    if (depth > 6 || node == null) return;
    if (Array.isArray(node)) {
      if (
        node.length > 0 &&
        typeof node[0] === "object" &&
        node[0] !== null &&
        ("totPpltn" in (node[0] as object) ||
          "totNmprCnt" in (node[0] as object) ||
          "malePpltnCnt" in (node[0] as object) ||
          "남자인구수" in (node[0] as object) ||
          "totPopulation" in (node[0] as object))
      ) {
        candidates.push(node);
      }
      for (const x of node) walk(x, depth + 1);
      return;
    }
    if (typeof node === "object") {
      for (const v of Object.values(node as Record<string, unknown>)) {
        walk(v, depth + 1);
      }
    }
  };
  walk(root, 0);
  if (candidates.length > 0) {
    return (candidates[0] as unknown[]).filter(
      (x) => x && typeof x === "object",
    ) as Record<string, unknown>[];
  }
  return [];
}

function aggregatePopulation(rows: Record<string, unknown>[]): {
  total: number;
  male: number;
  female: number;
  ages: AgeBucket[];
  dongName: string;
} {
  let total = 0;
  let male = 0;
  let female = 0;
  let dongName = "";

  const ageDefs: { label: string; mKeys: string[]; fKeys: string[] }[] = [
    {
      label: "0-19",
      mKeys: ["male0To9AgePpltnCnt", "male10To19AgePpltnCnt", "만0~9세남자", "만10~19세남자"],
      fKeys: ["female0To9AgePpltnCnt", "female10To19AgePpltnCnt", "만0~9세여자", "만10~19세여자"],
    },
    {
      label: "20-29",
      mKeys: ["male20To29AgePpltnCnt", "만20~29세남자"],
      fKeys: ["female20To29AgePpltnCnt", "만20~29세여자"],
    },
    {
      label: "30-39",
      mKeys: ["male30To39AgePpltnCnt", "만30~39세남자"],
      fKeys: ["female30To39AgePpltnCnt", "만30~39세여자"],
    },
    {
      label: "40-49",
      mKeys: ["male40To49AgePpltnCnt", "만40~49세남자"],
      fKeys: ["female40To49AgePpltnCnt", "만40~49세여자"],
    },
    {
      label: "50+",
      mKeys: [
        "male50To59AgePpltnCnt",
        "male60To69AgePpltnCnt",
        "male70To79AgePpltnCnt",
        "male80To89AgePpltnCnt",
        "male90To99AgePpltnCnt",
        "male100AgeAbovePpltnCnt",
        "만50~59세남자",
        "만60~69세남자",
        "만70~79세남자",
        "만80~89세남자",
        "만90~99세남자",
        "만100세이상남자",
      ],
      fKeys: [
        "female50To59AgePpltnCnt",
        "female60To69AgePpltnCnt",
        "female70To79AgePpltnCnt",
        "female80To89AgePpltnCnt",
        "female90To99AgePpltnCnt",
        "female100AgeAbovePpltnCnt",
        "만50~59세여자",
        "만60~69세여자",
        "만70~79세여자",
        "만80~89세여자",
        "만90~99세여자",
        "만100세이상여자",
      ],
    },
  ];

  const ageAcc = ageDefs.map((d) => ({
    label: d.label,
    male: 0,
    female: 0,
    total: 0,
  }));

  for (const row of rows) {
    if (!dongName) {
      dongName = String(
        row.admmNm ?? row.dongNm ?? row.행정동명 ?? row.admNm ?? "",
      );
    }
    total += num(
      row.totNmprCnt ?? row.totPpltn ?? row.totPopulation ?? row.총인구수,
    );
    male += num(
      row.maleNmprCnt ?? row.malePpltnCnt ?? row.남자인구수,
    );
    female += num(
      row.femaleNmprCnt ?? row.femalePpltnCnt ?? row.여자인구수,
    );

    ageDefs.forEach((def, i) => {
      for (const k of def.mKeys) ageAcc[i].male += num(row[k]);
      for (const k of def.fKeys) ageAcc[i].female += num(row[k]);
    });
  }

  for (const a of ageAcc) a.total = a.male + a.female;

  return { total, male, female, ages: ageAcc, dongName };
}

async function fetchPopulation(opts: {
  key: string;
  admCd: string;
  statsYm: string;
}): Promise<{
  ok: boolean;
  total: number;
  male: number;
  female: number;
  ages: AgeBucket[];
  dongName: string;
  statsYm: string;
  error?: string;
}> {
  const adm = opts.admCd.trim();
  if (!adm) {
    return {
      ok: false,
      total: 0,
      male: 0,
      female: 0,
      ages: [],
      dongName: "",
      statsYm: opts.statsYm,
      error: "adm_cd_required",
    };
  }

  // 행안부 주민등록 OpenAPI — 엔드포인트는 기관 스펙 변경에 대비해 2경로 시도
  const bases = [
    Deno.env.get("MOIS_POP_API_URL")?.trim(),
    "https://apis.data.go.kr/1741000/stdgPpltnInfoService/getStdgPpltnInfo",
    "https://apis.data.go.kr/1741000/admmPpltnInfoService/getAdmmPpltnInfo",
  ].filter((x): x is string => !!x && x.length > 0);

  let lastErr = "no_endpoint";
  for (const base of bases) {
    const url =
      `${base}?serviceKey=${encodeURIComponent(opts.key)}` +
      `&pageNo=1&numOfRows=300&resultType=json&type=json` +
      `&stdgCd=${encodeURIComponent(adm)}` +
      `&admmCd=${encodeURIComponent(adm)}` +
      `&srchFrYm=${opts.statsYm}&srchToYm=${opts.statsYm}` +
      `&statsYm=${opts.statsYm}&statsYearMonth=${opts.statsYm}`;

    try {
      const res = await fetch(url);
      const text = await res.text();
      let payload: unknown;
      try {
        payload = JSON.parse(text);
      } catch {
        lastErr = `pop_non_json status=${res.status}`;
        continue;
      }
      const rows = extractPopRows(payload);
      if (rows.length === 0) {
        lastErr = `pop_empty status=${res.status}`;
        continue;
      }
      const agg = aggregatePopulation(rows);
      return {
        ok: true,
        total: agg.total,
        male: agg.male,
        female: agg.female,
        ages: agg.ages,
        dongName: agg.dongName,
        statsYm: opts.statsYm,
      };
    } catch (e) {
      lastErr = String(e);
    }
  }

  return {
    ok: false,
    total: 0,
    male: 0,
    female: 0,
    ages: [],
    dongName: "",
    statsYm: opts.statsYm,
    error: lastErr,
  };
}

async function resolveAddressWithKakao(address: string): Promise<{
  ok: boolean;
  latitude?: number;
  longitude?: number;
  adm_cd?: string;
  dong_name?: string;
  display_label?: string;
  error?: string;
}> {
  const key = Deno.env.get("KAKAO_REST_API_KEY")?.trim() ?? "";
  if (!key) {
    return { ok: false, error: "missing_KAKAO_REST_API_KEY" };
  }
  const trimmed = address.trim();
  if (!trimmed) return { ok: false, error: "empty_address" };

  try {
    const searchUrl =
      `https://dapi.kakao.com/v2/local/search/address.json` +
      `?query=${encodeURIComponent(trimmed)}`;
    const searchRes = await fetch(searchUrl, {
      headers: { Authorization: `KakaoAK ${key}` },
    });
    const searchJson = await searchRes.json();
    const doc = searchJson?.documents?.[0];
    if (!doc) return { ok: false, error: "address_not_found" };

    const lat = Number(doc.y);
    const lng = Number(doc.x);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return { ok: false, error: "bad_coords" };
    }

    let admCd = String(doc.address?.h_code ?? "").trim();
    let dongName = String(doc.address?.region_3depth_name ?? "").trim();

    if (!admCd) {
      const regionUrl =
        `https://dapi.kakao.com/v2/local/geo/coord2regioncode.json` +
        `?x=${lng}&y=${lat}`;
      const regionRes = await fetch(regionUrl, {
        headers: { Authorization: `KakaoAK ${key}` },
      });
      const regionJson = await regionRes.json();
      const docs = regionJson?.documents ?? [];
      const h = docs.find((d: { region_type?: string }) => d.region_type === "H") ??
        docs[0];
      admCd = String(h?.code ?? "").trim();
      dongName = String(h?.region_3depth_name ?? dongName).trim();
    }

    if (!admCd) {
      return {
        ok: false,
        latitude: lat,
        longitude: lng,
        error: "adm_cd_not_found",
      };
    }

    return {
      ok: true,
      latitude: lat,
      longitude: lng,
      adm_cd: admCd,
      dong_name: dongName,
      display_label: dongName || admCd,
    };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as MarketBody;

    if ((body.action ?? "").trim() === "resolve_address") {
      const resolved = await resolveAddressWithKakao(body.address ?? "");
      return jsonResponse({
        ...resolved,
        fetched_at: new Date().toISOString(),
      });
    }

    const lat = body.latitude ?? 35.8562;
    const lng = body.longitude ?? 129.2247;
    const radiusM = Math.min(Math.max(body.radius_m ?? 500, 100), 2000);
    const category = body.category ?? "에스테틱";
    const locationLabel = body.location_label ?? "매장";
    const admCd = (body.adm_cd ?? "").trim();
    const statsYm = yyyymmKst();

    const sbizKey = Deno.env.get("SBIZ_STORE_SERVICE_KEY") ?? "";
    const moisKey = Deno.env.get("MOIS_POP_SERVICE_KEY") ?? "";

    const stores = sbizKey
      ? await fetchStores({
        key: sbizKey,
        lat,
        lng,
        radiusM,
        category,
      })
      : {
        ok: false,
        totalInRadius: 0,
        sameCategoryCount: 0,
        sampleNames: [] as string[],
        error: "missing_SBIZ_STORE_SERVICE_KEY",
      };

    const population = moisKey
      ? await fetchPopulation({ key: moisKey, admCd, statsYm })
      : {
        ok: false,
        total: 0,
        male: 0,
        female: 0,
        ages: [] as AgeBucket[],
        dongName: "",
        statsYm,
        error: "missing_MOIS_POP_SERVICE_KEY",
      };

    const densityHint =
      population.ok && population.total > 0 && stores.ok
        ? Number(
          (stores.sameCategoryCount / (population.total / 1000)).toFixed(2),
        )
        : null;

    return jsonResponse({
      ok: stores.ok || population.ok,
      shop_id: body.shop_id ?? "",
      location_label: locationLabel,
      latitude: lat,
      longitude: lng,
      radius_m: radiusM,
      category,
      estimate: true,
      sources: [
        "소상공인시장진흥공단 상가(상권)정보",
        "행정안전부 행정동별 성/연령별 주민등록 인구수",
      ],
      fetched_at: new Date().toISOString(),
      stats_ym: statsYm,
      stores: {
        ok: stores.ok,
        total_in_radius: stores.totalInRadius,
        same_category_count: stores.sameCategoryCount,
        sample_names: stores.sampleNames,
        error: stores.error ?? null,
      },
      population: {
        ok: population.ok,
        adm_cd: admCd || null,
        dong_name: population.dongName || null,
        total: population.total,
        male: population.male,
        female: population.female,
        ages: population.ages,
        error: population.error ?? null,
      },
      /** 동종 점포수 / 인구 천명 — 참고 지표 */
      stores_per_1k_pop: densityHint,
    });
  } catch (e) {
    return jsonResponse(
      {
        ok: false,
        estimate: true,
        error: String(e),
        fetched_at: new Date().toISOString(),
        stores: { ok: false, total_in_radius: 0, same_category_count: 0 },
        population: { ok: false, total: 0, male: 0, female: 0, ages: [] },
      },
      200,
    );
  }
});
