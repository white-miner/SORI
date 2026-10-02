import { assertEquals } from "jsr:@std/assert@1";
import { isSafeObjectPath, parseStorageRef, projectHostFromUrl, shopIdFromPath } from "./media_path.ts";

const HOST = "tieojdbzmqcmlwyqltrk.supabase.co";
const SHOP = "f4145a4f-1111-4222-8333-444455556666";
const base = `https://${HOST}/storage/v1`;

Deno.test("projectHostFromUrl", () => {
  assertEquals(projectHostFromUrl("https://TIEOJDBZMQCMLWYQLTRK.supabase.co/"), HOST);
  assertEquals(projectHostFromUrl("not a url"), null);
  assertEquals(projectHostFromUrl(undefined), null);
});

Deno.test("public, sign, authenticated and render URLs → bucket/path", () => {
  const p = `${SHOP}/cust-1/abc_1_before.webp`;
  for (const prefix of ["object/public", "object/sign", "object/authenticated", "render/image/public"]) {
    assertEquals(
      parseStorageRef(`${base}/${prefix}/chart_photos/${p}?token=x&width=200#frag`, { projectHost: HOST }),
      { bucket: "chart_photos", path: p },
    );
  }
  assertEquals(
    parseStorageRef(`${base}/object/public/consent_pdfs/${SHOP}/c/%ED%95%9C.pdf`, { projectHost: HOST }),
    { bucket: "consent_pdfs", path: `${SHOP}/c/한.pdf` },
  );
});

Deno.test("foreign hosts, data URIs, unknown buckets and non-storage URLs → null", () => {
  const p = `${SHOP}/c/x.webp`;
  assertEquals(
    parseStorageRef(`https://evil.example/storage/v1/object/public/chart_photos/${p}`, { projectHost: HOST }),
    null,
  );
  assertEquals(parseStorageRef(`${base}/object/public/chart_photos/${p}`, { projectHost: null }), null);
  assertEquals(
    parseStorageRef("data:image/png;base64,AAAA", { projectHost: HOST, defaultBucket: "chart_photos" }),
    null,
  );
  assertEquals(parseStorageRef(`${base}/object/public/secret_bucket/${p}`, { projectHost: HOST }), null);
  assertEquals(parseStorageRef(`https://${HOST}/rest/v1/customers`, { projectHost: HOST }), null);
  assertEquals(parseStorageRef(`javascript://${HOST}/x`, { projectHost: HOST }), null);
  assertEquals(parseStorageRef(42, { projectHost: HOST }), null);
  assertEquals(parseStorageRef("   ", { projectHost: HOST, defaultBucket: "chart_photos" }), null);
});

Deno.test("bare object paths need a default bucket", () => {
  assertEquals(parseStorageRef(`/${SHOP}/unbound/x.webp`, { projectHost: HOST, defaultBucket: "chart_photos" }), {
    bucket: "chart_photos",
    path: `${SHOP}/unbound/x.webp`,
  });
  assertEquals(parseStorageRef(`${SHOP}/unbound/x.webp`, { projectHost: HOST }), null);
  assertEquals(parseStorageRef(`${SHOP}/x.webp`, { projectHost: HOST, defaultBucket: "nope" }), null);
});

Deno.test("path traversal and malformed paths are rejected", () => {
  for (const bad of ["", "/abs", "a//b", "a/../b", "./a", "a\\b", "a/\u0000", "x".repeat(513)]) {
    assertEquals(isSafeObjectPath(bad), false, JSON.stringify(bad));
  }
  assertEquals(parseStorageRef(`${SHOP}/../other/x`, { projectHost: HOST, defaultBucket: "chart_photos" }), null);
  assertEquals(parseStorageRef(`${base}/object/public/chart_photos/${SHOP}/%2e%2e/x`, { projectHost: HOST }), null);
  assertEquals(parseStorageRef(`${base}/object/public/chart_photos/${SHOP}%2F..%2Fx`, { projectHost: HOST }), null);
  assertEquals(parseStorageRef(`${base}/object/public/chart_photos/${SHOP}/%E0%A4%A`, { projectHost: HOST }), null);
});

Deno.test("shopIdFromPath requires a uuid first segment", () => {
  assertEquals(shopIdFromPath(`${SHOP.toUpperCase()}/c/x`), SHOP);
  assertEquals(shopIdFromPath("unknown-shop/c/x"), null);
  assertEquals(shopIdFromPath("x"), null);
});
