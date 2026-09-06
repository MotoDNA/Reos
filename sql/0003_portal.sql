-- ═══════════════════════════════════════════════════════════════
-- 바깥에서 들어오는 두 화면 — 고객사와 외주업체
--
-- 둘 다 계정이 없습니다. 링크(32자)로 들어오고, 외주업체는 핀까지 맞아야
-- 합니다. 고객사는 보기만 하니 링크로 충분하고, 외주업체는 납기와 진행을
-- **쓰기** 때문에 한 겹 더 둡니다. Re:Store 의 점주와 같은 판단입니다.
--
-- ⚠ 틀린 횟수를 서버 함수 안의 Map 으로 세면 안 됩니다.
--   Edge Function 은 잠깐 쉬면 내려갔다 새로 뜨고, 그때 센 것이 0 으로
--   돌아갑니다. 여러 대가 동시에 돌면 각자 따로 셉니다. Re:Store 가
--   그렇게 만들었다가 "10번 틀리면 잠김" 이 실제로는 잘 안 걸렸습니다.
--   그래서 표에 셉니다.
-- ═══════════════════════════════════════════════════════════════
create table if not exists public.os_pin_tries (
  token      text primary key,
  tries      integer not null default 0,
  locked_to  timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.os_pin_tries enable row level security;
-- 정책을 하나도 두지 않는 것은 **의도한 것**입니다.
-- RLS 가 켜져 있고 정책이 없으면 브라우저에서는 한 줄도 못 봅니다.
-- 문지기(서버 함수)만 service_role 로 씁니다.
grant all privileges on public.os_pin_tries to service_role;

-- 문지기가 볼 표들. RLS 를 지나지 않으므로 무엇을 내보낼지는
-- 함수 코드가 스스로 가립니다.
grant select on public.os_projects, public.os_specs, public.os_samples,
                 public.os_pos, public.os_po_money, public.os_suppliers,
                 public.os_approvals, public.os_files, public.companies
  to service_role;
grant update on public.os_pos to service_role;
grant insert on public.os_activity to service_role;

select 'os_pin_tries 준비됨' as 결과;
