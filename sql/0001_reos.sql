-- ═══════════════════════════════════════════════════════════════
-- Re:O-S — 제작기획사 외주관리
--
-- Re:Bind(제조공정) · Re:Call(고객관리) · Re:Store(가맹점 발주)와
-- 같은 데이터베이스, 같은 계정입니다. 회사 격리와 담당자 규칙은
-- 0001_init(Re:Call) 에서 만든 도우미 함수를 그대로 씁니다.
--
--   current_company_id()  지금 로그인한 사람의 회사
--   is_admin()            관리자인가
--   company_for_app(app)  그 서비스를 산 회사인가   (Rebind/sql/0019_apps.sql)
--   touch_updated_at()    수정시각 자동 갱신
--
-- ───────────────────────────────────────────────────────────────
-- 왜 표 이름 앞에 os_ 를 붙였나
--   Re:Bind 가 이미 projects 를 쓰고 있습니다. 제작기획사의 "프로젝트"는
--   제본소의 "프로젝트"와 담는 것이 전혀 다른데 이름이 같으면 둘 중 하나가
--   못 들어옵니다. 형제가 늘어날수록 이 충돌은 더 자주 납니다.
--   그래서 이 앱의 표는 전부 os_ 로 시작합니다.
--
-- 설계 원칙 (앞의 세 앱과 같습니다)
--   1) 회사 격리는 앱이 아니라 데이터베이스가 강제합니다.
--   2) 지운 것은 표시만 합니다 (deleted).
--   3) 종이로 나간 숫자는 나중에 바뀌면 안 됩니다 — 견적서·발주서에
--      적힌 단가와 사양은 그때 그 값을 박아 둡니다.
--
-- 이 앱만의 원칙 둘
--   4) 금액은 딴 표에 둡니다. Re:Bind 가 project_money 로 나눠서 진짜로
--      막았고, Re:Store 는 아직 화면에서만 가려서 개발자 도구를 열면
--      보입니다(RESTORE.md 11장 구멍 1). 여기는 처음부터 나눠 둡니다.
--      제작기획사에서 원가와 이익은 직원에게도 안 보이는 것이 보통입니다.
--   5) 사양은 덮어쓰지 않고 판(version)을 쌓습니다. 제작 중에 사양이
--      바뀌는 것이 예외가 아니라 기본이고, "몇 판으로 발주했는가"를
--      나중에 못 대면 불량 책임을 가릴 수 없습니다.
-- ═══════════════════════════════════════════════════════════════

-- ───────────────── 고객사 ─────────────────
-- Re:Call 의 customers 와 이름이 비슷하지만 다른 것입니다. 저쪽은 사람
-- (명함 한 장 = 한 줄)이고, 여기는 발주를 주는 회사입니다. 담당자는
-- 한 회사에 여럿이라 contacts jsonb 에 담습니다 — 표를 하나 더 만들
-- 만큼 따로 검색하거나 이어 붙일 일이 없습니다.
create table if not exists public.os_customers (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  owner_id     uuid not null references public.profiles(id) on delete restrict,

  code         text not null default '',
  name         text not null default '',
  biz_no       text not null default '',   -- 숫자 열 자리만 담습니다
  biz_name     text not null default '',   -- 사업자 상호 (간판과 다른 곳이 많습니다)
  biz_ceo      text not null default '',
  biz_type     text not null default '',   -- 업태
  biz_item     text not null default '',   -- 종목
  phone        text not null default '',
  phone_digits text generated always as (regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g')) stored,
  email        text not null default '',
  addr         text not null default '',
  homepage     text not null default '',

  -- [{name,title,phone,email,memo}]
  contacts     jsonb not null default '[]'::jsonb,

  pay_term     text not null default '',   -- 결제조건 (자유 글. 회사마다 말이 다릅니다)
  status       text not null default 'active',
  memo         text not null default '',

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_customers_named  check (length(name) > 0),
  constraint os_customers_status check (status in ('active','pause','closed'))
);
create index if not exists os_customers_co_idx    on public.os_customers(company_id) where not deleted;
create index if not exists os_customers_name_idx  on public.os_customers(company_id, name) where not deleted;
create index if not exists os_customers_phone_idx on public.os_customers(company_id, phone_digits) where not deleted;

-- ───────────────── 외주업체 ─────────────────
-- caps 는 이 업체가 할 수 있는 일입니다. 표를 따로 두지 않고 글자 배열로
-- 둔 이유는, 공정 이름이 회사마다 다르고 계속 늘기 때문입니다. 미리 정해
-- 둔 목록에 맞추라고 하면 안 맞는 것이 생기고 그러면 아무도 안 채웁니다.
-- 배열이면 gin 색인으로 "무선제본 되는 곳" 을 바로 찾을 수 있습니다.
create table if not exists public.os_suppliers (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,

  code         text not null default '',
  name         text not null default '',
  biz_no       text not null default '',
  ceo          text not null default '',
  contact_name text not null default '',
  phone        text not null default '',
  phone_digits text generated always as (regexp_replace(coalesce(phone,''), '[^0-9]', '', 'g')) stored,
  email        text not null default '',
  addr         text not null default '',

  caps         text[] not null default '{}',  -- 가능한 제품·공정 예) {노트,무선제본,PUR,박}
  moq          integer,                       -- 최소 발주수량
  lead_days    integer,                       -- 평균 제작기간(일)
  pay_term     text not null default '',
  status       text not null default 'active',
  memo         text not null default '',

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_suppliers_named  check (length(name) > 0),
  constraint os_suppliers_status check (status in ('active','pause','closed'))
);
create index if not exists os_suppliers_co_idx   on public.os_suppliers(company_id) where not deleted;
create index if not exists os_suppliers_caps_idx on public.os_suppliers using gin (caps);

