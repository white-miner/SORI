// Supabase Edge Function — KMA short-term forecast proxy (PRD v4.0).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface WeatherBody {
  shop_id?: string;
  latitude?: number;
  longitude?: number;
}

function degToRad(deg: number): number {
  return (deg * Math.PI) / 180;
}

function latLngToGrid(lat: number, lng: number): { nx: number; ny: number } {
  const RE = 6371.00877;
  const GRID = 5.0;
  const SLAT1 = 30.0;
  const SLAT2 = 60.0;
  const OLON = 126.0;
  const OLAT = 38.0;
  const XO = 43;
  const YO = 136;

  const DEGRAD = Math.PI / 180.0;
  const re = RE / GRID;
  const slat1 = SLAT1 * DEGRAD;
  const slat2 = SLAT2 * DEGRAD;
  const olon = OLON * DEGRAD;
  const olat = OLAT * DEGRAD;

  let sn =
    Math.log(Math.cos(slat1) / Math.cos(slat2)) /
    Math.log(Math.tan(Math.PI * 0.25 + slat2 * 0.5) /
      Math.tan(Math.PI * 0.25 + slat1 * 0.5));
  sn = Math.log(Math.tan(Math.PI * 0.25 + slat1 * 0.5)) / sn;
  let sf = (Math.tan(Math.PI * 0.25 + slat1 * 0.5) ** sn * Math.cos(slat1)) / sn;
  let ro = re * sf / (Math.tan(Math.PI * 0.25 + olat * 0.5) ** sn);

  let ra = re * sf / (Math.tan(Math.PI * 0.25 + lat * DEGRAD * 0.5) ** sn);
  let theta = lng * DEGRAD - olon;
  if (theta > Math.PI) theta -= 2.0 * Math.PI;
  if (theta < -Math.PI) theta += 2.0 * Math.PI;
  theta *= sn;

  const x = Math.floor(ra * Math.sin(theta) + XO + 0.5);
  const y = Math.floor(ro - ra * Math.cos(theta) + YO + 0.5);
  return { nx: x, ny: y };
}

function computeCalm(tempC: number, humidity: number, uv: number) {
  let calm = 22.0;
  if (humidity < 45) calm += 0.5;
  if (uv >= 6) calm += 0.3;
  if (tempC > 28) calm -= (tempC - 28) * 0.1;
  calm = Math.min(24, Math.max(20, calm));
  const calmStr = calm.toFixed(1);
  let headline = `초기 진정 온도 ${calmStr}°C`;
  let narrative: string;
  if (humidity < 45 && uv >= 6) {
    narrative =
      "외기가 건조하고 자외선이 강합니다. 시술 전 냉각 패드 3분으로 표피 열감을 먼저 낮추세요.";
  } else if (humidity < 45) {
    narrative = `습도 ${humidity}%로 피부 수분 증발이 빠릅니다. 시술 전 냉각 패드 3분을 권장합니다.`;
  } else if (uv >= 6) {
    narrative = `자외선 지수 ${uv}로 혈관 확장 리스크가 있습니다. SPF 재도포 후 상담을 시작하세요.`;
  } else if (tempC > 28) {
    narrative = `외기 ${Math.round(tempC)}°C로 열감이 빨리 올라갑니다. 냉각·보습으로 장벽을 먼저 안정시키세요.`;
  } else {
    narrative =
      "오늘 환경은 표준 프로토콜에 적합합니다. 상담 전 고객 체감 온도만 확인하세요.";
  }
  return { calm, headline, narrative };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as WeatherBody;
    const lat = body.latitude ?? 37.5665;
    const lng = body.longitude ?? 126.9780;
    const key = Deno.env.get("KMA_SERVICE_KEY") ??
      Deno.env.get("DATA_GO_KR_SERVICE_KEY") ?? "";

    if (!key) {
      const fallback = computeCalm(24, 55, 4);
      return new Response(
        JSON.stringify({
          temp_c: 24,
          humidity_pct: 55,
          uv_index: 4,
          calm_target_c: fallback.calm,
          headline: fallback.headline,
          narrative: fallback.narrative,
          fetched_at: new Date().toISOString(),
          source: "fallback",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const grid = latLngToGrid(lat, lng);
    const now = new Date();
    const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
    const hour = kst.getUTCHours();
    let baseDate = kst.toISOString().slice(0, 10).replace(/-/g, "");
    let baseTime = "0500";
    if (hour < 2) baseTime = "2300";
    else if (hour < 5) baseTime = "0200";
    else if (hour < 8) baseTime = "0500";
    else if (hour < 11) baseTime = "0800";
    else if (hour < 14) baseTime = "1100";
    else if (hour < 17) baseTime = "1400";
    else if (hour < 20) baseTime = "1700";
    else if (hour < 23) baseTime = "2000";
    else baseTime = "2300";

    const url =
      `https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst` +
      `?serviceKey=${encodeURIComponent(key)}` +
      `&pageNo=1&numOfRows=200&dataType=JSON` +
      `&base_date=${baseDate}&base_time=${baseTime}` +
      `&nx=${grid.nx}&ny=${grid.ny}`;

    const res = await fetch(url);
    const json = await res.json();
    const items = json?.response?.body?.items?.item ?? [];
    let tmp: number | null = null;
    let reh: number | null = null;
    for (const item of items) {
      if (item.category === "TMP" && tmp === null) {
        tmp = Number(item.fcstValue);
      }
      if (item.category === "REH" && reh === null) {
        reh = Number(item.fcstValue);
      }
    }

    const tempC = tmp ?? 22;
    const humidity = reh ?? 55;
    const uv = hour >= 7 && hour <= 18
      ? Math.min(10, Math.max(1, Math.round((tempC - 10) / 3)))
      : 1;
    const calm = computeCalm(tempC, humidity, uv);

    return new Response(
      JSON.stringify({
        temp_c: tempC,
        humidity_pct: humidity,
        uv_index: uv,
        calm_target_c: calm.calm,
        headline: calm.headline,
        narrative: calm.narrative,
        fetched_at: new Date().toISOString(),
        source: "kma",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    const calm = computeCalm(24, 55, 4);
    return new Response(
      JSON.stringify({
        temp_c: 24,
        humidity_pct: 55,
        uv_index: 4,
        calm_target_c: calm.calm,
        headline: calm.headline,
        narrative: calm.narrative,
        fetched_at: new Date().toISOString(),
        source: "error_fallback",
        error: String(e),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
