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
    fetch: (url, init) => String(url).includes('/largeUpjongList')
      ? Promise.resolve(new Response(JSON.stringify({body:{items:[{indsLclsCd:'S2',indsLclsNm:'수리·개인 서비스'}]}})))
      : fetcher(url, init), Response, Request, URL, URLSearchParams, AbortSignal,
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
  assert.equal(requests[0].searchParams.get('indsLclsCd'), 'S2');
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


test('real public classifications exclude clinics, schools and similarly named businesses', () => {
  const e = edge();
  for (const row of [
    {bizesNm:'핑의원', indsSclsNm:'피부/비뇨기과 의원'},
    {bizesNm:'네일아카데미', indsSclsNm:'기타 기술/직업 훈련학원'},
    {bizesNm:'파이브스타투어', indsSclsNm:'여행사'},
    {bizesNm:'네일유통', indsSclsNm:'화장품 소매업'},
  ]) assert.equal(e.call(`chipKeyForStore(${JSON.stringify(row)})`), 'other');
  assert.equal(e.call(`chipKeyForStore({bizesNm:'정본에스테틱',indsSclsNm:'피부 관리실'})`), 'skin');
  assert.equal(e.call(`matchesCategory({indsSclsNm:'피부 관리실'}, categoryKeywords('에스테틱'))`), true);
});

test('store rows keep floor, building, and KSIC names additively (JSON and XML)', async () => {
  const row = {...shop(1, '피부 관리실'), flrNo:'2', bldNm:'황오빌딩', ksicNm:'피부 미용업', bldMngNo:'4713011200101150018000001', brchNm:'황오점'};
  const result = await edge(async () => page([row], 1)).call(`fetchStores(${opts})`);
  const item = result.items[0];
  assert.equal(item.flr_no, '2');
  assert.equal(item.bld_nm, '황오빌딩');
  assert.equal(item.ksic_nm, '피부 미용업');
  assert.equal(item.bld_mng_no, '4713011200101150018000001');
  assert.equal(item.brch_nm, '황오점');
  assert.equal(item.address, '서울 테스트로');
  assert.equal(item.chip_key, 'skin');
  const legacy = (await edge(async () => page([shop(2, '피부 관리실')], 1)).call(`fetchStores(${opts})`)).items[0];
  assert.equal(legacy.flr_no, '');
  assert.equal(legacy.bld_nm, '');
  assert.equal(legacy.ksic_nm, '');
  assert.equal(legacy.bizes_id, '2');
  const xml = edge().call(`extractXmlItemMaps('<items><item><bizesNm>샵</bizesNm><flrNo>B1</flrNo><bldNm>빌딩</bldNm><ksicNm>피부 미용업</ksicNm><bldMngNo>9</bldMngNo></item></items>')[0]`);
  assert.equal(xml.flrNo, 'B1');
  assert.equal(xml.bldNm, '빌딩');
  assert.equal(xml.ksicNm, '피부 미용업');
  assert.equal(xml.bldMngNo, '9');
});

test('license name normalization strips spaces, punctuation, case, and branch suffixes', () => {
  const e = edge();
  assert.equal(e.call(`normalizeShopName('  피어나-스킨 엔 바디 (주) ')`), '피어나스킨엔바디');
  assert.equal(e.call(`normalizeShopName('Nail·Lab')`), 'naillab');
  for (const [a, b] of [
    ['피어나스킨엔바디', '피어나 스킨엔바디'],
    ['소리헤어 황오점', '소리헤어'],
    ['소리헤어(황오점)', '소리 헤어'],
    ['소리헤어황오점', '소리헤어'],
    ['소리헤어 본점', '소리헤어'],
    ['NAIL LAB', 'nail-lab'],
  ]) assert.equal(e.call(`shopNamesMatch(${JSON.stringify(a)}, ${JSON.stringify(b)})`), true, `${a} ~ ${b}`);
  for (const [a, b] of [
    ['소리헤어', '소리네일'],
    ['피어나스킨엔바디', '피어나'],
    ['A', 'A'],
    ['', ''],
  ]) assert.equal(e.call(`shopNamesMatch(${JSON.stringify(a)}, ${JSON.stringify(b)})`), false, `${a} !~ ${b}`);
});

