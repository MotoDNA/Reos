-- ═══════════════════════════════════════════════════════════════
-- ACTIVA 에 Re:O-S 를 열어 줍니다
--
-- apps 가 비어 있으면 아무 데도 못 들어갑니다. 반대로 여기에 넣지 않으면
-- 표를 다 만들어 놓고도 화면이 통째로 빈 채로 뜹니다 —
-- company_for_app('reos') 가 null 을 돌려주기 때문입니다.
--
-- ⚠ 기존 것을 덮어쓰지 않습니다. ACTIVA 는 이미 rebind·recall 을 쓰고
--   있고, apps = '{reos}' 로 적으면 그 둘이 그 자리에서 막힙니다.
--   더하는 방식(array_append)으로만 씁니다.
-- ═══════════════════════════════════════════════════════════════
update public.companies
   set apps = array_append(apps, 'reos')
 where code = 'ACTIVA'
   and not ('reos' = any(apps));

-- 회사 설정 줄이 없으면 만들어 둡니다. 없으면 os_money_ok() 가
-- staff_money 를 못 찾아 늘 false 가 되는데, 관리자는 is_admin() 으로
-- 통과하므로 아무도 못 알아챕니다. 직원 계정을 만들고 나서야 드러납니다.
insert into public.company_settings (company_id)
select c.id from public.companies c
 where c.code = 'ACTIVA'
on conflict (company_id) do nothing;

select code, name, apps from public.companies order by code;
