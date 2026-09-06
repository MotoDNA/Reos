-- ═══════════════════════════════════════════════════════════════
-- 시연 자료 — ACTIVA
--
-- 빈 화면으로는 이 앱이 무엇을 하는지 보여 줄 수가 없습니다.
-- 실제 제작기획사가 겪는 모양(사양이 두 판, 업체 두 곳 견적 비교,
-- 샘플 두 번, 원가가 견적보다 늘어남)을 그대로 넣습니다.
--
-- ⚠ id 앞자리를 d4000000 으로 맞췄습니다. Re:Bind 가 b2000000 / c3000000 을
--   쓴 것과 같은 이유입니다 — 나중에 한 줄로 지울 수 있어야 합니다.
--
--   delete from public.os_projects  where id::text like 'd4000000-%';
--   delete from public.os_customers where id::text like 'd4000000-%';
--   delete from public.os_suppliers where id::text like 'd4000000-%';
--   (사양·견적·발주·샘플·원가는 프로젝트에 매달려 있어 같이 지워집니다)
--
-- 여러 번 돌려도 안전합니다.
-- ═══════════════════════════════════════════════════════════════
do $$
declare
  co   uuid := '24bca358-fbde-4048-b24d-0070182048a7';  -- ACTIVA
  boss uuid := '9128cb6f-a3c2-44c0-9077-b4f6abb465b2';  -- admin  (관리자)
  hand uuid := '0d98bbac-747b-438f-8ef9-763f6dabc283';  -- tester1(Test)
  d    date := current_date;
  c1   uuid := 'd4000000-0000-0000-0000-000000000001';  -- 고객사 A
  c2   uuid := 'd4000000-0000-0000-0000-000000000002';  -- 고객사 B
  s1   uuid := 'd4000000-0000-0000-0000-000000000011';  -- 제본 업체
  s2   uuid := 'd4000000-0000-0000-0000-000000000012';  -- 패키지 업체
  s3   uuid := 'd4000000-0000-0000-0000-000000000013';  -- 인쇄 업체
  p1   uuid := 'd4000000-0000-0000-0000-000000000101';  -- 생산 중
  p2   uuid := 'd4000000-0000-0000-0000-000000000102';  -- 고객 검토
  p3   uuid := 'd4000000-0000-0000-0000-000000000103';  -- 외주 견적 (지연)
  p4   uuid := 'd4000000-0000-0000-0000-000000000104';  -- 문의
  p5   uuid := 'd4000000-0000-0000-0000-000000000105';  -- 종료
  r1   uuid := 'd4000000-0000-0000-0000-000000000201';
  r2   uuid := 'd4000000-0000-0000-0000-000000000202';
  o1   uuid := 'd4000000-0000-0000-0000-000000000301';
  q1   uuid := 'd4000000-0000-0000-0000-000000000401';
begin

-- ───────── 고객사 ─────────
insert into public.os_customers (id,company_id,owner_id,code,name,biz_no,biz_name,biz_ceo,
       biz_type,biz_item,phone,email,addr,pay_term,contacts,memo) values
 (c1,co,boss,'C-001','한빛문구','1178145200','주식회사 한빛문구','김한빛','도소매','문구',
  '02-555-1234','order@hanbit.example','서울 중구 을지로 100','익월 말 현금',
  '[{"name":"김담당","title":"구매팀 과장","phone":"010-1111-2222","email":"buy@hanbit.example","memo":""}]'::jsonb,
  '해마다 다이어리를 리오더합니다. 수량이 조금씩 늡니다.'),
 (c2,co,boss,'C-002','오브제코스메틱','2208147800','(주)오브제','이오브','제조','화장품',
  '031-777-8899','','경기 성남시 분당구 판교로 20','계약금 30% / 잔금 70%',
  '[{"name":"박담당","title":"마케팅팀","phone":"010-3333-4444","email":"","memo":"연락은 카톡이 빠릅니다"}]'::jsonb,
  '')
on conflict (id) do nothing;

-- ───────── 외주업체 ─────────
insert into public.os_suppliers (id,company_id,code,name,biz_no,ceo,contact_name,phone,email,addr,
       caps,moq,lead_days,pay_term,memo) values
 (s1,co,'S-001','대성제본','1358101234','박대성','박대성','031-111-2222','','경기 파주시 문발로 30',
  '{노트,다이어리,양장,무선제본,PUR,박,형압}',1000,20,'50/50','양장 품질이 좋습니다. 박은 외주로 돌립니다.'),
 (s2,co,'S-002','한울패키지','1298112233','최한울','정과장','031-333-4444','','경기 김포시 양촌읍',
  '{패키지,싸바리,단상자,쇼핑백,후가공}',500,18,'100% 후불','소량도 받아 줍니다.'),
 (s3,co,'S-003','우진인쇄','1068155566','오우진','오우진','02-888-9999','','서울 중구 충무로 5',
  '{옵셋,UV,형압,라미네이팅,합지}',2000,25,'30/70','')
