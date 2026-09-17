import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

function edge(fetcher = async () => { throw new Error('Unexpected network'); }, secrets = {}) {
  const source = readFileSync(new URL('../supabase/functions/get-shop-market/index.ts', import.meta.url), 'utf8')
    .replace('import "jsr:@supabase/functions-js/edge-runtime.d.ts";', '');
  let handler;
  const context = vm.createContext({
    fetch: fetcher, Response, Request, URL, URLSearchParams, AbortSignal,
    console, setTimeout, clearTimeout,
    Deno: { env: { get: key => secrets[key] }, serve: fn => { handler = fn; } },
  });
  vm.runInContext(stripTypeScriptTypes(source), context);
  return { context, handler, call: expression => vm.runInContext(expression, context) };
}

test('preserves nested JSON and XML store response parsing', () => {
  const e = edge();
  assert.equal(e.call(`extractStoreItems({response:{body:{items:{item:[{bizesNm:'샵'}]}}}}).length`), 1);
  assert.equal(e.call(`extractXmlItemMaps('<items><item><bizesNm>샵</bizesNm><lat>37.5</lat><lon>127</lon></item></items>')[0].bizesNm`), '샵');
  assert.equal(e.call(`headerResultCode({response:{header:{resultCode:'00'}}})`), '00');
});

test('preserves missing-key failure and CORS preflight', async () => {
  const e = edge();
  const preflight = await e.handler(new Request('https://example.test', {method:'OPTIONS'}));
  assert.equal(preflight.headers.get('access-control-allow-origin'), '*');
  const response = await e.handler(new Request('https://example.test', {
    method:'POST', body:JSON.stringify({latitude:37.5, longitude:127, radius_m:1000}),
  }));
  const body = await response.json();
  assert.equal(body.stores.ok, false);
  assert.equal(body.stores.error, 'missing_SBIZ_STORE_SERVICE_KEY');
});

const shop = (id, category = '두발 미용업') => ({bizesId:String(id), bizesNm:`샵${id}`, indsSclsNm:category, lat:37.5, lon:127, rdnmAdr:'서울 테스트로'});
const page = (items, totalCount) => new Response(JSON.stringify({header:{resultCode:'00'},body:{items, ...(totalCount == null ? {} : {totalCount})}}));
const opts = `{key:'abc%2Bdef%3D',lat:37.5,lng:127,radiusM:1000,category:'전체',beautyOnly:true}`;

test('reads subsequent pages, encodes key once, excludes non-beauty and deduplicates', async () => {
  const requests = [];
  const e = edge(async url => {
    requests.push(new URL(url));
    return requests.length === 1
      ? page([shop(1),shop(2,'커피 전문점')], 4)
      : page([shop(1),shop(3,'피부 미용업')], 4);
  });
  const result = await e.call(`fetchStores(${opts})`);
  assert.equal(requests.length, 2);
  assert.equal(requests[1].searchParams.get('pageNo'), '2');
  assert.equal(requests[0].searchParams.get('serviceKey'), 'abc+def=');
  assert.equal(result.items.length, 2);
  assert.equal(result.items[1].chip_key, 'skin');
  assert.equal(result.complete, true);
});

test('does not report a failed later page as a complete census', async () => {
  let calls = 0;
  const e = edge(async () => ++calls === 1 ? page([shop(1)], 2) : new Response('down',{status:503}));
  const result = await e.call(`fetchStores(${opts})`);
  assert.equal(result.ok, true);
  assert.equal(result.items.length, 1);
  assert.equal(result.complete, false);
  assert.equal(result.error, 'http_503');
});

test('unknown total requires terminal empty page; true zero remains complete', async () => {
  let calls = 0;
  const e = edge(async () => page(++calls === 1 ? [shop(1)] : []));
  const result = await e.call(`fetchStores(${opts})`);
  assert.equal(calls, 2);
  assert.equal(result.complete, true);
  const zero = await edge(async () => page([],0)).call(`fetchStores(${opts})`);
  assert.equal(zero.items.length, 0);
  assert.equal(zero.complete, true);
});

test('XML authentication errors are not converted into zero shops', async () => {
  const result = await edge(async () => new Response('<OpenAPI_ServiceResponse><returnReasonCode>30</returnReasonCode></OpenAPI_ServiceResponse>')).call(`fetchStores(${opts})`);
  assert.equal(result.ok, false);
  assert.equal(result.error, 'api_30');
});

test('store-only lookup never waits for population API', async () => {
  const urls = [];
  const e = edge(async url => { urls.push(String(url)); return page([shop(1)],1); }, {SBIZ_STORE_SERVICE_KEY:'test', MOIS_POP_SERVICE_KEY:'test'});
  const response = await e.handler(new Request('https://example.test',{method:'POST',body:JSON.stringify({action:'stores',latitude:37.5,longitude:127,radius_m:1000})}));
  const body = await response.json();
  assert.equal(urls.length, 1);
  assert.equal(body.stores.complete, true);
  assert.equal(body.sources.length, 1);
});

test('invalid coordinates and unsupported radius fail instead of silently changing location', async () => {
  for (const body of [{}, {latitude:37.5,longitude:127,radius_m:10000}]) {
    const response = await edge().handler(new Request('https://example.test',{method:'POST',body:JSON.stringify(body)}));
    assert.equal(response.status, 400);
  }
});
