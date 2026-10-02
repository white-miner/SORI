import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  createMediaSignHandler,
  type MediaSignDeps,
  normalizeRef,
  parseAuthzMode,
  parsePublicCases,
  parseTtl,
  type SharedCase,
} from "./handler.ts";

const HOST = "tieojdbzmqcmlwyqltrk.supabase.co";
const PAGES = "https://white-miner.github.io";
const MINE = "f4145a4f-1111-4222-8333-444455556666";
const OTHER = "00000000-0000-4000-8000-0000000000f1";
const OWNER_JWT = "Bearer owner.jwt.sig";
const STRANGER_JWT = "Bearer stranger.jwt.sig";
const ANON_KEY = "Bearer anon.key.jwt";
const pub = (bucket: string, path: string) => `https://${HOST}/storage/v1/object/public/${bucket}/${path}`;

function setup(opts: Partial<MediaSignDeps> & { cases?: SharedCase[] } = {}) {
  const calls = {
    authz: [] as { shopId: string; mode: string }[],
    sign: [] as { bucket: string; paths: string[]; ttl: number }[],
    listed: [] as string[][],
  };
  const deps: MediaSignDeps = {
    getUserId: (auth) => Promise.resolve(auth === OWNER_JWT ? "u-owner" : auth === STRANGER_JWT ? "u-stranger" : null),
    canManageShop: (auth, shopId, mode) => {
      calls.authz.push({ shopId, mode });
      return Promise.resolve(auth === OWNER_JWT && shopId === MINE);
    },
    listSharedCases: (ids) => {
      calls.listed.push(ids);
      return Promise.resolve((opts.cases ?? []).filter((c) => ids.includes(c.chart_id)));
    },
    signUrls: (bucket, paths, ttl) => {
      calls.sign.push({ bucket, paths, ttl });
      return Promise.resolve(paths.map((p) => `https://${HOST}/storage/v1/object/sign/${bucket}/${p}?token=t`));
    },
    projectHost: HOST,
    allowedOrigins: [PAGES],
    authzMode: "owner",
    publicCasesEnabled: true,
    now: () => Date.parse("2026-10-03T00:00:00Z"),
    ...opts,
  };
  return { handler: createMediaSignHandler(deps), calls };
}

const post = (body: unknown, auth?: string) =>
  new Request("https://fn.example/media-sign", {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: PAGES, ...(auth ? { Authorization: auth } : {}) },
    body: JSON.stringify(body),
  });

Deno.test("env parsing", () => {
  assertEquals(parseAuthzMode(undefined), "owner");
  assertEquals(parseAuthzMode("Manager"), "manager");
  assertEquals(parseAuthzMode("admin"), "owner");
  assertEquals(parsePublicCases(undefined), true);
  assertEquals(parsePublicCases("off"), false);
  assertEquals(parseTtl(undefined), 3600);
  assertEquals(parseTtl(120), 120);
  assertEquals(parseTtl(30), null);
  assertEquals(parseTtl(7200), null);
  assertEquals(parseTtl(100.5), null);
  assertEquals(parseTtl("600"), null);
});

Deno.test("normalizeRef: URL, {url}, {bucket,path}; non-signable buckets; shop folder required", () => {
  const p = `${MINE}/cust/x.webp`;
  assertEquals(normalizeRef(pub("chart_photos", p), HOST), {
    ok: true,
    ref: { bucket: "chart_photos", path: p },
    shopId: MINE,
  });
  assertEquals(normalizeRef({ url: pub("consent_pdfs", `${MINE}/c/x.pdf`) }, HOST).ok, true);
  assertEquals(normalizeRef({ bucket: "chart-signatures", path: `${MINE}/c/1.png` }, HOST).ok, true);
  assertEquals(normalizeRef(pub("shop_profiles", `${MINE}/avatar.jpg`), HOST), {
    ok: false,
    error: "bucket_not_signable",
  });
  assertEquals(normalizeRef({ bucket: "chart-photos", path: `${MINE}/x` }, HOST), {
    ok: false,
    error: "bucket_not_signable",
  });
  assertEquals(normalizeRef(p, HOST), { ok: false, error: "invalid_ref" }); // bare path needs a bucket
  assertEquals(normalizeRef({ bucket: "chart_photos", path: "unknown-shop/c/x" }, HOST), {
    ok: false,
    error: "invalid_ref",
  });
  assertEquals(normalizeRef({ bucket: "chart_photos", path: `${MINE}/../${OTHER}/x` }, HOST), {
    ok: false,
    error: "invalid_ref",
  });
  assertEquals(normalizeRef("https://evil.example/storage/v1/object/public/chart_photos/" + p, HOST), {
    ok: false,
    error: "invalid_ref",
  });
});

Deno.test("refs: no Authorization or anon key → 401, nothing signed", async () => {
  for (const auth of [undefined, ANON_KEY]) {
    const { handler, calls } = setup();
    const res = await handler(post({ refs: [pub("chart_photos", `${MINE}/c/x.webp`)] }, auth));
    assertEquals(res.status, 401);
    assertEquals((await res.json()).error, "login_required");
    assertEquals(calls.sign.length + calls.authz.length, 0);
  }
});