test('license road address normalization keeps road + building number and drops floor/호', () => {
  const e = edge();
  const key = e.call(`normalizeRoadAddress('경상북도 경주시 원화로 234, 2층 (황오동)')`);
  assert.equal(key.sido, '경북');
  assert.equal(key.sigungu, '경주시');
  assert.equal(key.road, '원화로');
  assert.equal(key.bldg, '234');
  assert.equal(e.call(`normalizeRoadAddress('서울 강남구 테헤란로 123길 45 3층 301호').road`), '테헤란로123길');
  assert.equal(e.call(`normalizeRoadAddress('경북 경주시 원화로234번길 5-1').bldg`), '5-1');
  assert.equal(e.call(`normalizeRoadAddress('경북 경주시 원화로234번길 5-1').road`), '원화로234번길');
  assert.equal(e.call(`normalizeRoadAddress('서울 종로구 종로 1').road`), '종로');
  assert.equal(e.call(`normalizeRoadAddress('황오동 115-18')`), null);
  for (const [a, b] of [
    ['경북 경주시 원화로 234', '경상북도 경주시 원화로 234, 2층 (황오동)'],
    ['서울 강남구 테헤란로 123길 45', '서울특별시 강남구 테헤란로123길 45, 3층'],
    ['경북 경주시 원화로 234 2층', '경상북도 경주시 원화로 234'],
  ]) assert.equal(e.call(`roadAddressesMatch(${JSON.stringify(a)}, ${JSON.stringify(b)})`), true, `${a} ~ ${b}`);
  for (const [a, b] of [
    ['경북 경주시 원화로 234', '경상북도 경주시 원화로 236'],
    ['경북 경주시 원화로 234', '경상남도 김해시 원화로 234'],
    ['경북 경주시 원화로 234', '경상북도 경주시 원화로234번길 5'],
    ['경북 경주시 원화로 234', ''],
  ]) assert.equal(e.call(`roadAddressesMatch(${JSON.stringify(a)}, ${JSON.stringify(b)})`), false, `${a} !~ ${b}`);
});

test('license status codes, dates, and candidate preference', () => {
  const e = edge();
  assert.equal(e.call(`licenseStatusOf('01', '영업/정상')`), 'open');
  assert.equal(e.call(`licenseStatusOf('02', '휴업')`), 'suspended');
  assert.equal(e.call(`licenseStatusOf('03', '폐업')`), 'closed');
  assert.equal(e.call(`licenseStatusOf('', '영업/정상')`), 'open');
  assert.equal(e.call(`licenseStatusOf('05', '제외/삭제/전출')`), null);
  assert.equal(e.call(`licenseYmd('20190510')`), '2019-05-10');
  assert.equal(e.call(`licenseYmd('2019-05-10')`), '2019-05-10');
  assert.equal(e.call(`licenseYmd('20190231')`), null);
  assert.equal(e.call(`licenseYmd('')`), null);
  const rows = JSON.stringify([
    {BPLC_NM:'피어나스킨엔바디', ROAD_NM_ADDR:'경상북도 경주시 원화로 234, 2층', SALS_STTS_CD:'03', LCPMT_YMD:'20210101'},
    {BPLC_NM:'피어나 스킨엔바디', ROAD_NM_ADDR:'경상북도 경주시 원화로 234', SALS_STTS_CD:'01', LCPMT_YMD:'20190510'},
    {BPLC_NM:'피어나스킨엔바디', ROAD_NM_ADDR:'경상북도 경주시 원화로 234', SALS_STTS_CD:'01', LCPMT_YMD:'20150101'},
    {BPLC_NM:'다른샵', ROAD_NM_ADDR:'경상북도 경주시 원화로 234', SALS_STTS_CD:'01', LCPMT_YMD:'20240101'},
  ]);
  assert.equal(e.call(`pickLicenseMatch(${rows}, '피어나스킨엔바디', '경북 경주시 원화로 234').LCPMT_YMD`), '20190510');
  assert.equal(e.call(`pickLicenseMatch(${rows}, '피어나스킨엔바디', '경북 경주시 원화로 999')`), null);
  assert.equal(e.call(`pickLicenseMatch(${rows}, '없는샵', '경북 경주시 원화로 234')`), null);
});

const licensePage = (items, code = '00') => new Response(JSON.stringify({
  response: {header:{resultCode:code, resultMsg:'NORMAL SERVICE'}, body:{dataType:'JSON', pageNo:1, numOfRows:100, totalCount:items.length, items:{item:items}}},
}));