-- ───────────────── 프로젝트 ─────────────────
-- ⚠ 이 표에는 금액 칸이 하나도 없습니다. 직원도 읽는 표이기 때문입니다.
--   판매금액·원가·이익은 os_money 와 os_cost_items 에 있습니다.
create table if not exists public.os_projects (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  owner_id     uuid not null references public.profiles(id) on delete restrict,  -- 내부 담당자
  shared_ids   uuid[] not null default '{}',

  code         text not null default '',      -- PRJ-2026-0048
  name         text not null default '',
  customer_id  uuid references public.os_customers(id) on delete set null,
  contact_name text not null default '',      -- 고객 담당자 (그때 그 사람 이름을 박아 둡니다)

  category     text not null default '',      -- note · sketchbook · diary · package · stationery · goods · etc
  status       text not null default 'inquiry',
  priority     text not null default 'normal',

  started_on   date,
  due_on       date,                          -- 목표 납기
  delivered_on date,                          -- 실제 납품일
  qty_plan     integer,                       -- 예상 수량
  qty_final    integer,                       -- 최종 수량

  tags         text[] not null default '{}',
  memo         text not null default '',
  hold_reason  text not null default '',

  -- 고객사에게 진행현황만 보여 주는 링크. 원가와 외주업체는 안 나갑니다.
  share_token  text unique,
  share_on     boolean not null default false,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_projects_named  check (length(name) > 0),
  constraint os_projects_status check (status in (
    'inquiry','quotation','contract','planning','rfq','ordered','sample',
    'review','approved','production','qc','delivery','done','hold','canceled')),
  constraint os_projects_prio   check (priority in ('low','normal','high','urgent')),
  constraint os_projects_token  check (share_token is null or share_token ~ '^[a-f0-9]{32,64}$')
);
create index if not exists os_projects_co_idx     on public.os_projects(company_id) where not deleted;
create index if not exists os_projects_status_idx on public.os_projects(company_id, status) where not deleted;
create index if not exists os_projects_due_idx    on public.os_projects(company_id, due_on) where not deleted;
create index if not exists os_projects_cust_idx   on public.os_projects(company_id, customer_id) where not deleted;
create index if not exists os_projects_owner_idx  on public.os_projects(company_id, owner_id) where not deleted;
create index if not exists os_projects_token_idx  on public.os_projects(share_token) where share_on and not deleted;
create unique index if not exists os_projects_code_uniq
  on public.os_projects(company_id, code) where not deleted and code <> '';

