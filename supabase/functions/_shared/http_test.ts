import { assertEquals } from "jsr:@std/assert@1";
import { bearerHeader, gateRequest, isOriginAllowed, parseAllowedOrigins, readJsonObject } from "./http.ts";

const PAGES = "https://white-miner.github.io";

Deno.test("origin allow-list", () => {
  const allowed = parseAllowedOrigins(undefined);
  assertEquals(allowed, [PAGES]);
  assertEquals(isOriginAllowed(PAGES, allowed), true);
  assertEquals(isOriginAllowed(null, allowed), true); // curl / native app
  assertEquals(isOriginAllowed("http://localhost:5173", allowed), true);
  assertEquals(isOriginAllowed("https://evil.example", allowed), false);
  assertEquals(isOriginAllowed("https://white-miner.github.io.evil.example", allowed), false);
  assertEquals(parseAllowedOrigins("https://a.example/, junk ,https://b.example"), [
    "https://a.example",
    "https://b.example",
  ]);
});

Deno.test("gateRequest: preflight, foreign origin, method", async () => {
  const ok = gateRequest(new Request("https://x/f", { method: "OPTIONS", headers: { Origin: PAGES } }), [PAGES])!;
  assertEquals(ok.status, 204);
  assertEquals(ok.headers.get("access-control-allow-origin"), PAGES);
  const evil = gateRequest(
    new Request("https://x/f", { method: "OPTIONS", headers: { Origin: "https://evil.example" } }),
    [PAGES],
  )!;
  assertEquals(evil.status, 403);
  assertEquals(evil.headers.get("access-control-allow-origin"), null);
  await evil.body?.cancel();
  const get = gateRequest(new Request("https://x/f?token=abc"), [PAGES])!;
  assertEquals(get.status, 405);
  await get.body?.cancel();
  assertEquals(gateRequest(new Request("https://x/f", { method: "POST", body: "{}" }), [PAGES]), null);
});

Deno.test("readJsonObject rejects non-objects and oversized bodies", async () => {
  const r = (body: string) => new Request("https://x/f", { method: "POST", body });
  assertEquals((await readJsonObject(r('{"a":1}'), 100)).ok, true);
  assertEquals(await readJsonObject(r("[1]"), 100), { ok: false, error: "invalid_json" });
  assertEquals(await readJsonObject(r("nope"), 100), { ok: false, error: "invalid_json" });
  assertEquals(await readJsonObject(r(`{"a":"${"x".repeat(200)}"}`), 100), { ok: false, error: "body_too_large" });
});

Deno.test("bearerHeader", () => {
  const h = (v?: string) => new Request("https://x", { headers: v ? { Authorization: v } : {} });
  assertEquals(bearerHeader(h("Bearer abc.def")), "Bearer abc.def");
  assertEquals(bearerHeader(h("bearer   abc")), "Bearer abc");
  assertEquals(bearerHeader(h("Basic abc")), null);
  assertEquals(bearerHeader(h("Bearer ")), null);
  assertEquals(bearerHeader(h()), null);
});
