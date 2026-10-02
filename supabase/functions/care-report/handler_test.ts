import { assert, assertEquals } from "jsr:@std/assert@1";
import { type CareReportDeps, classifyInput, createCareReportHandler, type RpcResult } from "./handler.ts";

const HOST = "tieojdbzmqcmlwyqltrk.supabase.co";
const PAGES = "https://white-miner.github.io";
const SHOP = "f4145a4f-1111-4222-8333-444455556666";
const OTHER = "00000000-0000-4000-8000-0000000000f1";
const TOKEN = "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCd"; // 42 chars, base64url
const pub = (path: string) => `https://${HOST}/storage/v1/object/public/chart_photos/${path}`;

function payload(chart: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    kind: "care_report",
    expires_at: "2026-11-02T00:00:00Z",
    customer_display_name: "김*희",
    photos_withheld: false,
    shop: { id: SHOP, name: "샵", phone: "02-000-0000", address: "서울", profile_image_url: null },
    chart: {
      id: "e4000000-0000-4000-8000-000000000001",
      shop_id: SHOP,
      care_name: "진정관리",
      care_report_json: null,
      before_image_url: pub(`${SHOP}/cust/a_before.webp`),
      after_image_url: `${SHOP}/cust/a_after.webp`, // object path form (after S7)
      ...chart,
    },
  };
}

function setup(rpc: RpcResult | (() => Promise<RpcResult>), opts: Partial<CareReportDeps> = {}) {
  const calls = {
    rpc: [] as string[],
    sign: [] as { bucket: string; paths: string[]; ttl: number }[],
    logs: [] as string[],
  };
  const deps: CareReportDeps = {
    getCareReport(token) {
      calls.rpc.push(token);
      return typeof rpc === "function" ? rpc() : Promise.resolve(rpc);
    },
    signUrls(bucket, paths, ttl) {
      calls.sign.push({ bucket, paths, ttl });
      return Promise.resolve(paths.map((p) => `https://${HOST}/storage/v1/object/sign/${bucket}/${p}?token=signed`));
    },
    projectHost: HOST,
    allowedOrigins: [PAGES],
    now: () => Date.parse("2026-10-03T00:00:00Z"),
    log: (m) => calls.logs.push(m),
    ...opts,
  };
  return { handler: createCareReportHandler(deps), calls };
}

const post = (body: unknown, origin: string | null = PAGES) =>
  new Request("https://fn.example/care-report", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...(origin ? { Origin: origin } : {}) },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });

const KEY_DENY = /(signature|consent_pdf|allergy|side_effect|psycholog|birth|dob|guardian|ai_insight|paid)/i;
function forbiddenKeys(value: unknown, path = ""): string[] {
  if (Array.isArray(value)) return value.flatMap((v, i) => forbiddenKeys(v, `${path}[${i}]`));
  if (!value || typeof value !== "object") return [];
  return Object.entries(value as Record<string, unknown>).flatMap(([k, v]) => {
    const here = `${path}.${k}`;
    const bad = KEY_DENY.test(k) || ((k === "phone" || k === "address" || k === "customer_id") && path !== ".shop");
    return [...(bad ? [here] : []), ...forbiddenKeys(v, here)];
  });
}

Deno.test("classifyInput", () => {
  assertEquals(classifyInput({ token: TOKEN }), { kind: "token", token: TOKEN });
  assertEquals(classifyInput({ token: `  ${TOKEN} ` }), { kind: "token", token: TOKEN });
  assertEquals(classifyInput({ token: "e4000000-0000-4000-8000-000000000001" }), { kind: "legacy" });
  assertEquals(classifyInput({ chartId: "e4000000-0000-4000-8000-000000000001" }), { kind: "legacy" });
  assertEquals(classifyInput({ chart_id: "anything" }), { kind: "legacy" });
  assertEquals(classifyInput({ token: "bad" }), { kind: "invalid" });
  assertEquals(classifyInput({ token: "x".repeat(129) }), { kind: "invalid" });
  assertEquals(classifyInput({ token: "a".repeat(30) + "/" }), { kind: "invalid" });
  assertEquals(classifyInput({ token: 123 }), { kind: "invalid" });
  assertEquals(classifyInput({}), { kind: "invalid" });
});

Deno.test("OPTIONS preflight returns Pages CORS; foreign origin is refused", async () => {
  const { handler } = setup({ ok: true, data: payload() });
  const res = await handler(new Request("https://fn/care-report", { method: "OPTIONS", headers: { Origin: PAGES } }));
  assertEquals(res.status, 204);
  assertEquals(res.headers.get("access-control-allow-origin"), PAGES);
  const evil = await handler(post({ token: TOKEN }, "https://evil.example"));
  assertEquals(evil.status, 403);
  await evil.body?.cancel();
});

Deno.test("bad input → 400, GET → 405, nothing reaches the RPC", async () => {
  const { handler, calls } = setup({ ok: true, data: payload() });
  for (const body of [{ token: "bad" }, {}, "not json", "[1]"]) {
    const res = await handler(post(body));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "invalid_request");
  }
  const get = await handler(new Request(`https://fn/care-report?token=${TOKEN}`));
  assertEquals(get.status, 405);
  await get.body?.cancel();
  assertEquals(calls.rpc.length, 0);
});

Deno.test("legacy chartId links → 410 legacy_link with request_new_link (Q3), no RPC call", async () => {
  const { handler, calls } = setup({ ok: true, data: payload() });
  for (
    const body of [{ token: "e4000000-0000-4000-8000-000000000001" }, {
      chartId: "e4000000-0000-4000-8000-000000000001",
    }]
  ) {
    const res = await handler(post(body));
    assertEquals(res.status, 410);
    const json = await res.json();
    assertEquals(json.error, "legacy_link");
    assertEquals(json.action, "request_new_link");
    assert(String(json.message).includes("새 링크"));
  }
  assertEquals(calls.rpc.length, 0);
});

