// PRD v4.2 — KMA + AirKorea PM2.5 → SSI inputs.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ClimateBody {
  shop_id?: string;
  latitude?: number;
  longitude?: number;
  location_label?: string;
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
  const sf = (Math.tan(Math.PI * 0.25 + slat1 * 0.5) ** sn * Math.cos(slat1)) / sn;
  const ro = re * sf / (Math.tan(Math.PI * 0.25 + olat * 0.5) ** sn);
  const ra = re * sf / (Math.tan(Math.PI * 0.25 + lat * DEGRAD * 0.5) ** sn);
  let theta = lng * DEGRAD - olon;
  if (theta > Math.PI) theta -= 2.0 * Math.PI;
  if (theta < -Math.PI) theta += 2.0 * Math.PI;
  theta *= sn;
  return {
    nx: Math.floor(ra * Math.sin(theta) + XO + 0.5),
    ny: Math.floor(ro - ra * Math.cos(theta) + YO + 0.5),
  };
}

function estimateUv(tempC: number, hour: number): number {
  if (hour < 7 || hour > 18) return 1;
  return Math.min(10, Math.max(1, Math.round((tempC - 10) / 3)));
}

async function fetchPm25(key: string, station: string): Promise<number> {
  try {
    const url =
      `https://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRdmtrcMesureDnsty` +
      `?serviceKey=${encodeURIComponent(key)}` +
      `&returnType=json&numOfRows=1&pageNo=1` +
      `&stationName=${encodeURIComponent(station)}` +
      `&dataTerm=DAILY&ver=1.0`;
    const res = await fetch(url);
    const json = await res.json();
    const items = json?.response?.body?.items;
    if (Array.isArray(items) && items.length > 0) {
      const raw = String(items[0]?.pm25Value ?? "");
      const v = parseInt(raw.replace(/[^0-9]/g, ""), 10);
      if (!isNaN(v) && v >= 0) return v;
    }
  } catch (_) {}
  return 25;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json()) as ClimateBody;
    const lat = body.latitude ?? 35.8562;
    const lng = body.longitude ?? 129.2247;
    const locationLabel = body.location_label ?? "경주";
    const key = Deno.env.get("KMA_SERVICE_KEY") ??
      Deno.env.get("DATA_GO_KR_SERVICE_KEY") ?? "";

    if (!key) {
      return new Response(
        JSON.stringify({
          temp_c: 28,
          humidity_pct: 42,
          uv_index: 7,
          pm25_ug_m3: 38,
          hot_days_last_7: 2,
          location_label: locationLabel,
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
    const baseDate = kst.toISOString().slice(0, 10).replace(/-/g, "");
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

    const weatherUrl =
      `https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst` +
      `?serviceKey=${encodeURIComponent(key)}` +
      `&pageNo=1&numOfRows=200&dataType=JSON` +
      `&base_date=${baseDate}&base_time=${baseTime}` +
      `&nx=${grid.nx}&ny=${grid.ny}`;

    const weatherRes = await fetch(weatherUrl);
    const weatherJson = await weatherRes.json();
    const items = weatherJson?.response?.body?.items?.item ?? [];

    let tmp: number | null = null;
    let reh: number | null = null;
    for (const item of items) {
      if (item.category === "TMP" && tmp === null) tmp = Number(item.fcstValue);
      if (item.category === "REH" && reh === null) reh = Number(item.fcstValue);
    }

    const tempC = tmp ?? 22;
    const humidity = reh ?? 55;
    const uv = estimateUv(tempC, hour);
    const station = locationLabel.includes("경주") ? "경주" : "경주";
    const pm25 = await fetchPm25(key, station);

    return new Response(
      JSON.stringify({
        temp_c: tempC,
        humidity_pct: humidity,
        uv_index: uv,
        pm25_ug_m3: pm25,
        hot_days_last_7: tempC >= 30 ? 2 : 0,
        location_label: locationLabel,
        fetched_at: new Date().toISOString(),
        source: "kma",
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({
        temp_c: 24,
        humidity_pct: 55,
        uv_index: 4,
        pm25_ug_m3: 25,
        hot_days_last_7: 0,
        location_label: "경주",
        fetched_at: new Date().toISOString(),
        source: "error_fallback",
        error: String(e),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
