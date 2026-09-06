// Re:O-S 문지기 — 고객사와 외주업체는 계정이 없습니다.
//
// 링크 하나로 두 화면이 갈립니다.
//   프로젝트 토큰 → 고객사 화면 (보기만)
//   발주서 토큰   → 외주업체 화면 (핀을 받고, 납기·진행을 씁니다)
//
// 조심하는 것 넷
//
//   1) 고객사에게는 원가·외주업체·내부 메모가 절대 나가지 않습니다.
//      제작기획사가 어디에 맡겨 얼마에 만드는지는 그 회사의 밥줄입니다.
//      화면에서 안 그리는 것으로는 부족합니다 — 여기서 아예 안 담습니다.
//
//   2) 외주업체에게는 고객사가 나가지 않습니다.
//      누가 최종 발주처인지 알면 다음번엔 직접 붙습니다.
//      같은 이유로 다른 업체의 견적도 안 나갑니다.
//
//   3) 업체는 **쓰기** 때문에 핀을 함께 받습니다.
//      링크는 카톡으로 돌아다니고 담당자는 바뀝니다.
//      틀린 횟수는 표(os_pin_tries)에 셉니다 — 메모리로 옮기지 마세요.
//
//   4) 업체가 보낸 값 중 **날짜와 메모만** 받습니다.
//      수량·단가·상태는 받지 않습니다. 발주 조건을 업체가 바꾸면 안 됩니다.
//      (Re:Store 가 단가를 절대 브라우저에서 안 받는 것과 같은 판단입니다)
//
// 배포:
//   supabase functions deploy reos-gate --no-verify-jwt --project-ref izrtclsqhsgkuwsffifn
//   (--no-verify-jwt 를 빼면 바깥 사람이 열 수 없습니다)
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { mkJson } from '../_shared/cors.ts';

const URL_ = Deno.env.get('SUPABASE_URL')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const admin = createClient(URL_, SERVICE, { auth: { persistSession: false } });

const TOKEN_RE = /^[a-f0-9]{32,64}$/;
const MAX_MISS = 10;
const LOCK_MIN = 10;

// 너무 자주 부르는 것을 늦춥니다. 서버 한 대 안에서만 세는 것이라
// 완벽하지 않습니다 — 늦추는 것이 목적이고, 진짜 벽은 핀 세기입니다.
const hits = new Map<string, { n: number; at: number }>();
function tooMany(ip: string, cap = 60): boolean {
  const now = Date.now();
  const cur = hits.get(ip);
  if (!cur || now - cur.at > 60_000) { hits.set(ip, { n: 1, at: now }); return false; }
  cur.n++;
  if (hits.size > 5000) hits.clear();
  return cur.n > cap;
}

