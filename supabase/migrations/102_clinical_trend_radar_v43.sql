-- PRD v4.3 — Clinical Trend Radar: CCKS keywords + hourly snapshots + scripts.
-- PO §8: 15 global keywords, 2h edge cache, shop custom slots reserved (future).

CREATE TABLE IF NOT EXISTS public.clinical_trend_keywords (
  id text PRIMARY KEY,
  keyword text NOT NULL,
  category text NOT NULL,
  po_priority integer NOT NULL DEFAULT 50,
  is_global boolean NOT NULL DEFAULT true,
  shop_id uuid REFERENCES public.shops(id) ON DELETE CASCADE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT clinical_trend_keywords_shop_scope CHECK (
    (is_global = true AND shop_id IS NULL)
    OR (is_global = false AND shop_id IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_clinical_trend_keywords_shop
  ON public.clinical_trend_keywords (shop_id, is_active)
  WHERE shop_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.clinical_trend_scripts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  keyword_id text NOT NULL REFERENCES public.clinical_trend_keywords(id) ON DELETE CASCADE,
  headline text NOT NULL DEFAULT '',
  narrative_template text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (keyword_id)
);

CREATE TABLE IF NOT EXISTS public.shop_clinical_trend_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id uuid NOT NULL REFERENCES public.shops(id) ON DELETE CASCADE,
  hour_bucket timestamptz NOT NULL,
  trend_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  fetched_at timestamptz NOT NULL DEFAULT now(),
  source text NOT NULL DEFAULT 'naver',
  UNIQUE (shop_id, hour_bucket)
);

CREATE INDEX IF NOT EXISTS idx_shop_clinical_trend_snapshots_shop_hour
  ON public.shop_clinical_trend_snapshots (shop_id, hour_bucket DESC);

ALTER TABLE public.clinical_trend_keywords ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinical_trend_scripts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_clinical_trend_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY clinical_trend_keywords_read ON public.clinical_trend_keywords
  FOR SELECT USING (
    is_global = true
    OR shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
    )
  );

CREATE POLICY clinical_trend_scripts_read ON public.clinical_trend_scripts
  FOR SELECT USING (true);

CREATE POLICY shop_clinical_trend_snapshots_read ON public.shop_clinical_trend_snapshots
  FOR SELECT USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
    )
  );

CREATE POLICY shop_clinical_trend_snapshots_write ON public.shop_clinical_trend_snapshots
  FOR ALL USING (
    shop_id IN (
      SELECT sm.shop_id FROM public.shop_memberships sm
      WHERE sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'director')
    )
  );

-- PO v4.3 CCKS 15선 (global SSOT)
INSERT INTO public.clinical_trend_keywords (id, keyword, category, po_priority, is_global)
VALUES
  ('K01', '홍조', 'barrier_sensitive', 100, true),
  ('K02', '피부장벽', 'barrier_sensitive', 95, true),
  ('K03', '트러블', 'trouble_sebum', 90, true),
  ('K04', '모공', 'trouble_sebum', 85, true),
  ('K05', '각질', 'trouble_sebum', 80, true),
  ('K06', '수분폭탄', 'hydration', 75, true),
  ('K07', '속건조', 'hydration', 70, true),
  ('K08', '탄력리프팅', 'lifting_body', 65, true),
  ('K09', '주름', 'lifting_body', 60, true),
  ('K10', '뱃살관리', 'lifting_body', 55, true),
  ('K11', '셀룰라이트', 'lifting_body', 50, true),
  ('K12', '기미잡티', 'pigment_tone', 45, true),
  ('K13', '색소침착', 'pigment_tone', 40, true),
  ('K14', '피부결', 'pigment_tone', 35, true),
  ('K15', '두피각질', 'scalp', 30, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.clinical_trend_scripts (keyword_id, headline, narrative_template)
VALUES
  ('K01', '홍조 검색 급증', '요즘 ''홍조'' 검색이 {surge}% 올랐어요. 장벽·진정 쪽 먼저 여쭤보시면 고객이 트렌드까지 아는 샵이라고 느낍니다.'),
  ('K02', '피부장벽 관심↑', '''피부장벽'' 고민 검색이 {surge}% 증가했습니다. TEWL·민감 반응을 짚어 주시면 신뢰가 빨리 쌓입니다.'),
  ('K03', '트러블 수요 활발', '''트러블'' 검색이 {surge}% 올랐어요. 활성 여부와 홈케어 루틴부터 가볍게 확인해 보세요.'),
  ('K04', '모공 고민 트렌드', '''모공'' 검색이 {surge}% 증가 중입니다. 과도한 각질 제거보다 피지 밸런스 관점으로 상담하세요.'),
  ('K05', '각질 케어 수요', '''각질'' 검색이 {surge}% 올랐습니다. 계절·장벽 상태에 맞는 각질 케어 강도를 먼저 맞춰 주세요.'),
  ('K06', '수분폭탄 인기', '''수분폭탄'' 검색이 {surge}% 급증했어요. 속건조·TEWL과 연결해 패키지 제안 포인트를 잡으세요.'),
  ('K07', '속건조 관심↑', '''속건조'' 검색이 {surge}% 올랐습니다. 겉유분과 속당김을 구분해 질문하면 전문성이 드러납니다.'),
  ('K08', '탄력리프팅 수요', '''탄력리프팅'' 검색이 {surge}% 증가했습니다. HIFU·리프팅 기대치를 먼저 듣고 강도를 맞추세요.'),
  ('K09', '주름 상담 트렌드', '''주름'' 검색이 {surge}% 올랐어요. 표정습관·선택 부위를 함께 짚어 주시면 만족도가 올라갑니다.'),
  ('K10', '뱃살관리 관심', '''뱃살관리'' 검색이 {surge}% 증가 중입니다. 바디 프로그램 연계 시 기대 기간을 명확히 안내하세요.'),
  ('K11', '셀룰라이트 수요', '''셀룰라이트'' 검색이 {surge}% 올랐습니다. 생활습관·림프 순환 관점의 질문으로 상담을 시작하세요.'),
  ('K12', '기미잡티 검색↑', '''기미잡티'' 검색이 {surge}% 급증했어요. 자외선·색소 타입을 먼저 확인하고 레이저 강도를 조절하세요.'),
  ('K13', '색소침착 관심', '''색소침착'' 검색이 {surge}% 올랐습니다. PIH 이력과 홈케어 SPF 습관을 함께 점검하세요.'),
  ('K14', '피부결 트렌드', '''피부결'' 검색이 {surge}% 증가했습니다. 결·광채 목표를 구체화하면 시술 플랜이 명확해집니다.'),
  ('K15', '두피각질 수요', '''두피각질'' 검색이 {surge}% 올랐어요. 두피·모발 동시 고민인지 가볍게 확인해 보세요.')
ON CONFLICT (keyword_id) DO NOTHING;