-- ───────────────── 프로젝트 판매금액 (관리자만) ─────────────────
-- 프로젝트당 한 줄. 원가는 os_cost_items 에 항목별로 있고, 이익은
-- 두 값을 빼서 그때그때 셈합니다. 이익을 칸으로 두면 원가가 바뀔 때마다
-- 같이 고쳐야 하고, 한 번 빠뜨리면 손익 화면이 조용히 거짓말을 합니다.
create table if not exists public.os_money (
  project_id   uuid primary key references public.os_projects(id) on delete cascade,
  company_id   uuid not null references public.companies(id) on delete restrict,

  sales_amount numeric(14,2) not null default 0,   -- 고객에게 파는 금액 (공급가)
  vat_rate     numeric(5,2)  not null default 10,
  memo         text not null default '',

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ───────────────── 제품 사양 (판을 쌓습니다) ─────────────────
-- 칸을 미리 다 정해 두지 않았습니다. 노트·스케치북·패키지·문구류가
-- 필요로 하는 칸이 겹치지 않아서, 공통으로 쓰는 것만 칸으로 두고
-- 나머지는 extra 에 사용자가 이름부터 직접 적습니다.
-- (Re:Bind 의 options 와 같은 생각입니다)
create table if not exists public.os_specs (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid not null references public.os_projects(id) on delete cascade,

  ver          integer not null default 1,
  is_final     boolean not null default false,

  title        text not null default '',    -- 제품명
  ptype        text not null default '',    -- 제품 종류
  size_done    text not null default '',    -- 완제품 사이즈
  size_flat    text not null default '',    -- 펼친 사이즈
  qty          integer,
  colors       text not null default '',
  pages        integer,
  weight       text not null default '',

  material     text not null default '',    -- 재질
  paper_cover  text not null default '',    -- 표지 종이
  paper_inner  text not null default '',    -- 내지 종이
  gsm_cover    text not null default '',    -- 표지 평량
  gsm_inner    text not null default '',    -- 내지 평량
  printing     text not null default '',    -- 인쇄 방식
  print_colors text not null default '',    -- 인쇄 도수
  finishing    text not null default '',    -- 후가공
  binding      text not null default '',    -- 제본
  packing      text not null default '',    -- 포장 방식
  box_spec     text not null default '',
  label        text not null default '',
  barcode      text not null default '',
  req_note     text not null default '',    -- 기타 요구사항

  -- 제품 유형마다 다른 칸. [{k:'책등',v:'12mm'}, ...]
  extra        jsonb not null default '[]'::jsonb,

  note         text not null default '',    -- 이 판에서 무엇이 왜 바뀌었나
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false
);
create index if not exists os_specs_prj_idx on public.os_specs(project_id, ver) where not deleted;
create unique index if not exists os_specs_ver_uniq
  on public.os_specs(project_id, ver) where not deleted;

-- ───────────────── 고객 견적 ─────────────────
-- 금액이 통째로 딴 표(os_quote_money)에 있습니다. 견적서를 누가 만들었고
-- 언제 보냈고 따냈는지는 직원도 알아야 일이 되지만, 얼마에 팔았는지는
-- 다른 이야기입니다.
create table if not exists public.os_quotes (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid not null references public.os_projects(id) on delete cascade,

  no           text not null default '',     -- 견적번호
  ver          integer not null default 1,
  quoted_on    date,
  valid_until  date,                          -- 유효기간
  qty          integer,
  pay_term     text not null default '',
  due_text     text not null default '',      -- 납기 (자유 글. "발주 후 20일" 같은 것)
  memo         text not null default '',
  status       text not null default 'draft', -- draft 작성중 · sent 발송 · won 수주 · lost 실주

  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_quotes_status check (status in ('draft','sent','won','lost'))
);
create index if not exists os_quotes_prj_idx on public.os_quotes(project_id) where not deleted;

create table if not exists public.os_quote_money (
  quote_id     uuid primary key references public.os_quotes(id) on delete cascade,
  company_id   uuid not null references public.companies(id) on delete restrict,
  unit_price   numeric(14,2) not null default 0,
  supply       numeric(14,2) not null default 0,   -- 공급가
  vat          numeric(14,2) not null default 0,
  total        numeric(14,2) not null default 0,
  -- 부대비용 [{n:'금형비',v:300000}]
  extras       jsonb not null default '[]'::jsonb,
  updated_at   timestamptz not null default now()
);

-- ───────────────── 외주 견적 요청 ─────────────────
-- 한 프로젝트에 여러 업체가 붙습니다. 그래서 요청 한 줄 = 업체 하나입니다.
-- 회신 내용 중 **납기·MOQ·비고는 여기**, **금액은 os_rfq_money** 에 있습니다.
-- 비교 화면에서 값 비싸다고 무조건 지는 게 아니라 납기와 MOQ 를 함께 봐야
-- 하는데, 그 둘은 금액이 아니어서 직원도 봅니다.
create table if not exists public.os_rfqs (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid not null references public.os_projects(id) on delete cascade,
  supplier_id  uuid not null references public.os_suppliers(id) on delete restrict,

  spec_ver     integer,                       -- 몇 판 사양으로 물었나
  sent_on      date,
  reply_due    date,                          -- 회신 기한
  qty          integer,
  req_note     text not null default '',      -- 요청사항

  replied_on   date,
  lead_days    integer,                       -- 업체가 답한 제작기간
  moq          integer,
  pay_term     text not null default '',
  reply_note   text not null default '',

  status       text not null default 'draft', -- draft 요청전 · sent 요청완료 · replied 회신 · again 재문의 · won 확정 · lost 탈락
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_rfqs_status check (status in ('draft','sent','replied','again','won','lost'))
);
create index if not exists os_rfqs_prj_idx on public.os_rfqs(project_id) where not deleted;
create index if not exists os_rfqs_sup_idx on public.os_rfqs(company_id, supplier_id) where not deleted;

create table if not exists public.os_rfq_money (
  rfq_id       uuid primary key references public.os_rfqs(id) on delete cascade,
  company_id   uuid not null references public.companies(id) on delete restrict,
  unit_price   numeric(14,2) not null default 0,
  make_cost    numeric(14,2) not null default 0,   -- 제작비
  sample_cost  numeric(14,2) not null default 0,   -- 샘플비
  mold_cost    numeric(14,2) not null default 0,   -- 금형비
  ship_cost    numeric(14,2) not null default 0,   -- 운송비
  memo         text not null default '',
  updated_at   timestamptz not null default now()
);

-- ───────────────── 외주 발주 ─────────────────
-- 발주서를 만들면 원가(os_cost_items)에 외주제작비가 저절로 한 줄
-- 들어갑니다. 앱이 넣습니다 — 트리거로 하지 않은 이유는, 발주를 고칠 때
-- 원가 줄을 따라 고칠지 새로 만들지를 사람이 정해야 하기 때문입니다.
--
-- share_token · pin 은 외주업체 포털용입니다. 업체는 계정이 없습니다.
-- Re:Store 의 점주와 같은 방식이고, 같은 이유로 링크만으로는 못 들어옵니다 —
-- 여기도 업체가 납기와 진행을 **씁니다**.
create table if not exists public.os_pos (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid not null references public.os_projects(id) on delete cascade,
  supplier_id  uuid not null references public.os_suppliers(id) on delete restrict,
  rfq_id       uuid references public.os_rfqs(id) on delete set null,

  no           text not null default '',      -- 발주번호
  spec_ver     integer,                       -- 이 사양 판으로 발주했습니다
  ordered_on   date,
  due_on       date,                          -- 납기
  place        text not null default '',      -- 납품장소
  qty          integer,
  pay_term     text not null default '',
  req_note     text not null default '',      -- 작업요청사항

  status       text not null default 'draft', -- draft · sent 발송 · accepted 접수 · making 생산중 · done 완료 · canceled
  -- 업체가 자기 화면에서 적어 넣는 것
  sup_due_on   date,                          -- 업체가 답한 납기
  sup_note     text not null default '',
  sample_done_on date,
  make_done_on   date,

  share_token  text unique,
  share_on     boolean not null default false,
  pin          text not null default '',

  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_pos_status check (status in ('draft','sent','accepted','making','done','canceled')),
  constraint os_pos_token  check (share_token is null or share_token ~ '^[a-f0-9]{32,64}$'),
  constraint os_pos_pin    check (pin = '' or pin ~ '^[0-9]{4,8}$')
);
create index if not exists os_pos_prj_idx   on public.os_pos(project_id) where not deleted;
create index if not exists os_pos_sup_idx   on public.os_pos(company_id, supplier_id) where not deleted;
create index if not exists os_pos_token_idx on public.os_pos(share_token) where share_on and not deleted;

create table if not exists public.os_po_money (
  po_id        uuid primary key references public.os_pos(id) on delete cascade,
  company_id   uuid not null references public.companies(id) on delete restrict,
  unit_price   numeric(14,2) not null default 0,
  supply       numeric(14,2) not null default 0,
  vat          numeric(14,2) not null default 0,
  total        numeric(14,2) not null default 0,
  extras       jsonb not null default '[]'::jsonb,
  updated_at   timestamptz not null default now()
);

-- ───────────────── 샘플 ─────────────────
-- 제작기획사에서 샘플은 한 번으로 끝나지 않습니다. 목업 → 1차 → 컬러 →
-- 양산 전으로 이어지고, 어느 판 사양으로 만든 샘플인지가 승인의 근거가
-- 됩니다. 그래서 spec_ver 를 함께 담습니다.
create table if not exists public.os_samples (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid not null references public.os_projects(id) on delete cascade,
  supplier_id  uuid references public.os_suppliers(id) on delete set null,

  no           text not null default '',
  kind         text not null default 's1',    -- mockup 목업 · s1 1차 · s2 2차 · color 컬러 · print 인쇄 · pre 양산전 · final 최종
  spec_ver     integer,

  req_on       date,                          -- 요청일
  plan_on      date,                          -- 제작완료 예정일
  done_on      date,                          -- 실제 완료일
  sent_on      date,                          -- 발송일
  got_on       date,                          -- 수령일

  status       text not null default 'requested',
  fix_note     text not null default '',      -- 수정사항
  memo         text not null default '',
  photos       jsonb not null default '[]'::jsonb,   -- [{p:'경로',n:'설명',at:'…'}]

  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_samples_kind   check (kind in ('mockup','s1','s2','color','print','pre','final')),
  constraint os_samples_status check (status in ('requested','making','received','review','revise','approved'))
);
create index if not exists os_samples_prj_idx on public.os_samples(project_id) where not deleted;

-- ───────────────── 교정 ─────────────────
-- 샘플과 나눈 이유: 샘플은 물건이고 교정은 종이(디자인)입니다. 물건을 안
-- 만들고도 교정은 다섯 번씩 돕니다. 한 표에 담으면 "샘플 3차" 와
-- "교정 3차" 가 섞여 몇 번째인지 세지 못합니다.
create table if not exists public.os_proofs (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid not null references public.os_projects(id) on delete cascade,

  no           integer not null default 1,
  asked_on     date,
  feedback     text not null default '',      -- 고객 피드백
  fixed_note   text not null default '',      -- 수정내용
  status       text not null default 'open',  -- open 진행 · fixed 수정완료 · approved 승인
  by_name      text not null default '',      -- 요청자
  approved_by  text not null default '',
  approved_on  date,

  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_proofs_status check (status in ('open','fixed','approved'))
);
create index if not exists os_proofs_prj_idx on public.os_proofs(project_id) where not deleted;

-- ───────────────── 고객 승인 ─────────────────
-- 지금은 안에서 기록만 합니다. 나중에 고객에게 링크를 보내 웹에서 누르게
-- 하려고 token 과 접속 기록 칸을 미리 뒀습니다 — 승인은 나중에 "그런 적
-- 없다" 가 나오는 자리라, 누가 언제 어느 판을 보고 눌렀는지가 남아야 합니다.
create table if not exists public.os_approvals (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid not null references public.os_projects(id) on delete cascade,
  sample_id    uuid references public.os_samples(id) on delete set null,

  spec_ver     integer,
  asked_on     date,
  status       text not null default 'waiting',  -- waiting 대기 · revise 수정요청 · approved 승인
  decided_on   timestamptz,
  by_name      text not null default '',
  by_ip        text not null default '',
  note         text not null default '',

  token        text unique,
  token_on     boolean not null default false,

  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_approvals_status check (status in ('waiting','revise','approved')),
  constraint os_approvals_token  check (token is null or token ~ '^[a-f0-9]{32,64}$')
);
create index if not exists os_approvals_prj_idx   on public.os_approvals(project_id) where not deleted;
create index if not exists os_approvals_token_idx on public.os_approvals(token) where token_on and not deleted;

-- ───────────────── 원가 항목 (관리자만) ─────────────────
-- 한 항목에 금액이 셋인 이유
--   est  예상 — 견적을 낼 때 잡은 값
--   fix  확정 — 업체와 값을 맞춘 값
--   act  실제 — 세금계산서까지 끝난 값
-- 셋을 한 칸에 덮어쓰면 "견적 대비 얼마나 틀어졌나" 를 영영 못 셉니다.
-- 그게 제작기획사가 가장 알고 싶어 하는 숫자입니다.
create table if not exists public.os_cost_items (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid not null references public.os_projects(id) on delete cascade,
  supplier_id  uuid references public.os_suppliers(id) on delete set null,
  po_id        uuid references public.os_pos(id) on delete set null,   -- 발주서에서 저절로 들어온 줄

  category     text not null default 'etc',
  title        text not null default '',
  qty          numeric(14,2),
  unit_price   numeric(14,2),
  est_amount   numeric(14,2) not null default 0,
  fix_amount   numeric(14,2) not null default 0,
  act_amount   numeric(14,2) not null default 0,
  memo         text not null default '',
  sort         integer not null default 0,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_cost_cat check (category in (
    'outsource','paper','print','finish','bind','pack','mold',
    'sample','ship','store','qc','labor','etc'))
);
create index if not exists os_cost_prj_idx on public.os_cost_items(project_id) where not deleted;

-- ───────────────── 파일 ─────────────────
-- 덮어쓰지 않습니다. 같은 이름으로 또 올리면 판이 하나 올라갑니다.
-- 실무에서 design_final_final_2.pdf 가 생기는 이유는 덮어쓰기가 무서워서인데,
-- 앱이 판을 세 주면 그 이름을 지을 일이 없습니다.
create table if not exists public.os_files (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid not null references public.os_projects(id) on delete cascade,

  folder       text not null default '09_DOCUMENT',
  name         text not null default '',      -- 사람이 보는 이름 (같아도 됩니다)
  path         text not null default '',      -- 보관함 실제 경로. uuid 로 짓습니다
  ver          integer not null default 1,
  size         bigint,
  mime         text not null default '',
  kind         text not null default 'etc',   -- design·spec·quote·po·sample·qc·etc
  note         text not null default '',
  is_final     boolean not null default false,

  uploaded_by  uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_files_folder check (folder in (
    '01_SPEC','02_DESIGN','03_QUOTATION','04_SAMPLE','05_APPROVAL',
    '06_PRODUCTION','07_QC','08_DELIVERY','09_DOCUMENT'))
);
create index if not exists os_files_prj_idx on public.os_files(project_id) where not deleted;

-- ───────────────── 할 일 ─────────────────
create table if not exists public.os_tasks (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid references public.os_projects(id) on delete cascade,
  supplier_id  uuid references public.os_suppliers(id) on delete set null,

  title        text not null default '',
  assignee_id  uuid references public.profiles(id) on delete set null,
  due_on       date,
  priority     text not null default 'normal',
  done         boolean not null default false,
  done_at      timestamptz,
  memo         text not null default '',

  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_tasks_named check (length(title) > 0),
  constraint os_tasks_prio  check (priority in ('low','normal','high','urgent'))
);
create index if not exists os_tasks_co_idx  on public.os_tasks(company_id, done, due_on) where not deleted;
create index if not exists os_tasks_prj_idx on public.os_tasks(project_id) where not deleted;

-- ───────────────── 활동 기록 ─────────────────
-- 사람이 따로 적지 않아도 쌓입니다. 앱이 주요 동작마다 한 줄 넣습니다.
-- by_name 을 따로 담는 이유는, 사람이 회사를 떠나 profiles 에서 사라져도
-- "그때 누가 했는지" 는 남아야 하기 때문입니다.
create table if not exists public.os_activity (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  project_id   uuid references public.os_projects(id) on delete cascade,

  kind         text not null default 'note',  -- status·spec·quote·rfq·po·sample·proof·approval·file·task·cost·comment·note
  body         text not null default '',
  meta         jsonb not null default '{}'::jsonb,
  mentions     uuid[] not null default '{}',

  by_id        uuid references public.profiles(id) on delete set null,
  by_name      text not null default '',
  at           timestamptz not null default now()
);
create index if not exists os_activity_prj_idx on public.os_activity(project_id, at desc);
create index if not exists os_activity_co_idx  on public.os_activity(company_id, at desc);

-- ───────────────── 외주업체 평가 ─────────────────
-- 프로젝트가 끝날 때 한 번 매깁니다. 업체당 여러 줄이 쌓이고 평균이
-- 그 업체의 점수가 됩니다. 업체 표에 점수 한 칸만 두면 누가 언제 왜
-- 그렇게 매겼는지가 사라져서, 나쁜 점수를 아무도 못 고칩니다.
create table if not exists public.os_supplier_evals (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  supplier_id  uuid not null references public.os_suppliers(id) on delete cascade,
  project_id   uuid references public.os_projects(id) on delete set null,

  price        smallint,   -- 1~5
  quality      smallint,
  ontime       smallint,
  comm         smallint,   -- 커뮤니케이션
  response     smallint,   -- 대응속도
  defect_rate  numeric(6,3),
  rework       boolean not null default false,
  claim        boolean not null default false,
  memo         text not null default '',

  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  deleted      boolean not null default false,

  constraint os_eval_range check (
    coalesce(price,3) between 1 and 5 and coalesce(quality,3) between 1 and 5 and
    coalesce(ontime,3) between 1 and 5 and coalesce(comm,3) between 1 and 5 and
    coalesce(response,3) between 1 and 5)
);
create index if not exists os_eval_sup_idx on public.os_supplier_evals(company_id, supplier_id) where not deleted;

-- ───────────────── 제품 템플릿 ─────────────────
-- 같은 것을 해마다 다시 만듭니다. 사양을 통째로 담아 두고 새 프로젝트에
-- 부어 넣습니다.
create table if not exists public.os_templates (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete restrict,
  name         text not null default '',
  category     text not null default '',
  spec         jsonb not null default '{}'::jsonb,   -- os_specs 의 칸들을 그대로
  memo         text not null default '',
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted      boolean not null default false,
  constraint os_templates_named check (length(name) > 0)
);
create index if not exists os_templates_co_idx on public.os_templates(company_id) where not deleted;

-- ───────────────── 수정시각 자동 갱신 ─────────────────
do $$
declare t text;
begin
  foreach t in array array[
    'os_customers','os_suppliers','os_projects','os_money','os_specs',
    'os_quotes','os_quote_money','os_rfqs','os_rfq_money','os_pos','os_po_money',
    'os_samples','os_proofs','os_approvals','os_cost_items','os_tasks','os_templates'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t||'_touch', t);
    execute format('create trigger %I before update on public.%I
                    for each row execute function public.touch_updated_at()', t||'_touch', t);
  end loop;
end $$;

-- ═══════════════════════════════════════════════════════════════
-- 자물쇠
--
-- 바깥문(grant)과 안쪽문(RLS)이 따로입니다. Re:Store 가 0001 에서
-- grant 를 빠뜨려 표는 있는데 아무도 못 읽었습니다. 여기서는 아래
-- "권한" 칸에서 한꺼번에 줍니다.
-- ═══════════════════════════════════════════════════════════════

-- 금액을 볼 수 있는가.
--   관리자는 늘 봅니다. 직원은 회사가 열어 준 경우에만(company_settings.staff_money)
--   봅니다 — Re:Bind 가 쓰는 그 칸을 그대로 씁니다. 회사 하나가 두 서비스를
--   쓰는데 "Re:Bind 금액은 열고 Re:O-S 금액은 닫는" 경우를 아직 못 봤고,
--   칸을 따로 만들면 설정 화면이 둘로 늘어납니다.
--
-- ⚠ 열어 주어도 **고치는 것은 관리자만** 입니다. 아래 정책에서 읽기는
--   os_money_ok(), 쓰기는 is_admin() 을 씁니다.
create or replace function public.os_money_ok()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin()
      or coalesce((select cs.staff_money
                     from public.company_settings cs
                    where cs.company_id = public.current_company_id()), false)
$$;
grant execute on function public.os_money_ok() to authenticated;

-- ───────────────── 직원도 보는 표 ─────────────────
-- 열여섯 개에 똑같은 규칙을 손으로 적으면 한 군데를 빠뜨립니다.
-- 실제로 형제 앱에서 그렇게 표 하나가 열린 적이 있어, 여기서는 돌립니다.
do $$
declare t text;
begin
  foreach t in array array[
    'os_customers','os_suppliers','os_specs','os_quotes','os_rfqs','os_pos',
    'os_samples','os_proofs','os_approvals','os_files','os_tasks',
    'os_activity','os_supplier_evals','os_templates'
  ] loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I on public.%I', t||'_read', t);
    execute format($p$create policy %I on public.%I for select to authenticated
                      using (company_id = public.company_for_app('reos'))$p$, t||'_read', t);

    execute format('drop policy if exists %I on public.%I', t||'_insert', t);
    execute format($p$create policy %I on public.%I for insert to authenticated
                      with check (company_id = public.company_for_app('reos'))$p$, t||'_insert', t);

    execute format('drop policy if exists %I on public.%I', t||'_update', t);
    execute format($p$create policy %I on public.%I for update to authenticated
                      using (company_id = public.company_for_app('reos'))
                      with check (company_id = public.company_for_app('reos'))$p$, t||'_update', t);

    -- 진짜로 지우는 것은 관리자만. 직원은 deleted 를 세우는 것(update)까지입니다.
    execute format('drop policy if exists %I on public.%I', t||'_delete', t);
    execute format($p$create policy %I on public.%I for delete to authenticated
                      using (company_id = public.company_for_app('reos') and public.is_admin())$p$, t||'_delete', t);
  end loop;
end $$;

-- ───────────────── 프로젝트 ─────────────────
-- 담당자를 못 박습니다. 다른 회사 사람을 담당자로 앉히지 못하게.
alter table public.os_projects enable row level security;

drop policy if exists os_projects_read on public.os_projects;
create policy os_projects_read on public.os_projects for select to authenticated
  using (company_id = public.company_for_app('reos'));

drop policy if exists os_projects_insert on public.os_projects;
create policy os_projects_insert on public.os_projects for insert to authenticated
  with check (company_id = public.company_for_app('reos')
              and exists (select 1 from public.profiles p
                           where p.id = os_projects.owner_id
                             and p.company_id = public.current_company_id()));

drop policy if exists os_projects_update on public.os_projects;
create policy os_projects_update on public.os_projects for update to authenticated
  using (company_id = public.company_for_app('reos'))
  with check (company_id = public.company_for_app('reos')
              and exists (select 1 from public.profiles p
                           where p.id = os_projects.owner_id
                             and p.company_id = public.current_company_id()));

drop policy if exists os_projects_delete on public.os_projects;
create policy os_projects_delete on public.os_projects for delete to authenticated
  using (company_id = public.company_for_app('reos') and public.is_admin());

-- ───────────────── 금액이 든 표 다섯 ─────────────────
-- 읽기는 os_money_ok(), 쓰기는 is_admin(). 화면에서 가리는 것이 아니라
-- 서버가 아예 안 내려 줍니다 — 개발자 도구를 열어도 없습니다.
do $$
declare t text;
begin
  foreach t in array array['os_money','os_quote_money','os_rfq_money','os_po_money','os_cost_items'] loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I on public.%I', t||'_read', t);
    execute format($p$create policy %I on public.%I for select to authenticated
                      using (company_id = public.company_for_app('reos') and public.os_money_ok())$p$, t||'_read', t);

    execute format('drop policy if exists %I on public.%I', t||'_insert', t);
    execute format($p$create policy %I on public.%I for insert to authenticated
                      with check (company_id = public.company_for_app('reos') and public.is_admin())$p$, t||'_insert', t);

    execute format('drop policy if exists %I on public.%I', t||'_update', t);
    execute format($p$create policy %I on public.%I for update to authenticated
                      using (company_id = public.company_for_app('reos') and public.is_admin())
                      with check (company_id = public.company_for_app('reos') and public.is_admin())$p$, t||'_update', t);

    execute format('drop policy if exists %I on public.%I', t||'_delete', t);
    execute format($p$create policy %I on public.%I for delete to authenticated
                      using (company_id = public.company_for_app('reos') and public.is_admin())$p$, t||'_delete', t);
  end loop;
end $$;

-- ───────────────── 권한 (바깥문) ─────────────────
do $$
declare t text;
begin
  foreach t in array array[
    'os_customers','os_suppliers','os_projects','os_money','os_specs',
    'os_quotes','os_quote_money','os_rfqs','os_rfq_money','os_pos','os_po_money',
    'os_samples','os_proofs','os_approvals','os_cost_items','os_files','os_tasks',
    'os_activity','os_supplier_evals','os_templates'
  ] loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    -- 서버 함수(외주업체 포털·고객 공유)는 RLS 를 지나지 않습니다.
    -- 무엇을 내보낼지는 그 함수 코드가 스스로 가립니다.
    execute format('grant all privileges on public.%I to service_role', t);
  end loop;
end $$;

-- ───────────────── 보관함 ─────────────────
-- 경로가 곧 권한입니다 — {회사id}/{프로젝트id}/{파일id}.확장자
-- 첫 칸이 자기 회사 id 가 아니면 서명조차 못 받습니다.
insert into storage.buckets (id, name, public)
     values ('osfiles','osfiles', false)
on conflict (id) do nothing;

drop policy if exists osfiles_read   on storage.objects;
create policy osfiles_read on storage.objects for select to authenticated
  using (bucket_id = 'osfiles'
         and (storage.foldername(name))[1] = (public.company_for_app('reos'))::text);

drop policy if exists osfiles_insert on storage.objects;
create policy osfiles_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'osfiles'
              and (storage.foldername(name))[1] = (public.company_for_app('reos'))::text);

drop policy if exists osfiles_update on storage.objects;
create policy osfiles_update on storage.objects for update to authenticated
  using (bucket_id = 'osfiles'
         and (storage.foldername(name))[1] = (public.company_for_app('reos'))::text);

drop policy if exists osfiles_delete on storage.objects;
create policy osfiles_delete on storage.objects for delete to authenticated
  using (bucket_id = 'osfiles'
         and (storage.foldername(name))[1] = (public.company_for_app('reos'))::text);

-- ───────────────── 회사 설정에 Re:O-S 칸 ─────────────────
-- 제품 카테고리·후가공 목록·제품유형별 커스텀 필드처럼 회사마다 다른
-- 목록들입니다. 표를 따로 만들지 않은 이유는 Re:Bind 의 preset 과 같습니다 —
-- 목록을 담을 뿐 이어 붙이거나 검색할 일이 없습니다.
alter table public.company_settings
  add column if not exists reos jsonb not null default '{}'::jsonb;

comment on column public.company_settings.reos is
  'Re:O-S 가 쓰는 회사별 목록 { categories, finishings, materials, fields }';

-- ═══════════════════════════════════════════════════════════════
-- 확인 — 표마다 바깥문(grant)과 안쪽문(RLS)이 다 있는지
-- 넷(select/insert/update/delete)이 안 차 있으면 그 표는 반쯤 열린 것입니다.
-- ═══════════════════════════════════════════════════════════════
select c.relname                                   as "표",
       c.relrowsecurity                            as "RLS 켜짐",
       (select count(*) from pg_policies pp
         where pp.schemaname='public' and pp.tablename=c.relname) as "정책 수",
       (select count(distinct g.privilege_type)
          from information_schema.role_table_grants g
         where g.table_schema='public' and g.table_name=c.relname
           and g.grantee='authenticated')          as "직원 권한"
  from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname like 'os\_%' and c.relkind='r'
 order by c.relname;