Deno.test("RPC PT404 → 404 not_found, PT410 → 410 link_expired, other → 502 without details", async () => {
  const cases: [RpcResult, number, string][] = [
    [{ ok: false, status: 404, code: "PT404" }, 404, "not_found"],
    [{ ok: false, status: 410, code: "PT410" }, 410, "link_expired"],
    [{ ok: false, status: 400, code: "22023" }, 400, "invalid_request"],
    [{ ok: false, status: 500, code: "XX000" }, 502, "upstream_error"],
  ];
  for (const [rpc, status, error] of cases) {
    const { handler, calls } = setup(rpc);
    const res = await handler(post({ token: TOKEN }));
    assertEquals(res.status, status);
    const json = await res.json();
    assertEquals(json.ok, false);
    assertEquals(json.error, error);
    assertEquals(calls.sign.length, 0);
    assert(!JSON.stringify(json).includes("XX000"));
    assert(!calls.logs.join(" ").includes(TOKEN), "token must never be logged");
  }
  const { handler } = setup(() => Promise.reject(new Error("boom")));
  const res = await handler(post({ token: TOKEN }));
  assertEquals(res.status, 500);
  assertEquals((await res.json()).error, "server_error");
});

Deno.test("200: photos become 10-minute signed URLs, forbidden keys never leave, no-store", async () => {
  const sneaky = payload({
    care_report_json: { summary: "ok", allergy_notes: "땅콩", nested: [{ signature_url: "data:x", tip: "보습" }] },
    customer_phone: "010-1234-5678",
    phone: "010-1234-5678",
  });
  (sneaky as Record<string, unknown>).consent_pdf_url = "https://x/y.pdf";
  const { handler, calls } = setup({ ok: true, data: sneaky });
  const res = await handler(post({ token: TOKEN }));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("cache-control"), "no-store");
  assertEquals(res.headers.get("access-control-allow-origin"), PAGES);
  const json = await res.json();
  assertEquals(json.ok, true);
  assertEquals(forbiddenKeys(json), []);
  assertEquals(json.shop.phone, "02-000-0000"); // shop business contact is allowed
  assertEquals(json.chart.care_report_json.summary, "ok");
  assertEquals(json.chart.care_report_json.nested[0].tip, "보습");
  assertEquals(calls.sign, [{
    bucket: "chart_photos",
    paths: [`${SHOP}/cust/a_before.webp`, `${SHOP}/cust/a_after.webp`],
    ttl: 600,
  }]);
  assert(json.chart.before_image_url.includes("/object/sign/chart_photos/"));
  assert(json.chart.after_image_url.includes("/object/sign/chart_photos/"));
  assertEquals(json.photos_unavailable, false);
  assertEquals(json.media_expires_in, 600);
  assertEquals(json.media_expires_at, "2026-10-03T00:10:00.000Z");
});

Deno.test("photos withheld by the RPC (no consent_photo) → no signing, nulls", async () => {
  const { handler, calls } = setup({ ok: true, data: payload({ before_image_url: null, after_image_url: null }) });
  const json = await (await handler(post({ token: TOKEN }))).json();
  assertEquals(calls.sign.length, 0);
  assertEquals(json.chart.before_image_url, null);
  assertEquals(json.photos_unavailable, false);
  assertEquals(json.media_expires_in, null);
});

Deno.test("images from another shop, foreign host or another bucket are dropped, never signed", async () => {
  const { handler, calls } = setup({
    ok: true,
    data: payload({
      before_image_url: pub(`${OTHER}/cust/x.webp`),
      after_image_url: `https://${HOST}/storage/v1/object/public/consent_pdfs/${SHOP}/c/x.pdf`,
    }),
  });
  const json = await (await handler(post({ token: TOKEN }))).json();
  assertEquals(calls.sign.length, 0);
  assertEquals(json.chart.before_image_url, null);
  assertEquals(json.chart.after_image_url, null);
  assertEquals(json.photos_unavailable, true);

  const foreign = setup({
    ok: true,
    data: payload({ before_image_url: "https://evil.example/x.webp", after_image_url: null }),
  });
  const j2 = await (await foreign.handler(post({ token: TOKEN }))).json();
  assertEquals(j2.chart.before_image_url, null);
  assertEquals(foreign.calls.sign.length, 0);
});

Deno.test("signing failure → null photo + photos_unavailable, still 200", async () => {
  const { handler } = setup({ ok: true, data: payload() }, {
    signUrls: (_b, paths) => Promise.resolve(paths.map((_, i) => (i === 0 ? null : "https://signed"))),
  });
  const json = await (await handler(post({ token: TOKEN }))).json();
  assertEquals(json.chart.before_image_url, null);
  assertEquals(json.chart.after_image_url, "https://signed");
  assertEquals(json.photos_unavailable, true);
  const thrower = setup({ ok: true, data: payload() }, { signUrls: () => Promise.reject(new Error("storage down")) });
  const res = await thrower.handler(post({ token: TOKEN }));
  assertEquals(res.status, 200);
  assertEquals((await res.json()).photos_unavailable, true);
});

Deno.test("unexpected RPC payload → 502", async () => {
  const { handler } = setup({ ok: true, data: [1, 2] });
  assertEquals((await handler(post({ token: TOKEN }))).status, 502);
});