Deno.test("refs: owner signs own shop objects in one call per bucket (URL and path forms)", async () => {
  const { handler, calls } = setup();
  const res = await handler(post({
    refs: [
      pub("chart_photos", `${MINE}/c/a.webp`),
      { bucket: "chart_photos", path: `${MINE}/unbound/b.webp` },
      { url: pub("consent_pdfs", `${MINE}/c/x.pdf`) },
      pub("shop_profiles", `${MINE}/avatar.jpg`),
      "data:image/png;base64,AAAA",
    ],
    expires_in: 900,
  }, OWNER_JWT));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("cache-control"), "no-store");
  const json = await res.json();
  assertEquals(json.expires_in, 900);
  assertEquals(json.expires_at, "2026-10-03T00:15:00.000Z");
  assertEquals(calls.authz, [{ shopId: MINE, mode: "owner" }]);
  assertEquals(calls.sign, [
    { bucket: "chart_photos", paths: [`${MINE}/c/a.webp`, `${MINE}/unbound/b.webp`], ttl: 900 },
    { bucket: "consent_pdfs", paths: [`${MINE}/c/x.pdf`], ttl: 900 },
  ]);
  assert(json.items[0].signed_url.includes("/object/sign/chart_photos/"));
  assertEquals(json.items[3], { index: 3, signed_url: null, error: "bucket_not_signable" });
  assertEquals(json.items[4], { index: 4, signed_url: null, error: "invalid_ref" });
});

Deno.test("refs: any other shop's path → 403 for the whole request, nothing signed", async () => {
  for (const auth of [OWNER_JWT, STRANGER_JWT]) {
    const { handler, calls } = setup();
    const res = await handler(post({
      refs: [pub("chart_photos", `${MINE}/c/a.webp`), { bucket: "consent_pdfs", path: `${OTHER}/c/x.pdf` }],
    }, auth));
    assertEquals(res.status, 403);
    const json = await res.json();
    assertEquals(json.error, "forbidden");
    assertEquals(json.forbidden, auth === OWNER_JWT ? [1] : [0, 1]);
    assertEquals(calls.sign.length, 0);
  }
});

Deno.test("refs: manager mode is passed through to the authz check", async () => {
  const { handler, calls } = setup({ authzMode: "manager" });
  await (await handler(post({ refs: [pub("chart_photos", `${MINE}/c/a.webp`)] }, OWNER_JWT))).body?.cancel();
  assertEquals(calls.authz, [{ shopId: MINE, mode: "manager" }]);
});

Deno.test("refs: validation", async () => {
  const { handler } = setup();
  const tooMany = Array.from({ length: 51 }, (_, i) => pub("chart_photos", `${MINE}/c/${i}.webp`));
  for (
    const [body, error] of [
      [{ refs: [] }, "invalid_refs"],
      [{ refs: tooMany }, "invalid_refs"],
      [{ refs: "x" }, "invalid_refs"],
      [{ refs: [pub("chart_photos", `${MINE}/c/a.webp`)], expires_in: 99999 }, "invalid_expires_in"],
    ] as const
  ) {
    const res = await handler(post(body, OWNER_JWT));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, error);
  }
  for (const body of [{}, { refs: [], case_chart_ids: [] }]) {
    const res = await handler(post(body, OWNER_JWT));
    assertEquals(res.status, 400);
    assertEquals((await res.json()).error, "use_refs_or_case_chart_ids");
  }
});

const SHARED = "e4000000-0000-4000-8000-000000000001";
const UNSHARED = "e4000000-0000-4000-8000-000000000002";

Deno.test("cases: shared + consented case photos signed for 1 hour without login (Q1)", async () => {
  const { handler, calls } = setup({
    cases: [{
      chart_id: SHARED,
      shop_id: MINE,
      before_image_url: pub("chart_photos", `${MINE}/c/b.webp`),
      after_image_url: `${MINE}/c/a.webp`,
    }],
  });
  const res = await handler(post({ case_chart_ids: [SHARED, UNSHARED, SHARED.toUpperCase()] }));
  assertEquals(res.status, 200);
  const json = await res.json();
  assertEquals(calls.listed, [[SHARED, UNSHARED]]);
  assertEquals(calls.sign, [{ bucket: "chart_photos", paths: [`${MINE}/c/b.webp`, `${MINE}/c/a.webp`], ttl: 3600 }]);
  assertEquals(json.items.length, 1);
  assertEquals(json.items[0].chart_id, SHARED);
  assert(json.items[0].before_url.includes("/object/sign/"));
  assertEquals(json.not_eligible, [UNSHARED]);
  assertEquals(json.expires_in, 3600);
});

Deno.test("cases: non-shared/unconsented chart → no URL; photo outside the case's shop folder → not signed", async () => {
  const { handler, calls } = setup({
    cases: [{
      chart_id: SHARED,
      shop_id: MINE,
      before_image_url: pub("chart_photos", `${OTHER}/c/b.webp`),
      after_image_url: null,
    }],
  });
  const json = await (await handler(post({ case_chart_ids: [SHARED, UNSHARED] }))).json();
  assertEquals(calls.sign.length, 0);
  assertEquals(json.items, [{ chart_id: SHARED, before_url: null, after_url: null }]);
  assertEquals(json.not_eligible, [UNSHARED]);
});

Deno.test("cases: validation and kill switch", async () => {
  const { handler } = setup();
  for (const ids of [[], ["nope"], Array.from({ length: 21 }, () => SHARED), "x"]) {
    const res = await handler(post({ case_chart_ids: ids }));
    assertEquals(res.status, 400);
    await res.body?.cancel();
  }
  const off = setup({ publicCasesEnabled: false });
  const res = await off.handler(post({ case_chart_ids: [SHARED] }));
  assertEquals(res.status, 403);
  assertEquals((await res.json()).error, "public_cases_disabled");
  assertEquals(off.calls.listed.length, 0);
});

Deno.test("unexpected dependency failure → 500 without details", async () => {
  const { handler } = setup({ getUserId: () => Promise.reject(new Error("auth down secret")) });
  const res = await handler(post({ refs: [pub("chart_photos", `${MINE}/c/a.webp`)] }, OWNER_JWT));
  assertEquals(res.status, 500);
  const text = await res.text();
  assert(!text.includes("secret"));
});