on conflict (id) do nothing;

-- ───────── 프로젝트 ─────────
insert into public.os_projects (id,company_id,owner_id,code,name,customer_id,contact_name,category,
       status,priority,started_on,due_on,delivered_on,qty_plan,qty_final,tags,memo) values
 (p1,co,boss,'PRJ-2026-0048','2026 한빛문구 양장 다이어리',c1,'김담당','diary',
  'production','high',d-40,d+2,null,10000,null,'{리오더}','작년 대비 수량 50% 늘었습니다. 박 위치가 바뀌었습니다.'),
 (p2,co,hand,'PRJ-2026-0049','오브제 신제품 싸바리 패키지',c2,'박담당','package',
  'review','normal',d-20,d+12,null,5000,null,'{}',''),
 (p3,co,boss,'PRJ-2026-0050','한빛문구 A5 무선노트 3종',c1,'김담당','note',
  'rfq','urgent',d-6,d-3,null,20000,null,'{}','납기가 이미 지났습니다. 업체 회신이 늦습니다.'),
 (p4,co,boss,'PRJ-2026-0051','오브제 굿즈 키링 세트',c2,'박담당','goods',
  'inquiry','low',d-2,d+45,null,3000,null,'{}',''),
 (p5,co,boss,'PRJ-2026-0044','2025 한빛문구 다이어리',c1,'김담당','diary',
  'done','normal',d-200,d-120,d-118,12000,12000,'{}','')
on conflict (id) do nothing;

-- ───────── 판매금액 (관리자만 보는 표) ─────────
insert into public.os_money (project_id,company_id,sales_amount) values
 (p1,co,98000000),(p2,co,22000000),(p5,co,84000000)
on conflict (project_id) do nothing;

-- ───────── 사양 — 판이 둘입니다 ─────────
insert into public.os_specs (id,company_id,project_id,ver,is_final,title,ptype,size_done,qty,pages,
       paper_cover,gsm_cover,paper_inner,gsm_inner,printing,print_colors,finishing,binding,packing,
       extra,note,created_by) values
 ('d4000000-0000-0000-0000-000000000501',co,p1,1,false,'2026 한빛 양장 다이어리','다이어리',
  '150 × 210mm',10000,224,'스노우지','300gsm','미색모조','80gsm','옵셋','4/1',
  '무광 라미네이팅','양장','개별 OPP','[]'::jsonb,'',boss),
 ('d4000000-0000-0000-0000-000000000502',co,p1,2,true,'2026 한빛 양장 다이어리','다이어리',
  '150 × 210mm',10000,240,'스노우지','300gsm','미색모조','100gsm','옵셋','4/1',
  '무광 라미네이팅, 박','양장','개별 OPP',
  '[{"k":"책등","v":"18mm"},{"k":"밴드","v":"있음"},{"k":"책갈피","v":"리본 2개"}]'::jsonb,
  '내지 80→100gsm, 페이지 224→240. 고객이 두께를 키워 달라고 했습니다.',boss),
 ('d4000000-0000-0000-0000-000000000503',co,p2,1,true,'오브제 싸바리 패키지','패키지',
  '180 × 180 × 60mm',5000,null,'','','','','옵셋','4/0','유광 라미네이팅','','싸바리',
  '[{"k":"내장재","v":"EVA 흑색"},{"k":"자석","v":"양쪽 2개"}]'::jsonb,'',hand)
on conflict (id) do nothing;

-- ───────── 고객 견적 (수주 확정) ─────────
insert into public.os_quotes (id,company_id,project_id,no,ver,quoted_on,valid_until,qty,
       pay_term,due_text,status,created_by) values
 (q1,co,p1,'Q-2026-001',1,d-35,d-5,10000,'계약금 50% / 잔금 50%','발주 후 30일','won',boss)
on conflict (id) do nothing;
insert into public.os_quote_money (quote_id,company_id,unit_price,supply,vat,total) values
 (q1,co,9800,98000000,9800000,107800000)
on conflict (quote_id) do nothing;

-- ───────── 외주 견적 두 곳 — 비교 화면이 보이도록 ─────────
insert into public.os_rfqs (id,company_id,project_id,supplier_id,spec_ver,sent_on,reply_due,qty,
       replied_on,lead_days,moq,pay_term,status,req_note,created_by) values
 (r1,co,p1,s1,2,d-30,d-27,10000,d-28,20,1000,'50/50','won',
  '박 위치 도면 첨부. 밴드 색상 확인 부탁드립니다.',boss),
 (r2,co,p1,s3,2,d-30,d-27,10000,d-27,25,2000,'30/70','lost','',boss)