async function pinBlocked(token: string): Promise<boolean> {
  const { data } = await admin.from('os_pin_tries')
    .select('tries, updated_at').eq('token', token).maybeSingle();
  if (!data) return false;
  if (Date.now() - new Date(data.updated_at).getTime() > LOCK_MIN * 60_000) return false;
  return Number(data.tries) >= MAX_MISS;
}
// 몇 번째에서 틀렸는지를 걸린 시간으로 알아내지 못하게 한 글자씩 다 봅니다.
function sameSecret(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

const STAGE = ['inquiry','quotation','contract','planning','rfq','ordered','sample',
               'review','approved','production','qc','delivery','done'];
const STAGE_KO: Record<string,string> = {
  inquiry:'문의', quotation:'견적', contract:'계약', planning:'기획', rfq:'외주견적',
  ordered:'발주', sample:'샘플', review:'고객검토', approved:'승인완료',
  production:'생산', qc:'검수', delivery:'출고·납품', done:'종료',
  hold:'보류', canceled:'취소',
};

Deno.serve(async (req) => {
  const { cors, json } = mkJson(req);
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: '안 되는 요청입니다' }, 405);

  const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
  if (tooMany(ip)) return json({ error: '잠시 뒤에 다시 시도해 주세요' }, 429);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: '잘못된 요청입니다' }, 400); }

  const token = String(body.t ?? '');
  if (!TOKEN_RE.test(token)) return json({ error: '없는 주소입니다' }, 404);
  const action = String(body.action ?? 'view');

  // ───────── 1. 고객사 링크인가 ─────────
  const { data: prj } = await admin.from('os_projects')
    .select('id, company_id, code, name, status, due_on, delivered_on, qty_plan, qty_final, share_on, deleted')
    .eq('share_token', token).maybeSingle();

  if (prj) {
    if (!prj.share_on || prj.deleted) return json({ error: '지금은 볼 수 없는 링크입니다' }, 403);
    if (action !== 'view') return json({ error: '할 수 없는 일입니다' }, 403);

    const [{ data: co }, { data: samples }, { data: appr }] = await Promise.all([
      admin.from('companies').select('name').eq('id', prj.company_id).maybeSingle(),
      admin.from('os_samples').select('kind, status, done_on, got_on, deleted')
        .eq('project_id', prj.id).eq('deleted', false).order('created_at'),
      admin.from('os_approvals').select('status, asked_on, decided_on, deleted')
        .eq('project_id', prj.id).eq('deleted', false).order('created_at', { ascending: false }).limit(3),
    ]);

    const i = STAGE.indexOf(prj.status);
    const progress = prj.status === 'done' ? 100
      : (prj.status === 'hold' || prj.status === 'canceled') ? null
      : i < 0 ? 0 : Math.round(i / (STAGE.length - 1) * 100);

    // 담는 것을 하나하나 적습니다. 통째로 넘기면 나중에 칸이 하나 늘 때
    // 그게 그대로 밖으로 나갑니다.
    return json({
      kind: 'customer',
      maker: co?.name ?? '',
      project: {
        code: prj.code, name: prj.name,
        status: prj.status, statusKo: STAGE_KO[prj.status] ?? prj.status,
        progress,
        due_on: prj.due_on, delivered_on: prj.delivered_on,
        qty: prj.qty_final ?? prj.qty_plan,
      },
      stages: STAGE.map((k, n) => ({ k, n: STAGE_KO[k], past: n < i, now: n === i })),
      samples: (samples ?? []).map((s) => ({ kind: s.kind, status: s.status, done_on: s.done_on })),
      approvals: (appr ?? []).map((a) => ({ status: a.status, asked_on: a.asked_on, decided_on: a.decided_on })),
    });
  }

  // ───────── 2. 외주업체 링크인가 ─────────
  const { data: po } = await admin.from('os_pos')
    .select('id, company_id, project_id, supplier_id, no, spec_ver, ordered_on, due_on, place, qty, ' +
            'pay_term, req_note, status, sup_due_on, sup_note, sample_done_on, make_done_on, ' +
            'share_on, pin, deleted')
    .eq('share_token', token).maybeSingle();

  if (!po) return json({ error: '없는 주소입니다' }, 404);
  if (!po.share_on || po.deleted) return json({ error: '지금은 볼 수 없는 링크입니다' }, 403);

  if (await pinBlocked(token)) {
    return json({ error: '여러 번 틀려 10분 동안 잠겼습니다' }, 429);
  }
  const pin = String(body.pin ?? '');
  if (!po.pin || !sameSecret(pin, po.pin)) {
    if (pin) {
      const n = await admin.rpc('os_pin_miss', { p_token: token });
      const left = MAX_MISS - Number(n.data ?? 0);
      return json({ error: left > 0 ? '핀이 맞지 않습니다 (남은 횟수 ' + left + '회)'
                                    : '여러 번 틀려 10분 동안 잠겼습니다', needPin: true }, 401);
    }
    return json({ needPin: true }, 401);
  }
  await admin.rpc('os_pin_ok', { p_token: token });

  const [{ data: co }, { data: sup }, { data: money }] = await Promise.all([
    admin.from('companies').select('name').eq('id', po.company_id).maybeSingle(),
    admin.from('os_suppliers').select('name').eq('id', po.supplier_id).maybeSingle(),
    admin.from('os_po_money').select('unit_price, supply, vat, total').eq('po_id', po.id).maybeSingle(),
  ]);

  // 발주한 사양 판. 업체가 만들려면 이것이 있어야 합니다 — 작업지시서 몫입니다.
  let spec = null;
  if (po.spec_ver) {
    const { data } = await admin.from('os_specs').select('*')
      .eq('project_id', po.project_id).eq('ver', po.spec_ver).eq('deleted', false).maybeSingle();
    if (data) {
      // 내부용 칸(누가 만들었나·언제 고쳤나)은 빼고 사양만 보냅니다.
      const drop = ['id','company_id','project_id','created_by','created_at','updated_at','deleted','note','is_final'];
      spec = Object.fromEntries(Object.entries(data).filter(([k]) => !drop.includes(k)));
    }
  }

  // ── 업체가 적어 넣는 것 ──
  if (action === 'update') {
    const patch: Record<string, unknown> = {};
    const dateOk = (v: unknown) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v);
    // 날짜와 메모만 받습니다. 수량·단가·납기(우리가 정한 due_on)는 받지 않습니다.
    if (body.sup_due_on === null || dateOk(body.sup_due_on)) patch.sup_due_on = body.sup_due_on ?? null;
    if (body.sample_done_on === null || dateOk(body.sample_done_on)) patch.sample_done_on = body.sample_done_on ?? null;
    if (body.make_done_on === null || dateOk(body.make_done_on)) patch.make_done_on = body.make_done_on ?? null;
    if (typeof body.sup_note === 'string') patch.sup_note = body.sup_note.slice(0, 1000);
    // 상태는 업체가 고를 수 있는 둘만. 취소나 완료 처리는 우리 쪽 몫입니다.
    if (body.accept === true && po.status === 'sent') patch.status = 'accepted';
    if (body.making === true && ['sent','accepted'].includes(po.status)) patch.status = 'making';

    if (Object.keys(patch).length) {
      const { error } = await admin.from('os_pos').update(patch).eq('id', po.id);
      if (error) return json({ error: '저장하지 못했습니다' }, 500);
      const what: string[] = [];
      if (patch.sup_due_on) what.push('납기 ' + patch.sup_due_on);
      if (patch.sample_done_on) what.push('샘플 완료 ' + patch.sample_done_on);
      if (patch.make_done_on) what.push('생산 완료 ' + patch.make_done_on);
      if (patch.status) what.push(patch.status === 'accepted' ? '발주 접수' : '생산 시작');
      await admin.from('os_activity').insert({
        company_id: po.company_id, project_id: po.project_id, kind: 'po',
        body: (sup?.name ?? '외주업체') + ' 가 직접 적었습니다 — ' + (what.join(' · ') || '메모'),
        by_name: (sup?.name ?? '외주업체') + ' (업체 화면)',
        meta: { po_id: po.id, via: 'supplier-portal' },
      });
      Object.assign(po, patch);
    }
  }

  return json({
    kind: 'supplier',
    maker: co?.name ?? '',
    supplier: sup?.name ?? '',
    po: {
      no: po.no, ordered_on: po.ordered_on, due_on: po.due_on, place: po.place,
      qty: po.qty, pay_term: po.pay_term, req_note: po.req_note, status: po.status,
      sup_due_on: po.sup_due_on, sup_note: po.sup_note,
      sample_done_on: po.sample_done_on, make_done_on: po.make_done_on,
    },
    money: money ?? null,     // 자기 발주 건의 금액입니다. 다른 업체 것은 없습니다.
    spec,
  });
});
