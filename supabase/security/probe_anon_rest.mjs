#!/usr/bin/env node
// SORI security baseline - PostgREST probe with the PUBLIC anon key, GET requests only.
//
// * Never writes: only HTTP GET. Table probes use `limit=0` + `Prefer: count=exact`,
//   so no row data is downloaded - only the HTTP status and the total row count
//   from the Content-Range header are recorded.
// * The anon key is public (it ships in the web bundle) but is NOT stored in the repo.
//   Pass it via env:  SORI_ANON_KEY=<anon or sb_publishable key> node supabase/security/probe_anon_rest.mjs
//   (Get it from Dashboard > Project Settings > API, or MCP get_publishable_keys.)
// * Optional: SUPABASE_URL (default: project tieojdbzmqcmlwyqltrk), --json for raw output.
//
// Expected after each P0 step: see supabase/security/baseline-2026-10-03.md.

const BASE = (process.env.SUPABASE_URL || 'https://tieojdbzmqcmlwyqltrk.supabase.co').replace(/\/$/, '');
const KEY = process.env.SORI_ANON_KEY;
if (!KEY) {
  console.error('SORI_ANON_KEY is required (public anon / publishable key).');
  process.exit(2);
}

const TABLES = [
  // A. customer-private
  'customers', 'customer_charts', 'customer_reviews', 'chart_photo_records', 'photo_sets',
  'review_replies', 'ai_replies', 'membership_tickets', 'care_diary_notes', 'kakao_msg_logs',
  'chart_records', 'customer_merge_events', 'chart_view_events', 'care_schedule_entries',
  'ba_capture_sessions',
  // B. shop public profile
  'shops', 'shop_posts', 'shop_gallery_items', 'shop_highlights', 'shop_menus',
  // C. money / ledger
  'wallets', 'point_transactions', 'settlement_transactions', 'market_escrow_holds',
  'shop_entitlements', 'shop_promo_credits',
  // E. admin / identity
  'shop_memberships', 'shop_notifications', 'profiles', 'staff_roles',
  // community + views
  'community_posts', 'community_comments', 'community_shared_cases', 'shop_assets',
  'unified_feed_items_v1', 'seminars',
  // M1 (expected 404 before migration, 401/403 or 0 rows after)
  'customer_access_tokens',
];

// Read-only RPCs probed with GET (PostgREST runs GET RPCs in a read-only transaction).
const RPCS = [
  ['list_community_shared_cases', { p_limit: '1' }],   // M1: anon-callable, 404 before migration
  ['get_review_context', { p_token: 'probe-invalid-token-0000000000000000000000' }], // M1: expect PT404 after
  ['list_community_posts_safe', { p_limit: '1' }],
];

const headers = {
  apikey: KEY,
  Authorization: `Bearer ${KEY}`,
  Accept: 'application/json',
  Prefer: 'count=exact',
};

function total(contentRange) {
  if (!contentRange) return null;
  const m = /\/(\d+|\*)$/.exec(contentRange);
  return m && m[1] !== '*' ? Number(m[1]) : null;
}

async function probeTable(t) {
  const url = `${BASE}/rest/v1/${encodeURIComponent(t)}?select=*&limit=0`;
  try {
    const res = await fetch(url, { method: 'GET', headers });
    let note = '';
    if (!res.ok) {
      const body = await res.text();
      try { const j = JSON.parse(body); note = [j.code, j.message].filter(Boolean).join(' '); } catch { note = body.slice(0, 120); }
    } else {
      await res.arrayBuffer(); // limit=0 -> empty array
    }
    return { kind: 'table', name: t, status: res.status, rows: total(res.headers.get('content-range')), note };
  } catch (e) {
    return { kind: 'table', name: t, status: 'ERR', rows: null, note: String(e).slice(0, 120) };
  }
}

async function probeRpc([fn, params]) {
  const qs = new URLSearchParams(params).toString();
  const url = `${BASE}/rest/v1/rpc/${fn}?${qs}`;
  try {
    const res = await fetch(url, { method: 'GET', headers: { ...headers, Prefer: '' } });
    const body = await res.text();
    let rows = null; let note = '';
    try {
      const j = JSON.parse(body);
      if (Array.isArray(j)) rows = j.length;
      else if (j && typeof j === 'object' && (j.code || j.message)) note = [j.code, j.message].filter(Boolean).join(' ');
      else rows = j === null ? 0 : 1;
    } catch { note = body.slice(0, 120); }
    return { kind: 'rpc', name: fn, status: res.status, rows, note };
  } catch (e) {
    return { kind: 'rpc', name: fn, status: 'ERR', rows: null, note: String(e).slice(0, 120) };
  }
}

const results = [];
for (const t of TABLES) results.push(await probeTable(t));
for (const r of RPCS) results.push(await probeRpc(r));

if (process.argv.includes('--json')) {
  console.log(JSON.stringify({ at: new Date().toISOString(), base: BASE, results }, null, 2));
} else {
  console.log(`# PostgREST anon GET probe - ${new Date().toISOString()} - ${BASE}`);
  console.log('');
  console.log('| kind | name | HTTP | rows (count=exact) | note |');
  console.log('|---|---|---|---|---|');
  for (const r of results) {
    console.log(`| ${r.kind} | \`${r.name}\` | ${r.status} | ${r.rows ?? '-'} | ${(r.note || '').replace(/\|/g, '\\|').replace(/\n/g, ' ')} |`);
  }
}