on conflict (id) do nothing;
insert into public.os_rfq_money (rfq_id,company_id,unit_price,make_cost,sample_cost,mold_cost,ship_cost) values
 (r1,co,6500,65000000,150000,0,0),
 (r2,co,6900,69000000,100000,0,0)
on conflict (rfq_id) do nothing;

-- 회신이 늦은 곳 하나 — 위험도 화면이 실제로 뜨도록
insert into public.os_rfqs (id,company_id,project_id,supplier_id,sent_on,reply_due,qty,status,created_by) values
 ('d4000000-0000-0000-0000-000000000203',co,p3,s1,d-5,d-2,20000,'sent',boss)
on conflict (id) do nothing;

-- ───────── 발주 ─────────
insert into public.os_pos (id,company_id,project_id,supplier_id,rfq_id,no,spec_ver,ordered_on,due_on,
       place,qty,pay_term,status,req_note,sup_due_on,sample_done_on,created_by) values
 (o1,co,p1,s1,r1,'PO-2026-001',2,d-25,d-1,'경기 파주 물류창고',10000,'50/50','making',
  '박 위치는 도면대로. 모서리 찍힘 주의. 검수는 전수 아니고 AQL 2.5 로 합니다.',d+1,d-12,boss)
on conflict (id) do nothing;
insert into public.os_po_money (po_id,company_id,unit_price,supply,vat,total) values
 (o1,co,6500,65000000,6500000,71500000)
on conflict (po_id) do nothing;

-- ───────── 원가 — 예상보다 늘어난 모양 ─────────
insert into public.os_cost_items (id,company_id,project_id,supplier_id,po_id,category,title,
       qty,unit_price,est_amount,fix_amount,act_amount,memo,sort) values
 ('d4000000-0000-0000-0000-000000000601',co,p1,s1,o1,'outsource','대성제본 외주 제작비',
  10000,6500,62000000,65000000,0,'발주서 PO-2026-001 에서 저절로 들어왔습니다',0),
 ('d4000000-0000-0000-0000-000000000602',co,p1,null,null,'ship','파주→서울 운송비',
  null,null,2000000,0,2400000,'차량 두 번 나눠 실었습니다',1),
 ('d4000000-0000-0000-0000-000000000603',co,p1,null,null,'pack','개별 OPP 포장',
  10000,120,1200000,1200000,0,'',2),
 ('d4000000-0000-0000-0000-000000000604',co,p2,s2,null,'outsource','한울패키지 외주 제작비',
  5000,2800,14000000,14000000,0,'',0),
 ('d4000000-0000-0000-0000-000000000605',co,p5,null,null,'outsource','2025년 외주 제작비',
  12000,4667,56000000,0,59000000,'실제로 300만원 더 들었습니다',0)
on conflict (id) do nothing;

-- ───────── 샘플 — 한 번 수정, 두 번째 승인 ─────────
insert into public.os_samples (id,company_id,project_id,supplier_id,no,kind,spec_ver,
       req_on,plan_on,done_on,sent_on,got_on,status,fix_note,created_by) values
 ('d4000000-0000-0000-0000-000000000701',co,p1,s1,'S01','s1',1,d-26,d-18,d-17,d-17,d-16,
  'revise','표지 색상이 어둡습니다. 박 위치 3mm 위로. 밴드 장력이 약합니다.',boss),
 ('d4000000-0000-0000-0000-000000000702',co,p1,s1,'S02','s2',2,d-15,d-12,d-12,d-12,d-11,
  'approved','',boss),
 ('d4000000-0000-0000-0000-000000000703',co,p2,s2,'S01','mockup',1,d-14,d-8,d-8,null,d-7,
  'review','',hand)
on conflict (id) do nothing;

-- ───────── 교정 ─────────
insert into public.os_proofs (id,company_id,project_id,no,asked_on,feedback,fixed_note,status,
       by_name,approved_by,approved_on,created_by) values
 ('d4000000-0000-0000-0000-000000000801',co,p1,1,d-24,
  '표지 색상 어두움 / 로고 3mm 위로 / 내지 월간 페이지 요일 시작을 월요일로',
  '세 가지 모두 반영했습니다.','approved','김담당','김담당',d-20,boss)
on conflict (id) do nothing;

-- ───────── 고객 승인 ─────────
insert into public.os_approvals (id,company_id,project_id,sample_id,spec_ver,asked_on,status,
       decided_on,by_name,note,created_by) values
 ('d4000000-0000-0000-0000-000000000901',co,p1,'d4000000-0000-0000-0000-000000000702',2,d-11,
  'approved',(d-10)::timestamptz,'김담당','2차 샘플로 확정. 양산 진행해 주세요.',boss),
 ('d4000000-0000-0000-0000-000000000902',co,p2,'d4000000-0000-0000-0000-000000000703',1,d-6,
  'waiting',null,'박담당','',hand)