test('license_status queries the official endpoint once-encoded and matches name + road address', async () => {
  const urls = [];
  const e = edge(async url => {
    urls.push(String(url));
    return licensePage([
      {BPLC_NM:'피어나스킨엔바디', ROAD_NM_ADDR:'경상북도 경주시 원화로 234, 2층 (황오동)', SALS_STTS_CD:'01', SALS_STTS_NM:'영업/정상', LCPMT_YMD:'20190510', CLSBIZ_YMD:''},
      {BPLC_NM:'옆집네일', ROAD_NM_ADDR:'경상북도 경주시 원화로 234, 1층', SALS_STTS_CD:'01', SALS_STTS_NM:'영업/정상', LCPMT_YMD:'20220101'},
    ]);
  }, {MOIS_BEAUTY_LICENSE_SERVICE_KEY:'abc%2Bdef%3D'});
  const response = await e.handler(new Request('https://example.test', {method:'POST', body:JSON.stringify({
    action:'license_status', name:'피어나스킨엔바디', address:'경북 경주시 원화로 234', latitude:35.85, longitude:129.22,
  })}));
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(urls.length, 1);
  const url = new URL(urls[0]);
  assert.equal(url.origin + url.pathname, 'https://apis.data.go.kr/1741000/beauty_salons/info');
  assert.equal(url.searchParams.get('serviceKey'), 'abc+def=');
  assert.ok(urls[0].includes('serviceKey=abc%2Bdef%3D&'));
  assert.equal(url.searchParams.get('returnType'), 'json');
  assert.equal(url.searchParams.get('numOfRows'), '100');
  assert.equal(url.searchParams.get('pageNo'), '1');
  assert.equal(url.searchParams.get('cond[ROAD_NM_ADDR::LIKE]'), '원화로 234');
  assert.equal(body.matched, true);
  assert.equal(body.status, 'open');
  assert.equal(body.status_label, '영업/정상');
  assert.equal(body.licensed_on, '2019-05-10');
  assert.equal(body.closed_on, null);
  assert.equal(body.source, '행정안전부 생활_미용업 인허가 정보');
  assert.ok(body.fetched_at);
  assert.ok(!JSON.stringify(body).includes('abc'));
});

test('license_status never infers closure from no match, missing key, or upstream failure', async () => {
  const urls = [];
  const none = await edge(async url => { urls.push(String(url)); return licensePage([]); }, {MOIS_BEAUTY_LICENSE_SERVICE_KEY:'k'})
    .call(`licenseStatus({name:'피어나스킨엔바디', address:'경북 경주시 원화로 234'})`);
  assert.equal(none.matched, false);
  assert.equal(none.status, null);
  assert.equal(none.reason, 'no_match');
  assert.equal(urls.length, 2);
  assert.equal(new URL(urls[1]).searchParams.get('cond[BPLC_NM::LIKE]'), '피어나스킨엔바디');

  const missing = await edge().handler(new Request('https://example.test', {method:'POST', body:JSON.stringify({action:'license_status', name:'샵', address:'경북 경주시 원화로 234'})}));
  assert.equal(missing.status, 200);
  const missingBody = await missing.json();
  assert.equal(missingBody.matched, false);
  assert.equal(missingBody.status, null);
  assert.equal(missingBody.reason, 'missing_MOIS_BEAUTY_LICENSE_SERVICE_KEY');

  const down = await edge(async () => { throw new Error('https://apis.data.go.kr/?serviceKey=secret'); }, {MOIS_BEAUTY_LICENSE_SERVICE_KEY:'secret'})
    .call(`licenseStatus({name:'샵샵', address:'경북 경주시 원화로 234'})`);
  assert.equal(down.matched, false);
  assert.equal(down.status, null);
  assert.equal(down.reason, 'upstream_unavailable');
  assert.ok(!JSON.stringify(down).includes('secret'));

  const auth = await edge(async () => licensePage([], '30'), {MOIS_BEAUTY_LICENSE_SERVICE_KEY:'k'})
    .call(`licenseStatus({name:'샵샵', address:'경북 경주시 원화로 234'})`);
  assert.equal(auth.matched, false);
  assert.equal(auth.reason, 'api_30');

  const unparsed = await edge(undefined, {MOIS_BEAUTY_LICENSE_SERVICE_KEY:'k'})
    .call(`licenseStatus({name:'샵샵', address:'황오동 115-18'})`);
  assert.equal(unparsed.matched, false);
  assert.equal(unparsed.reason, 'road_address_unparsed');
});
