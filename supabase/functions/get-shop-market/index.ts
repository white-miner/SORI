// PRD v7.6 Phase 3a — 상가정보 + 행정동 인구 → 경영 ZONE 3
// Secrets: SBIZ_STORE_SERVICE_KEY, MOIS_POP_SERVICE_KEY, KAKAO_REST_API_KEY
// action=resolve_address → 주소만으로 행정동 코드 자동 연결
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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
  if (c === '전체' || c.toLowerCase() === 'all') return [];
  if (c.includes('네일')) return ['네일', '손톱'];
  if (c.includes('바버') || c.includes('이발')) return ['바버', '이발', '남성전문', '이용업', '이용원'];
  if (c.includes('타투')) return ['타투', '문신'];
  if (c.includes('반영구')) return ['반영구', '반영구화장', '눈썹문신', '아이라인'];
  if (c.includes('미용')) return ['두발미용', '헤어', '미용실'];
  if (c.includes('피부') || c.includes('에스테틱')) {
    return ['피부미용', '피부관리', '에스테틱', '스킨케어'];
  }
  return ['피부', '에스테틱', '마사지', '체형', '미용', '네일', '왁싱'];
}

function storeBlob(item: Record<string, unknown>): string {
  return [
    item.indsLclsNm,
    item.indsMclsNm,
    item.indsSclsNm,
    item.lclsNm,
    item.mclsNm,
    item.sclsNm,
    item.indutyLclasNm,
    item.indutyMlsfcNm,
    item.indutySclasNm,
    item.ksicNm,
  ]
    .map((x) => String(x ?? ''))
    .join(' ');
}

function matchesCategory(item: Record<string, unknown>, keywords: string[]): boolean {
  if (keywords.length === 0) return true;
  const blob = storeBlob(item).replace(/\s+/g, "");
  if (!blob.trim()) return true;
  return keywords.some((k) => blob.includes(k));
}

function chipKeyForStore(item: Record<string, unknown>): string {
  const blob = storeBlob(item).replace(/\s+/g, "");
  const name = String(item.bizesNm ?? item.storeNm ?? "").replace(/\s+/g, "");
  // Service shops only: a skin clinic, nail school or “스타투어” travel
  // agency must not become a beauty shop through a substring match.
  if (/의원|병원|의료|학원|교육|훈련|소매|도매|여행|제조/.test(blob)) return "other";
  if (/반영구|눈썹문신/.test(name)) return "semi_permanent";
  if (/타투|tattoo/i.test(name)) return "tattoo";
  if (/바버|barber/i.test(name)) return "barber";
  if (/네일|nail/i.test(name)) return "nail";
  if (/메이크업|makeup/i.test(name)) return "makeup";
  if (/메이크업|화장분장|메이크업/.test(blob)) return "makeup";
  // 원문 분류명. 짧은 '미용' 토큰을 피부미용업보다 먼저 쓰면 피부가 헤어로 간다.
  if (/피부미용|피부관리|에스테틱|스킨케어/.test(blob)) return "skin";
  if (/두발미용/.test(blob)) return "hair";
  if (/이용업/.test(blob) && !/이용및미용/.test(blob) && !/미용업/.test(blob)) {
    return "barber";
  }
  if (/네일|손톱/.test(blob)) return "nail";
  if (/바버|이발|남성전문|이용원/.test(blob) && !/두발미용|미용실/.test(blob)) {
    return "barber";
  }
  if (/반영구/.test(blob)) return "semi_permanent";
  if (/타투|문신/.test(blob)) return "tattoo";
  if (/헤어샵|헤어|미용실/.test(blob) && !/피부미용/.test(blob)) return "hair";
  if (/피부|왁싱/.test(blob)) return "skin";
  return "other";
}

function storeLatLng(item: Record<string, unknown>): { lat: number; lng: number } | null {
  const lat = num(item.lat ?? item.y ?? item.ycord ?? item.cy);
  const lng = num(item.lon ?? item.lng ?? item.x ?? item.xcord ?? item.cx);
  if (Math.abs(lat) < 0.01 || Math.abs(lng) < 0.01) return null;
  if (lat < 33 || lat > 39 || lng < 124 || lng > 132) return null;
  return { lat, lng };
}