on conflict (id) do nothing;

-- ───────── 할 일 ─────────
insert into public.os_tasks (id,company_id,project_id,supplier_id,title,assignee_id,due_on,
       priority,done,created_by) values
 ('d4000000-0000-0000-0000-000000000a01',co,p1,s1,'대성제본 생산 진행 확인',boss,d,'high',false,boss),
 ('d4000000-0000-0000-0000-000000000a02',co,p3,s1,'대성제본 견적 회신 독촉',boss,d-2,'urgent',false,boss),
 ('d4000000-0000-0000-0000-000000000a03',co,p2,null,'오브제 승인 요청 다시 메일',hand,d+1,'normal',false,boss),
 ('d4000000-0000-0000-0000-000000000a04',co,p1,null,'출고 라벨 시안 확인',hand,d+3,'normal',false,boss),
 ('d4000000-0000-0000-0000-000000000a05',co,p1,null,'박 도면 업체 전달',boss,d-20,'normal',true,boss)
on conflict (id) do nothing;

-- ───────── 활동 기록 ─────────
insert into public.os_activity (id,company_id,project_id,kind,body,by_id,by_name,at) values
 ('d4000000-0000-0000-0000-000000000b01',co,p1,'quote','수주 확정 — 판매금액 98,000,000원',boss,'관리자',now()-interval '35 day'),
 ('d4000000-0000-0000-0000-000000000b02',co,p1,'rfq','대성제본 에 견적을 요청했습니다',boss,'관리자',now()-interval '30 day'),
 ('d4000000-0000-0000-0000-000000000b03',co,p1,'po','대성제본 에 발주했습니다 — PO-2026-001',boss,'관리자',now()-interval '25 day'),
 ('d4000000-0000-0000-0000-000000000b04',co,p1,'sample','1차 샘플 — 수정필요',boss,'관리자',now()-interval '16 day'),
 ('d4000000-0000-0000-0000-000000000b05',co,p1,'spec','사양 V2 을(를) FINAL 로 확정했습니다',boss,'관리자',now()-interval '15 day'),
 ('d4000000-0000-0000-0000-000000000b06',co,p1,'approval','고객이 승인했습니다 (김담당)',boss,'관리자',now()-interval '10 day'),
 ('d4000000-0000-0000-0000-000000000b07',co,p2,'sample','목업 을(를) 등록했습니다',hand,'Test',now()-interval '7 day'),
 ('d4000000-0000-0000-0000-000000000b08',co,p3,'rfq','대성제본 에 견적을 요청했습니다',boss,'관리자',now()-interval '5 day')
on conflict (id) do nothing;

-- ───────── 업체 평가 ─────────
insert into public.os_supplier_evals (id,company_id,supplier_id,project_id,price,quality,ontime,
       comm,response,defect_rate,memo,created_by) values
 ('d4000000-0000-0000-0000-000000000c01',co,s1,p5,4,5,5,4,4,0.8,'양장 품질이 늘 좋습니다',boss),
 ('d4000000-0000-0000-0000-000000000c02',co,s1,null,4,4,5,5,4,0.5,'',boss),
 ('d4000000-0000-0000-0000-000000000c03',co,s2,null,5,4,3,4,3,1.4,'값은 싼데 납기가 밀립니다',boss)
on conflict (id) do nothing;

-- ───────── 제품 템플릿 ─────────
insert into public.os_templates (id,company_id,name,category,spec,memo,created_by) values
 ('d4000000-0000-0000-0000-000000000d01',co,'A5 무선노트 100p','note',
  '{"title":"A5 무선노트","ptype":"노트","size_done":"148 × 210mm","pages":100,
    "paper_cover":"스노우지","gsm_cover":"300gsm","paper_inner":"미색모조","gsm_inner":"80gsm",
    "printing":"옵셋","print_colors":"4/1","binding":"무선제본","extra":[]}'::jsonb,
  '가장 자주 만드는 것',boss)
on conflict (id) do nothing;

raise notice '시연 자료를 넣었습니다';
end $$;

select (select count(*) from public.os_projects  where not deleted) as 프로젝트,
       (select count(*) from public.os_customers where not deleted) as 고객사,
       (select count(*) from public.os_suppliers where not deleted) as 외주업체,
       (select count(*) from public.os_specs     where not deleted) as 사양판,
       (select count(*) from public.os_cost_items where not deleted) as 원가항목,
       (select count(*) from public.os_tasks     where not deleted) as 할일;