function haversineM(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

type StoreItemOut = {
  name: string;
  category_label: string;
  chip_key: string;
  lat: number;
  lng: number;
  distance_m: number;
  address: string;
  bizes_id: string;
  inds_lcls_cd: string;
  inds_lcls_nm: string;
  inds_mcls_cd: string;
  inds_mcls_nm: string;
  inds_scls_cd: string;
  inds_scls_nm: string;
  lot_address: string;
  addr: string;
  ctprvn_cd: string;
  ctprvn_nm: string;
  signgu_cd: string;
  signgu_nm: string;
  adong_cd: string;
  adong_nm: string;
};

function rawText(row: Record<string, unknown>, key: string): string {
  if (!(key in row) || row[key] == null) return "";
  return String(row[key]).trim();
}

function readTotalCount(payload: unknown): number | null {
  if (!payload || typeof payload !== "object") return null;
  const root = payload as Record<string, unknown>;
  const body = (root.body ??
    (root.response as Record<string, unknown> | undefined)?.body) as
    | Record<string, unknown>
    | undefined;
  const raw = body?.totalCount ?? body?.totalcount;
  const n = num(raw);
  return n > 0 || raw === 0 || raw === "0" ? n : null;
}
function headerResultCode(payload: unknown): string {
  if (!payload || typeof payload !== "object") return "";
  const root = payload as Record<string, unknown>;
  const header = (root.header ??
    (root.response as Record<string, unknown> | undefined)?.header ??
    (root.cmmMsgHeader as Record<string, unknown> | undefined)) as
    | Record<string, unknown>
    | undefined;
  return String(
    header?.resultCode ??
      header?.returnReasonCode ??
      header?.errMsg ??
      "",
  ).trim();
}

function looksLikeStore(row: Record<string, unknown>): boolean {
  return (
    "bizesNm" in row ||
    "storeNm" in row ||
    "bizesId" in row
  );
}

function extractStoreItems(payload: unknown): Record<string, unknown>[] {
  const found: Record<string, unknown>[] = [];
  const walk = (node: unknown, depth: number) => {
    if (depth > 8 || node == null) return;
    if (Array.isArray(node)) {
      const maps: Record<string, unknown>[] = [];
      for (const e of node) {
        maps.push(...coerceStoreMaps(e));
      }
      if (maps.some((m) => looksLikeStore(m))) {
        for (const m of maps) {
          if (looksLikeStore(m)) found.push(m);
        }
        return;
      }
      for (const e of node) walk(e, depth + 1);
      return;
    }
    if (typeof node === "object") {
      const map = node as Record<string, unknown>;
      if ("item" in map) {
        walk(map.item, depth + 1);
        return;
      }
      if ("items" in map) {
        walk(map.items, depth + 1);
        return;
      }
      if (looksLikeStore(map)) {
        found.push(map);
        return;
      }
      for (const v of Object.values(map)) walk(v, depth + 1);
    }
  };
  walk(payload, 0);
  return found;
}

function coerceStoreMaps(node: unknown): Record<string, unknown>[] {
  if (Array.isArray(node)) {
    return node.flatMap(coerceStoreMaps);
  }
  if (node && typeof node === "object") {
    const map = node as Record<string, unknown>;
    if ("item" in map && !looksLikeStore(map)) {
      return coerceStoreMaps(map.item);
    }
    return [map];
  }
  return [];
}

function xmlTag(block: string, name: string): string {
  const m = new RegExp("<" + name + ">([^<]*)</" + name + ">", "i").exec(block);
  return (m?.[1] ?? "").trim();
}

function extractXmlItemMaps(xml: string): Record<string, unknown>[] {
  const out: Record<string, unknown>[] = [];
  const re = /<item>([\s\S]*?)<\/item>/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(xml)) !== null) {
    const body = m[1];
    out.push({
      bizesNm: xmlTag(body, "bizesNm") || xmlTag(body, "storeNm"),
      bizesId: xmlTag(body, "bizesId"),
      storeNm: xmlTag(body, "storeNm"),
      lat: xmlTag(body, "lat") || xmlTag(body, "cy"),
      lon: xmlTag(body, "lon") || xmlTag(body, "lng") || xmlTag(body, "cx"),
      lng: xmlTag(body, "lng"),
      rdnmAdr: xmlTag(body, "rdnmAdr"),
      lnoAdr: xmlTag(body, "lnoAdr"),
      addr: xmlTag(body, "addr"),
      indsLclsCd: xmlTag(body, "indsLclsCd"),
      indsLclsNm: xmlTag(body, "indsLclsNm"),
      indsMclsCd: xmlTag(body, "indsMclsCd"),
      indsMclsNm: xmlTag(body, "indsMclsNm"),
      indsSclsCd: xmlTag(body, "indsSclsCd"),
      indsSclsNm: xmlTag(body, "indsSclsNm"),
      ctprvnCd: xmlTag(body, "ctprvnCd"),
      ctprvnNm: xmlTag(body, "ctprvnNm"),
      signguCd: xmlTag(body, "signguCd"),
      signguNm: xmlTag(body, "signguNm"),
      adongCd: xmlTag(body, "adongCd"),
      adongNm: xmlTag(body, "adongNm"),
    });
  }
  return out;
}

function xmlResultCode(xml: string): string {
  return xmlTag(xml, "returnReasonCode") || xmlTag(xml, "resultCode");
}

function isSuccessCode(code: string): boolean {
  return code === "00" || code === "0" || code === "0000";
}

// Resolve the provider's current personal-service classification instead of
// downloading restaurants/offices first. Failure falls back to full pagination.
let personalIndustryCache: {code: string; expires: number} | null = null;
async function personalIndustryCode(serviceKey: string): Promise<string> {
  if (personalIndustryCache && personalIndustryCache.expires > Date.now()) {
    return personalIndustryCache.code;
  }
  try {
    const url = new URL("https://apis.data.go.kr/B553077/api/open/sdsc2/largeUpjongList");
    url.search = new URLSearchParams({serviceKey, type: "json"}).toString();
    const response = await fetch(url, {signal: AbortSignal.timeout(4000)});
    if (!response.ok) return "";
    const data = await response.json();
    const candidates = new Set<string>();
    function walk(value: unknown): void {
      if (!value || typeof value !== "object") return;
      if (Array.isArray(value)) { value.forEach(walk); return; }
      const row = value as Record<string, unknown>;
      const name = String(row.indsLclsNm ?? "").replace(/\s+/g, "");
      const code = String(row.indsLclsCd ?? "");
      if (/개인서비스|수리.*개인|생활서비스/.test(name) && /^[A-Z0-9]{2}$/.test(code)) candidates.add(code);
      Object.values(row).forEach(walk);
    }
    walk(data);
    if (candidates.size !== 1) return "";
    const code = [...candidates][0];
    personalIndustryCache = {code, expires: Date.now() + 86400000};
    return code;
  } catch { return ""; }
}

async function fetchStores(opts: {
  key: string;
  lat: number;
  lng: number;
  radiusM: number;
  category: string;
  beautyOnly?: boolean;
}): Promise<{
  ok: boolean;
  totalInRadius: number;
  sameCategoryCount: number;
  sampleNames: string[];
  items: StoreItemOut[];
  complete?: boolean;
  audit?: Record<string, unknown>;
  error?: string;
  upstream?: "ok" | "api_error" | "malformed" | "missing_key" | "network";
}> {
  const keywords = categoryKeywords(opts.category);
  // Both encoded and decoded data.go.kr keys are accepted; encode exactly once.
  let serviceKey = opts.key.trim();
  try { serviceKey = decodeURIComponent(serviceKey); } catch { /* raw key */ }
  const industryCode = opts.beautyOnly ? await personalIndustryCode(serviceKey) : "";
  const pageSize = 1000;
  const maxPages = 20;
  const started = Date.now();
  const rawItems: Record<string, unknown>[] = [];
  let responseTotalCount: number | null = null;
  let complete = false;
  let pageError: string | undefined;
  let pageCount = 0;
  try {
    for (let page = 1; page <= maxPages; page++) {
      if (Date.now() - started > 20000) {
        pageError = "pagination_timeout";
        break;
      }
      const url = new URL("https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInRadius");
      url.search = new URLSearchParams({
        serviceKey, pageNo: String(page), numOfRows: String(pageSize),
        ...(industryCode ? {indsLclsCd: industryCode} : {}),
        radius: String(opts.radiusM), cx: String(opts.lng), cy: String(opts.lat), type: "json",
      }).toString();
      let pageItems: Record<string, unknown>[];
      try {
        const res = await fetch(url, { signal: AbortSignal.timeout(6000) });
        if (!res.ok) throw new Error("http_" + res.status);
        const text = (await res.text()).trim();
        let code: string;
        if (text.startsWith("<")) {
          code = xmlResultCode(text);
          if (code && !isSuccessCode(code)) throw new Error("api_" + code);
          pageItems = extractXmlItemMaps(text);
          const total = xmlTag(text, "totalCount");
          if (total) responseTotalCount = num(total);
        } else {
          const payload = JSON.parse(text);
          code = headerResultCode(payload);
          if (code && !isSuccessCode(code)) throw new Error("api_" + code);
          pageItems = extractStoreItems(payload);
          responseTotalCount = readTotalCount(payload) ?? responseTotalCount;
        }
        if (!pageItems.length && !isSuccessCode(code)) throw new Error("malformed_empty");
      } catch (e) {
        // Never echo upstream URLs (which contain service keys).
        const message = e instanceof Error ? e.message : "network";
        pageError = /^(http_\d+|api_[A-Z0-9_]+|malformed_empty)$/.test(message)
          ? message : "upstream_unavailable";
        break;
      }
      pageCount++;
      if (pageItems.length === 0) {
        complete = responseTotalCount == null || rawItems.length >= responseTotalCount;
        if (!complete) pageError = "pagination_incomplete";
        break;
      }
      rawItems.push(...pageItems);
      if (responseTotalCount != null && rawItems.length >= responseTotalCount) {
        complete = true;
        break;
      }
      // Without totalCount, only an empty terminal page proves completion.
    }
    if (!complete && !pageError) pageError = "pagination_limit";
    if (pageCount === 0) return {
      ok: false, totalInRadius: 0, sameCategoryCount: 0, sampleNames: [], items: [],
      complete: false, error: pageError, upstream: "api_error",
    };
    const matched = rawItems.filter((it) => matchesCategory(it, keywords));
    const names = matched
      .map((it) => String(it.bizesNm ?? it.storeNm ?? it.name ?? ''))
      .filter((n) => n.length > 0)
      .slice(0, 5);

    const dropReasons: Record<string, number> = {};
    const bump = (k: string) => {
      dropReasons[k] = (dropReasons[k] ?? 0) + 1;
    };
    const seenIds = new Set<string>();
    const mapped: StoreItemOut[] = [];
    for (const it of rawItems) {
      const id = String(it.bizesId ?? it.bizesNo ?? "").trim();
      if (id && seenIds.has(id)) {
        bump("dedupe_bizesId");
        continue;
      }
      if (id) seenIds.add(id);
      if (!matchesCategory(it, keywords)) {
        bump("category_keyword");
        continue;
      }
      if (opts.beautyOnly && chipKeyForStore(it) === "other") {
        bump("not_beauty");
        continue;
      }
      const ll = storeLatLng(it);
      if (!ll) {
        bump("invalid_or_missing_coords");
        continue;
      }
      const name = String(it.bizesNm ?? it.storeNm ?? it.name ?? "").trim();
      if (!name) {
        bump("empty_name");
        continue;
      }
      const categoryLabel = String(
        it.indsSclsNm ?? it.indsMclsNm ?? it.indsLclsNm ?? it.sclsNm ?? "",
      ).trim();
      if (haversineM(opts.lat, opts.lng, ll.lat, ll.lng) > opts.radiusM) {
        bump("outside_radius");
        continue;
      }
      mapped.push({
        name,
        category_label: categoryLabel,
        chip_key: chipKeyForStore(it),
        lat: ll.lat,
        lng: ll.lng,
        distance_m: haversineM(opts.lat, opts.lng, ll.lat, ll.lng),
        address: rawText(it, "rdnmAdr"),
        addr: rawText(it, "addr"),
        bizes_id: rawText(it, "bizesId"),
        inds_lcls_cd: rawText(it, "indsLclsCd"),
        inds_lcls_nm: rawText(it, "indsLclsNm"),
        inds_mcls_cd: rawText(it, "indsMclsCd"),
        inds_mcls_nm: rawText(it, "indsMclsNm"),
        inds_scls_cd: rawText(it, "indsSclsCd"),
        inds_scls_nm: rawText(it, "indsSclsNm"),
        lot_address: rawText(it, "lnoAdr"),
        ctprvn_cd: rawText(it, "ctprvnCd"),
        ctprvn_nm: rawText(it, "ctprvnNm"),
        signgu_cd: rawText(it, "signguCd"),
        signgu_nm: rawText(it, "signguNm"),
        adong_cd: rawText(it, "adongCd"),
        adong_nm: rawText(it, "adongNm"),
      });
    }
    mapped.sort((a, b) => a.distance_m - b.distance_m);

    const coordBuckets = new Map<string, number>();
    for (const s of mapped) {
      const k = `${s.lat.toFixed(5)},${s.lng.toFixed(5)}`;
      coordBuckets.set(k, (coordBuckets.get(k) ?? 0) + 1);
    }
    let coincident = 0;
    for (const n of coordBuckets.values()) {
      if (n > 1) coincident += 1;
    }

    const audit = {
      source: "LIVE" as const,
      category: opts.category,
      lat: opts.lat,
      lng: opts.lng,
      radiusM: opts.radiusM,
      pagesRead: pageCount,
      industryCode: industryCode || null,
      responseTotalCount,
      rawItemCount: rawItems.length,
      normalizedCount: rawItems.length,
      afterFilterCount: mapped.length,
      categoryFilteredCount: mapped.length,
      afterCoordCount: mapped.length,
      afterDedupeCount: mapped.length,
      renderedPinCount: mapped.length,
      paginationContract: complete ? "complete" : "partial",
      dropReasons,
      coincidentCoordGroups: coincident,
    };

    return {
      ok: true,
      totalInRadius: rawItems.length,
      sameCategoryCount: opts.beautyOnly ? mapped.length : matched.length,
      sampleNames: opts.beautyOnly ? mapped.slice(0, 5).map((s) => s.name) : names,
      items: mapped,
      complete,
      error: pageError,
      upstream: "ok",
      audit,
    };
  } catch (e) {
    return {
      ok: false,
      totalInRadius: 0,
      sameCategoryCount: 0,
      sampleNames: [],
      items: [],
      error: String(e),
      upstream: "network",
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
  const looksLikePopRow = (row: object): boolean =>
    "totPpltn" in row ||
    "totNmprCnt" in row ||
    "malePpltnCnt" in row ||
    "남자인구수" in row ||
    "totPopulation" in row ||
    "총인구수" in row ||
    "male0To9AgePpltnCnt" in row ||
    "만0~9세남자" in row ||
    "female0To9AgePpltnCnt" in row ||
    "만0~9세여자" in row;
  const walk = (node: unknown, depth: number) => {
    if (depth > 6 || node == null) return;
    if (Array.isArray(node)) {
      if (
        node.length > 0 &&
        typeof node[0] === "object" &&
        node[0] !== null &&
        looksLikePopRow(node[0] as object)
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

function moisGatewayError(payload: unknown): { code: string; msg: string } {
  if (!payload || typeof payload !== "object") return { code: "", msg: "" };
  const root = payload as Record<string, unknown>;
  const nestedHeader = (root.response as Record<string, unknown> | undefined)
    ?.header as Record<string, unknown> | undefined;
  const topHeader = root.header as Record<string, unknown> | undefined;
  const cmmHeader = root.cmmMsgHeader as Record<string, unknown> | undefined;
  const gatewayHeader = (
    root.OpenAPI_ServiceResponse as Record<string, unknown> | undefined
  )?.cmmMsgHeader as Record<string, unknown> | undefined;
  const code = String(
    root.resultCode ??
      topHeader?.resultCode ??
      nestedHeader?.resultCode ??
      cmmHeader?.resultCode ??
      gatewayHeader?.returnReasonCode ??
      "",
  ).trim();
  const msg = String(
    root.resultMsg ??
      topHeader?.resultMsg ??
      nestedHeader?.resultMsg ??
      cmmHeader?.resultMsg ??
      gatewayHeader?.errMsg ??
      gatewayHeader?.returnAuthMsg ??
      "",
  ).trim();
  return { code, msg };
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

  // 15108072 selectAdmmSexdAgePpltn 실응답 키: male0AgeNmprCnt / feml0AgeNmprCnt …
  const ageDefs: { label: string; mKeys: string[]; fKeys: string[] }[] = [
    {
      label: "0-19",
      mKeys: [
        "male0AgeNmprCnt",
        "male10AgeNmprCnt",
        "male0To9AgePpltnCnt",
        "male10To19AgePpltnCnt",
        "만0~9세남자",
        "만10~19세남자",
      ],
      fKeys: [
        "feml0AgeNmprCnt",
        "feml10AgeNmprCnt",
        "female0To9AgePpltnCnt",
        "female10To19AgePpltnCnt",
        "만0~9세여자",
        "만10~19세여자",
      ],
    },
    {
      label: "20-29",
      mKeys: ["male20AgeNmprCnt", "male20To29AgePpltnCnt", "만20~29세남자"],
      fKeys: ["feml20AgeNmprCnt", "female20To29AgePpltnCnt", "만20~29세여자"],
    },
    {
      label: "30-39",
      mKeys: ["male30AgeNmprCnt", "male30To39AgePpltnCnt", "만30~39세남자"],
      fKeys: ["feml30AgeNmprCnt", "female30To39AgePpltnCnt", "만30~39세여자"],
    },
    {
      label: "40-49",
      mKeys: ["male40AgeNmprCnt", "male40To49AgePpltnCnt", "만40~49세남자"],
      fKeys: ["feml40AgeNmprCnt", "female40To49AgePpltnCnt", "만40~49세여자"],
    },
    {
      label: "50+",
      mKeys: [
        "male50AgeNmprCnt",
        "male60AgeNmprCnt",
        "male70AgeNmprCnt",
        "male80AgeNmprCnt",
        "male90AgeNmprCnt",
        "male100AgeNmprCnt",
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
        "feml50AgeNmprCnt",
        "feml60AgeNmprCnt",
        "feml70AgeNmprCnt",
        "feml80AgeNmprCnt",
        "feml90AgeNmprCnt",
        "feml100AgeNmprCnt",
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
      row.femlNmprCnt ?? row.femaleNmprCnt ?? row.femalePpltnCnt ?? row.여자인구수,
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

  // data.go.kr 15108072 — 행정동별(통반단위) 성/연령별 주민등록 인구수
  // https://apis.data.go.kr/1741000/admmSexdAgePpltn/selectAdmmSexdAgePpltn
  // 필수: serviceKey, admmCd, srchFrYm, srchToYm / numOfRows 최대 100
  const base =
    Deno.env.get("MOIS_POP_API_URL")?.trim() ||
    "https://apis.data.go.kr/1741000/admmSexdAgePpltn/selectAdmmSexdAgePpltn";

  // data.go.kr keys may arrive URL-encoded; encode exactly once (same as SBIZ/FTC).
  let serviceKey = opts.key.trim();
  try {
    serviceKey = decodeURIComponent(serviceKey);
  } catch {
    /* raw key */
  }

  const describePayload = (payload: unknown): string => {
    if (!payload || typeof payload !== "object") return "shape=non_object";
    const root = payload as Record<string, unknown>;
    const topKeys = Object.keys(root).slice(0, 12).join(",");
    const gw = moisGatewayError(payload);
    const bits = [`top=${topKeys || "-"}`];
    if (gw.code) bits.push(`code=${gw.code}`);
    if (gw.msg) bits.push(`msg=${gw.msg}`);
    // first array-of-objects field names for schema mismatch diagnosis
    const walk = (node: unknown, depth: number): string | null => {
      if (depth > 5 || node == null) return null;
      if (Array.isArray(node)) {
        if (node.length > 0 && typeof node[0] === "object" && node[0]) {
          return Object.keys(node[0] as object).slice(0, 16).join(",");
        }
        return `empty_array`;
      }
      if (typeof node === "object") {
        for (const v of Object.values(node as Record<string, unknown>)) {
          const hit = walk(v, depth + 1);
          if (hit) return hit;
        }
      }
      return null;
    };
    const fields = walk(root, 0);
    if (fields) bits.push(`itemFields=${fields}`);
    return bits.join(" ");
  };

  // lv=7 단일 읍면동, lv=4 통반단위(기본). 둘 다 시도.
  const lvCandidates = ["4", "7"];
  let lastErr = "no_endpoint";

  for (const lv of lvCandidates) {
    const allRows: Record<string, unknown>[] = [];
    let pageNo = 1;
    const pageSize = 100;
    let lastStatus = 0;
    let lastPayload: unknown = null;

    while (pageNo <= 20) {
      const params = new URLSearchParams({
        serviceKey,
        admmCd: adm,
        srchFrYm: opts.statsYm,
        srchToYm: opts.statsYm,
        lv,
        regSeCd: "1",
        type: "json",
        numOfRows: String(pageSize),
        pageNo: String(pageNo),
      });
      const url = `${base}?${params.toString()}`;
      try {
        const res = await fetch(url);
        lastStatus = res.status;
        const text = await res.text();
        let payload: unknown;
        try {
          payload = JSON.parse(text);
        } catch {
          lastErr = `pop_non_json status=${res.status} lv=${lv}`;
          break;
        }
        lastPayload = payload;
        const gw = moisGatewayError(payload);
        // 실패 코드면 다음 lv로
        if (gw.code && !["00", "0", "INFO-0", "NORMAL", "NORMAL SERVICE"].includes(gw.code.toUpperCase()) &&
            !/^00/.test(gw.code) && gw.code !== "03") {
          // 03 sometimes means NODATA — treat as empty for this lv
          if (gw.code === "03" || /NO_DATA|NODATA|데이터가 없습니다/i.test(gw.msg)) {
            lastErr = `pop_empty status=${res.status} lv=${lv} code=${gw.code} msg=${gw.msg}`;
            break;
          }
          // hard errors (10,12,20...) — keep trying next lv only for empty-ish; else record
          if (["10", "11", "12", "20", "22", "30", "31", "32"].includes(gw.code)) {
            lastErr = `pop_gw status=${res.status} lv=${lv} code=${gw.code} msg=${gw.msg}`;
            break;
          }
        }

        const rows = extractPopRows(payload);
        if (rows.length === 0) {
          lastErr = `pop_empty status=${res.status} lv=${lv} ${describePayload(payload)}`;
          break;
        }
        allRows.push(...rows);
        const root = payload as Record<string, unknown>;
        const body = (root.response as Record<string, unknown> | undefined)?.body ??
          root.body ??
          root;
        const totalCount = Number(
          (body as Record<string, unknown>)?.totalCount ?? root.totalCount ?? 0,
        );
        if (!totalCount || allRows.length >= totalCount || rows.length < pageSize) {
          break;
        }
        pageNo += 1;
      } catch (e) {
        lastErr = `lv=${lv} ${String(e)}`;
        break;
      }
    }

    if (allRows.length > 0) {
      const agg = aggregatePopulation(allRows);
      return {
        ok: true,
        total: agg.total,
        male: agg.male,
        female: agg.female,
        ages: agg.ages,
        dongName: agg.dongName,
        statsYm: opts.statsYm,
      };
    }
    if (lastPayload && lastErr.startsWith("pop_empty")) {
      // keep richest empty diagnostic; try next lv
      continue;
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
    const searchText = await searchRes.text();
    let searchJson: Record<string, unknown> = {};
    try { searchJson = JSON.parse(searchText); } catch {
      return {
        ok: false,
        error: "kakao_non_json",
        debug: { http_status: searchRes.status, body_prefix: searchText.slice(0, 120) },
      };
    }
    if (!searchRes.ok) {
      return {
        ok: false,
        error: "kakao_http_" + searchRes.status,
        debug: {
          http_status: searchRes.status,
          msg: String((searchJson as {message?: unknown}).message ?? (searchJson as {error?: unknown}).error ?? "").slice(0, 200),
          error_type: String((searchJson as {errorType?: unknown}).errorType ?? "").slice(0, 80),
        },
      };
    }
    const docs = (searchJson as {documents?: unknown[]}).documents ?? [];
    const doc = docs[0] as Record<string, unknown> | undefined;
    if (!doc) return {
      ok: false,
      error: "address_not_found",
      debug: { http_status: searchRes.status, document_count: docs.length },
    };

    const lat = Number(doc.y);
    const lng = Number(doc.x);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return { ok: false, error: "bad_coords" };
    }

    const addrMap = (doc.address && typeof doc.address === "object")
      ? doc.address as Record<string, unknown>
      : null;
    let admCd = String(addrMap?.h_code ?? "").trim();
    let dongName = String(addrMap?.region_3depth_name ?? "").trim();

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


type FranchiseSale = { area_name: string; industry_name: string; year: string; area_unit_average_sales: number; currency_unit: string; franchise_count: number };
const regionAliases: Record<string,string> = {
  서울특별시:"서울", 부산광역시:"부산", 대구광역시:"대구", 인천광역시:"인천",
  광주광역시:"광주", 대전광역시:"대전", 울산광역시:"울산",
  세종특별자치시:"세종", 경기도:"경기", 강원특별자치도:"강원",
  충청북도:"충북", 충청남도:"충남", 전북특별자치도:"전북",
  전라북도:"전북", 전라남도:"전남", 경상북도:"경북",
  경상남도:"경남", 제주특별자치도:"제주",
};
function regionOf(text: string): string {
  const first = text.trim().split(/\s+/)[0] ?? "";
  return regionAliases[first] ?? (/^(서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주)$/.test(first) ? first : "");
}
// data.go.kr 서비스들은 성공 시 스키마가 제각각이다(최상위 평면형 /
// {header,body} 평면형 / {response:{header,body}} 중첩형). 이 파일의
// stores API(headerResultCode·readTotalCount)도 이미 top-level과
// response.* 두 형태를 모두 받아들이도록 되어 있다 — 같은 패턴을
// franchise_sales에도 동일하게 적용한다. 이 함수는 "무엇을 성공으로
// 볼지"를 넓히는 것이 아니라 "성공 코드가 어디에 있는지"만 넓게 찾는다.
function franchiseResultInfo(
  payload: unknown,
): { code: string; msg: string; headerAt: string } {
  if (!payload || typeof payload !== "object") {
    return { code: "", msg: "", headerAt: "none" };
  }
  const root = payload as Record<string, unknown>;
  const nestedHeader = (root.response as Record<string, unknown> | undefined)
    ?.header as Record<string, unknown> | undefined;
  const topHeader = root.header as Record<string, unknown> | undefined;
  const cmmHeader = root.cmmMsgHeader as Record<string, unknown> | undefined;
  // data.go.kr의 구형 게이트웨이 오류 포맷: 인증/키/요청 파라미터 문제일 때
  // HTTP 403과 함께 { OpenAPI_ServiceResponse: { cmmMsgHeader: {...} } }를
  // 반환한다 (returnReasonCode/errMsg/returnAuthMsg). resultCode라는 키
  // 자체가 없으므로 별도로 찾아야 한다.
  const gatewayHeader = (
    root.OpenAPI_ServiceResponse as Record<string, unknown> | undefined
  )?.cmmMsgHeader as Record<string, unknown> | undefined;
  let headerAt = "none";
  if (root.resultCode !== undefined) headerAt = "top";
  else if (topHeader?.resultCode !== undefined) headerAt = "header";
  else if (nestedHeader?.resultCode !== undefined) headerAt = "response.header";
  else if (cmmHeader?.resultCode !== undefined) headerAt = "cmmMsgHeader";
  else if (gatewayHeader?.returnReasonCode !== undefined) {
    headerAt = "OpenAPI_ServiceResponse.cmmMsgHeader";
  }
  const code = String(
    root.resultCode ??
      topHeader?.resultCode ??
      nestedHeader?.resultCode ??
      cmmHeader?.resultCode ??
      gatewayHeader?.returnReasonCode ??
      "",
  ).trim();
  const msg = String(
    root.resultMsg ??
      topHeader?.resultMsg ??
      nestedHeader?.resultMsg ??
      cmmHeader?.resultMsg ??
      gatewayHeader?.errMsg ??
      gatewayHeader?.returnAuthMsg ??
      "",
  ).trim();
  return { code, msg, headerAt };
}
// 성공 판정에는 쓰지 않는다 — 이미 실패로 확정된 결과를 data.go.kr
// 공통 오류코드/메시지로 분류하는 라벨링 전용 함수.
function classifyFranchiseError(code: string, msg: string): string {
  const m = msg.toUpperCase();
  if (
    ["20", "22", "30", "31", "32"].includes(code) ||
    /ACCESS_DENIED|SERVICE_KEY_IS_NOT_REGISTERED|UNREGISTERED|DEADLINE_HAS_EXPIRED|LIMITED_NUMBER_OF_SERVICE_REQUESTS_EXCEEDS/
      .test(m)
  ) {
    return "auth_or_permission";
  }
  if (
    ["10", "11", "12", "99"].includes(code) ||
    /INVALID_REQUEST_PARAMETER|NO_MANDATORY_REQUEST_PARAMETERS|NO_OPENAPI_SERVICE/
      .test(m)
  ) {
    return "invalid_request";
  }
  return "unexpected_shape";
}
// 안전한 진단 정보만 — 서비스키·매출 원본 금액은 절대 담지 않는다.
type FranchiseDiag = {
  year: string;
  http_status: number;
  top_level_keys: string[];
  result_code: string;
  result_code_at: string;
  result_msg: string;
  items_found_at: string;
  raw_item_count: number;
};
async function franchiseSales(address: string) {
  const source = "공정거래위원회 가맹정보 지역별 서비스업 평균매출";
  const region = regionOf(address);
  // data.go.kr issues both encoded and decoded keys; encode exactly once via URLSearchParams.
  let key = Deno.env.get("FTC_FRANCHISE_SALES_SERVICE_KEY")?.trim() ?? "";
  try { key = decodeURIComponent(key); } catch { /* already decoded */ }
  if (!region) return { ok:false, error:"region_required", source, rows:[] as FranchiseSale[] };
  if (!key) return { ok:false, error:"missing_FTC_FRANCHISE_SALES_SERVICE_KEY", source, rows:[] as FranchiseSale[] };
  let error = "no_matching_data";
  let lastDiag: FranchiseDiag | null = null;
  for (let year = new Date().getUTCFullYear() - 1; year >= new Date().getUTCFullYear() - 5; year--) {
    const url = new URL("https://apis.data.go.kr/1130000/FftcAreaIndutyAvrStatsService/getAreaIndutyAvrSrvcStats");
    for (const [k,v] of Object.entries({ serviceKey:key, pageNo:"1", numOfRows:"1000", resultType:"json", yr:String(year) })) url.searchParams.set(k,v);
    try {
      const res = await fetch(url, { signal:AbortSignal.timeout(8000) });
      const text = await res.text();
      // deno-lint-ignore no-explicit-any
      let payload: any;
      try { payload = JSON.parse(text); } catch {
        error = "unexpected_shape";
        lastDiag = {
          year: String(year), http_status: res.status, top_level_keys: [],
          result_code: "", result_code_at: "none", result_msg: "",
          items_found_at: "none", raw_item_count: 0,
        };
        continue;
      }
      const root: Record<string, unknown> =
        payload && typeof payload === "object" ? payload : {};
      const { code, msg, headerAt } = franchiseResultInfo(payload);
      const isSuccess = res.ok && ["00", "0", "NORMAL_SERVICE"].includes(code);

      const topBody = root.body as Record<string, unknown> | undefined;
      const nestedBody = (root.response as Record<string, unknown> | undefined)?.body as
        | Record<string, unknown>
        | undefined;
      let itemsFoundAt = "none";
      // deno-lint-ignore no-explicit-any
      let raw: any = [];
      if ((topBody?.items as Record<string, unknown> | undefined)?.item !== undefined) {
        raw = (topBody!.items as Record<string, unknown>).item; itemsFoundAt = "body.items.item";
      } else if (topBody?.items !== undefined) {
        raw = topBody!.items; itemsFoundAt = "body.items";
      } else if ((nestedBody?.items as Record<string, unknown> | undefined)?.item !== undefined) {
        raw = (nestedBody!.items as Record<string, unknown>).item; itemsFoundAt = "response.body.items.item";
      } else if (nestedBody?.items !== undefined) {
        raw = nestedBody!.items; itemsFoundAt = "response.body.items";
      } else if ((root.items as Record<string, unknown> | undefined)?.item !== undefined) {
        raw = (root.items as Record<string, unknown>).item; itemsFoundAt = "items.item";
      } else if (root.items !== undefined) {
        raw = root.items; itemsFoundAt = "items";
      }
      const rawArr = Array.isArray(raw) ? raw : (raw ? [raw] : []);

      lastDiag = {
        year: String(year), http_status: res.status,
        top_level_keys: Object.keys(root).slice(0, 20),
        result_code: code, result_code_at: headerAt, result_msg: msg.slice(0, 200),
        items_found_at: itemsFoundAt, raw_item_count: rawArr.length,
      };

      if (!isSuccess) {
        // 코드를 찾았다면(HTTP 상태와 무관하게) 원인을 분류한다. data.go.kr
        // 게이트웨이는 인증/파라미터 오류를 HTTP 403 + 오류 바디로 함께
        // 내려주므로, res.ok만으로 "그냥 서버 문제"로 뭉뜥그려지 않는다.
        error = code
          ? classifyFranchiseError(code, msg)
          : (res.ok ? "unexpected_shape" : "upstream_unavailable");
        continue;
      }
      const rows: FranchiseSale[] = [];
      for (const item of rawArr) {
        if (!item || typeof item !== "object") continue;
        const industry = String(item.indutyMlsfcNm ?? "").trim();
        const amount = Number(String(item.arUnitAvrgSlsAmt ?? "").replace(/,/g,""));
        if (regionOf(String(item.areaNm ?? "")) !== region ||
            !/미용|헤어|피부|네일|이용/.test(industry) ||
            !Number.isFinite(amount) || amount <= 0) continue;
        rows.push({ area_name:String(item.areaNm), industry_name:industry, year:String(item.yr ?? year),
          area_unit_average_sales:amount, currency_unit:String(item.crrncyUnitCdNm ?? "").trim(),
          franchise_count:num(item.frcsCnt) });
      }
      if (rows.length) return { ok:true, source, region, year:String(year), scope:"province_franchise_service_area_unit", rows };
      error = "no_matching_beauty_rows";
    } catch { error = "upstream_unavailable"; }
  }
  return { ok:false, source, region, error, rows:[] as FranchiseSale[], debug: lastDiag };
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

    if (body.action === "franchise_sales") return jsonResponse(await franchiseSales(body.address ?? ""));
    const lat = body.latitude;
    const lng = body.longitude;
    if (typeof lat !== "number" || typeof lng !== "number" ||
        !Number.isFinite(lat) || !Number.isFinite(lng) ||
        lat < 33 || lat > 39 || lng < 124 || lng > 132) {
      return jsonResponse({ ok: false, error: "valid_korea_coordinates_required" }, 400);
    }
    if (body.radius_m != null &&
        (typeof body.radius_m !== "number" || !Number.isFinite(body.radius_m) ||
         body.radius_m < 100 || body.radius_m > 2000)) {
      return jsonResponse({ ok: false, error: "radius_m_must_be_100_to_2000" }, 400);
    }
    const storesOnly = body.action === "stores";
    const radiusM = Math.min(Math.max(body.radius_m ?? 500, 100), 2000);
    const category = body.category ?? (storesOnly ? "전체" : "에스테틱");
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
        beautyOnly: storesOnly,
      })
      : {
        ok: false,
        totalInRadius: 0,
        sameCategoryCount: 0,
        sampleNames: [] as string[],
        items: [] as StoreItemOut[],
        error: "missing_SBIZ_STORE_SERVICE_KEY",
        upstream: "missing_key" as const,
      };

    const population = !storesOnly && moisKey
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
        ...(!storesOnly ? ["행정안전부 행정동별 성/연령별 주민등록 인구수"] : []),
      ],
      fetched_at: new Date().toISOString(),
      stats_ym: statsYm,
      stores: {
        ok: stores.ok,
        upstream: stores.upstream ?? (stores.ok ? "ok" : "error"),
        complete: (stores as { complete?: boolean }).complete ?? false,
        empty: Boolean(stores.ok) && (stores.items?.length ?? 0) === 0,
        total_in_radius: stores.totalInRadius,
        same_category_count: stores.sameCategoryCount,
        sample_names: stores.sampleNames,
        items: stores.items ?? [],
        error: stores.error ?? null,
        source: "소상공인시장진흥공단 상가(상권)정보",
        retrieved_at: new Date().toISOString(),
        audit: (stores as { audit?: unknown }).audit ?? null,
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
        stores: {
          ok: false,
          upstream: "network",
          empty: false,
          total_in_radius: 0,
          same_category_count: 0,
        },
        population: { ok: false, total: 0, male: 0, female: 0, ages: [] },
      },
      200,
    );
  }
});
