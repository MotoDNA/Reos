# Re:O-S — 한 장으로 보는 전부

제작기획사가 쓰는 **제작 프로젝트와 외주관리** 앱입니다.
고객 문의를 받아 사양을 잡고, 외주업체에 견적을 물어 발주하고,
샘플을 승인받아 생산에 넘기고, 원가와 이익까지 한 프로젝트 화면에서 봅니다.

이 문서는 **지금 상태**만 적습니다. "언제 무엇을 왜 그렇게 했는가"는
[진행상황.md](진행상황.md)에 날짜순으로 있습니다.

네 서비스를 함께 다루는 규칙(얽혀 있는 것 · 배포 · 말투)은 스킬
`~/.claude/skills/dnalabs/SKILL.md` 에 있습니다.

*기준 2026-09-06*

---

## 0. ⚠ 아직 운영에 안 올렸습니다

**표와 서버 함수는 운영에 들어가 있고, 앱은 로컬 커밋까지만 되어 있습니다.**
저장소를 만들지 않았고 push 도 안 했습니다 — 올릴지 말지는 사람이 정합니다.

지금 상태:

| 무엇 | 어디까지 |
|---|---|
| 표 스물 · RLS · 보관함 | **운영 DB 에 들어감** |
| ACTIVA 에 `reos` 열기 | **들어감** |
| `reos-gate` 서버 함수 | **배포됨** |
| 시연 자료 (프로젝트 5건) | **들어감** (`sql/0005_demo.sql`) |
| `reos.html` 등 앱 | 로컬 커밋만 |
| 형제 셋 토글 (넷으로) | 로컬 커밋만 |
| `/os` rewrite | 로컬 커밋만 |
| GitHub 저장소 · Pages | **아직 없음** |

올리려면 — 순서대로:

```bash
# 1. 저장소를 만들고 올립니다 (Pages 는 공개에서만 공짜입니다)
cd ~/Desktop/05_개발프로젝트/Reos
gh repo create MotoDNA/Reos --public --source=. --push
gh api -X POST repos/MotoDNA/Reos/pages -f 'source[branch]=main' -f 'source[path]=/'

# 2. 형제 셋 (토글이 넷이 됩니다)
git -C ~/Desktop/05_개발프로젝트/Rebind  push
git -C ~/Desktop/05_개발프로젝트/Restore push

# 3. 홈페이지 — /os rewrite
#    ⚠ `npx vercel --prod` 는 쓰지 마세요. 지금 web/ 에 커밋 안 된 변경이
#      34건 있어서 그것까지 함께 올라갑니다. git push 로 올리면
#      커밋된 것만 올라갑니다.
git -C ~/Desktop/05_개발프로젝트/network-dna push
```

올린 뒤 `https://dnalabs.kr/os` 를 열어 콘솔까지 봅니다.
GitHub Pages 는 1~2분, 브라우저가 옛 파일을 한동안 보여 줍니다 — `?v=2`.

시연 자료를 지우려면:

```sql
delete from public.os_projects  where id::text like 'd4000000-%';
delete from public.os_customers where id::text like 'd4000000-%';
delete from public.os_suppliers where id::text like 'd4000000-%';
```

---

## 1. 어디에 있나

| | |
|---|---|
| 운영 | **https://dnalabs.kr/os** (아직 안 열렸습니다 — 0장) |
| 저장소 | https://github.com/MotoDNA/Reos — 아직 안 만들었습니다 |
| 폴더 | `~/Desktop/05_개발프로젝트/Reos` |

**옛 주소(`reos.dnalabs.kr`)가 없습니다.** 형제 셋과 다른 점입니다.
새로 만든 앱이라 밖으로 나간 링크가 없어서, 이름표(도메인)를 하나 더 사고
DNS 를 건드릴 이유가 없었습니다. `dnalabs.kr/os` 가 본집이고,
Vercel rewrite 가 GitHub Pages(`motodna.github.io/Reos/reos.html`)를 비춥니다.

⚠ 그래서 **공유 링크는 언제나 `https://dnalabs.kr/os?t=…`** 로 나갑니다.
github.io 주소로 나가면 문지기가 CORS 로 막습니다 — 그 주소는
`ALLOWED_ORIGIN` 에 없습니다. 앱이 링크를 만들 때 이미 못 박아 두었습니다.

---

## 2. 형제 서비스 넷

| 서비스 | 하는 일 | 새 주소 | 옛 주소 | 폴더 |
|---|---|---|---|---|
| Re:Bind | 프로젝트별 공정 관리 | `dnalabs.kr/bind` | `rebind.dnalabs.kr` | `Rebind` |
| Re:Call | 고객관리 | `dnalabs.kr/call` | `recall.dnalabs.kr` | `network-dna` |
| Re:Store | 가맹점 발주·정산 | `dnalabs.kr/store` | `restore.dnalabs.kr` | `Restore` |
| **Re:O-S** | **제작 외주관리** | `dnalabs.kr/os` | — | `Reos` |

**Re:O-S 가 막내입니다.** `0001_init.sql`(Re:Call)의 도우미 함수를 그대로 씁니다.

```
current_company_id()   지금 로그인한 사람의 회사
is_admin()             관리자인가
company_for_app(app)   그 서비스를 산 회사인가   ← Rebind/sql/0019_apps.sql
touch_updated_at()     수정시각 자동 갱신
```

⚠ **넷이 얽혀 있어 하나만 보고 고치면 다른 쪽이 멈추는 것 셋**
1. `ALLOWED_ORIGIN` (6장)
2. `companies.apps` (5장)
3. 로그인 화면의 서비스 토글 — **이제 네 앱이** 같은 차례·같은 문구를 씁니다

### Re:Bind 와 무엇이 다른가

이름이 비슷해 헷갈립니다. **보는 자리가 반대입니다.**

| | Re:Bind | Re:O-S |
|---|---|---|
| 쓰는 사람 | 제본소·인쇄소 (**만드는 쪽**) | 제작기획사 (**맡기는 쪽**) |
| 중심 | 우리 공장의 공정 | 바깥 업체 여러 곳 |
| 돈 | 고객에게 받을 돈 | 받을 돈 **－** 업체에 줄 돈 = 이익 |
| 바깥 사람 | 고객사가 진행도를 봄 | 고객사가 봄 **＋ 외주업체가 적음** |

---

## 3. 파일 구조

```
reos.html             앱 전부. 이 파일 하나입니다 (약 3,900줄 / 250KB)
                      회사 화면 · 고객사 화면 · 외주업체 화면이 같은 파일입니다.
                      주소에 ?t=토큰 이 붙으면 바깥 화면으로 갈립니다.
index.html            reos.html 로 넘겨 주기만 합니다 (?t= 를 실어서)
sql/0001_reos.sql     표 스물 (809줄)
sql/0002_company.sql  ACTIVA 에 Re:O-S 열어 주기
sql/0003_portal.sql   핀 시도 세는 표 · 문지기 권한
sql/0004_pin_rpc.sql  핀 틀린 횟수를 한 문장으로 올리는 함수
supabase/functions/
  reos-gate/          바깥 사람 문지기 (--no-verify-jwt)
  _shared/cors.ts     네 앱이 같은 파일을 씁니다
manifest.webmanifest · icon-*.png     홈 화면 설치용
```

### 화면 다섯 · 프로젝트 탭 여덟

| 탭 | id | |
|---|---|---|
| 오늘 | `p-dash` | 오늘 할 일 · 급한 것 · 단계별 현황 · 최근 활동 |
| 프로젝트 | `p-prjs` | 목록 / 보드(끌어 놓기) · 찾기 · 거르기 |
| 일정 | `p-cal` | 달력 · 앞으로 2주 |
| 거래처 | `p-biz` | 고객사 / 외주업체 |
| 설정 | `p-set` | 계정 · 팀원 · 금액 공개 · 템플릿 |

프로젝트 상세는 덮는 화면(`#detail`)이고 탭이 여덟입니다 —
**개요 · 사양 · 견적 · 외주 · 샘플 · 원가 · 파일 · 기록**.
바깥 사람 화면은 `#pub`, 시트는 `#sheet` **하나를 돌려 씁니다**.

---

## 4. 데이터 모양

표 이름이 전부 `os_` 로 시작합니다. Re:Bind 가 이미 `projects` 를 쓰고
있어서, 이름이 겹치면 둘 중 하나가 못 들어옵니다.

### 금액은 딴 표입니다 — 이 앱에서 가장 중요한 규칙

`os_projects` 에는 **금액 칸이 하나도 없습니다.** 직원도 읽는 표이기 때문입니다.

| 금액이 든 표 | 담는 것 |
|---|---|
| `os_money` | 프로젝트당 판매금액 한 줄 |
| `os_cost_items` | 원가 항목. **예상 · 확정 · 실제 세 자리** |
| `os_quote_money` | 고객 견적 금액 |
| `os_rfq_money` | 외주 견적 금액 |
| `os_po_money` | 발주 금액 |

읽기는 `os_money_ok()`, 쓰기는 `is_admin()`.
`os_money_ok()` 는 관리자이거나 `company_settings.staff_money` 가 켜진
회사의 직원일 때 참입니다 — **Re:Bind 와 같은 칸을 씁니다.**
열어 주어도 **고치는 것은 관리자만** 입니다.

**화면에서 가리는 것이 아니라 서버가 아예 안 내려 줍니다.**
Re:Store 는 아직 화면에서만 가려서 개발자 도구를 열면 보입니다
(RESTORE.md 11장 구멍 1). 여기는 처음부터 나눠 두었습니다.

### 나머지 표

| 표 | |
|---|---|
| `os_customers` | 고객사. 담당자 여럿은 `contacts` jsonb 에 |
| `os_suppliers` | 외주업체. `caps` text[] 로 "무엇을 할 수 있나" (gin 색인) |
| `os_projects` | 프로젝트. `status` 열다섯 · `share_token`(고객 링크) |
| `os_specs` | **사양 판(version).** 덮어쓰지 않고 쌓습니다. `is_final` 은 한 판만 |
| `os_quotes` | 고객 견적 |
| `os_rfqs` | 외주 견적 요청 — 한 줄 = 업체 하나 |
| `os_pos` | 외주 발주서. `share_token`+`pin`(업체 포털) |
| `os_samples` | 샘플. 종류 일곱 · 상태 여섯 · `photos` jsonb |
| `os_proofs` | 교정. 샘플(물건)과 나눴습니다 — 교정은 종이(디자인)입니다 |
| `os_approvals` | 고객 승인. 누가 언제 어느 판을 보고 눌렀나 |
| `os_files` | 파일. 같은 이름을 또 올리면 **판이 올라갑니다** |
| `os_tasks` `os_activity` | 할 일 · 활동 기록(자동) |
| `os_supplier_evals` `os_templates` | 업체 평가 · 제품 템플릿 |
| `os_pin_tries` | 업체 핀 틀린 횟수. **정책 없음(의도)** — 문지기만 씁니다 |

보관함: **`osfiles`**(비공개). 경로가 곧 권한 — `{회사id}/{프로젝트id}/{파일id}.확장자`

---

## 5. 누가 무엇을 볼 수 있나

### 회사 단위 (`companies.apps`)

```
apps text[]   {rebind} · {recall} · {restore} · {reos} · 여러 개 가능
```

지금: `ACTIVA {rebind,recall,reos}` · `BKT {rebind}` · `9DORO {restore}` · `DNALABS {}`

**비어 있으면 아무 데도 못 들어갑니다.** 새 회사를 만들 때 꼭 함께 넣으세요.
`company_for_app('reos')` 가 null 을 돌려주면 표가 통째로 닫힙니다.

### 사람 단위

**관리자만:** 금액 넣고 고치기 · 견적 만들기 · 프로젝트 지우기 · 직원 금액 공개 설정

**직원:** 프로젝트·사양·외주 견적 요청·발주서·샘플·파일·할 일 (금액 빼고)

지시서에는 역할이 일곱(PM·SALES·PRODUCTION·QC·ACCOUNTING…)이었지만
**만들지 않았습니다.** `profiles.role` 은 네 서비스가 함께 쓰는 칸이라
여기서 늘리면 형제 셋이 모르는 값을 보게 됩니다. 지금 쓰는 회사에
그만한 사람이 없기도 합니다 — 필요해지면 그때 넷이 함께 늘립니다.

### 바깥 사람 — 계정이 없습니다

| 고객사 | 링크만. **보기만** 합니다 |
|---|---|
| 외주업체 | 링크 **＋ 핀 여섯 자리**. 납기·샘플 완료·생산 완료를 **씁니다** |

---

## 6. 접속과 서버

```
Project ref  izrtclsqhsgkuwsffifn
회사코드 ACTIVA / admin
```

```bash
cd ~/Desktop/05_개발프로젝트/Rebind          # supabase CLI 가 link 된 폴더
supabase db query --linked "select ..."
cd ~/Desktop/05_개발프로젝트/Reos
supabase functions deploy reos-gate --no-verify-jwt --project-ref izrtclsqhsgkuwsffifn
```

`--no-verify-jwt` 를 빼면 **고객사와 외주업체가 링크를 못 엽니다.**

### ⚠ ALLOWED_ORIGIN

**다섯 주소가 함께 쓰는 값 하나입니다.** 지금까지 세 번 어긋났습니다.
**틀려도 조용합니다** — 화면은 뜨고 로그인도 되는데 서버 함수만 막힙니다.

```bash
supabase secrets set ALLOWED_ORIGIN="https://rebind.dnalabs.kr,https://recall.dnalabs.kr,https://restore.dnalabs.kr,https://dnalabs.kr" \
  --project-ref izrtclsqhsgkuwsffifn
```

**Re:O-S 는 이 값을 늘리지 않아도 됩니다.** `dnalabs.kr` 하나에서만 돌기
때문입니다. 대신 바꾼 뒤에는 **함수 아홉을 모두 다시 배포**해야 합니다 —
`reos-gate`(여기) · `share-view` `read-order`(Re:Bind) ·
`read-card` `admin-user` `signup` `subscription`(Re:Call) ·
`store-gate`(Re:Store) · `ops`(운영).

```bash
curl -s -o /dev/null -D - -X OPTIONS \
  https://izrtclsqhsgkuwsffifn.supabase.co/functions/v1/reos-gate \
  -H "Origin: https://dnalabs.kr" -H "Access-Control-Request-Method: POST" \
  | grep -i access-control-allow-origin
# 부른 주소가 그대로 돌아오면 통과
```

### `reos-gate` — 문지기가 조심하는 것 넷

1. **고객사에게 원가·외주업체·내부 메모가 안 나갑니다.** 어디에 맡겨 얼마에
   만드는지는 제작기획사의 밥줄입니다. 화면에서 안 그리는 것으로는 부족해서
   함수가 담을 것을 하나하나 적어 보냅니다.
2. **외주업체에게 고객사가 안 나갑니다.** 최종 발주처를 알면 다음엔 직접 붙습니다.
   다른 업체의 견적도 안 나갑니다.
3. **업체는 쓰기 때문에 핀을 받습니다.** 틀린 횟수는 `os_pin_tries` **표**에
   셉니다 — 메모리(Map)로 옮기지 마세요. Edge Function 은 쉬면 내려갔다
   새로 떠서 센 것이 0 으로 돌아갑니다(Re:Store 가 겪었습니다).
4. **업체가 보낸 값 중 날짜와 메모만 받습니다.** 수량·단가·우리가 정한 납기는
   받지 않습니다. 발주 조건을 업체가 바꾸면 안 됩니다.

---

## 7. 일을 하면 상태가 따라옵니다

실무자가 상태를 손으로 바꾸게 두면 아무도 안 바꿉니다.

| 한 일 | 따라오는 것 |
|---|---|
| 고객 견적 만들기 | → 견적 |
| 견적 수주 확정 | → 계약 **＋ 판매금액이 저절로 들어감** |
| 외주 견적 요청 | → 외주견적 |
| 발주서 만들기 | → 발주 **＋ 외주 제작비가 원가에 한 줄 저절로** |
| 샘플 등록 | → 샘플 |
| 샘플 검토 요청 / 고객 승인 요청 | → 고객검토 |
| 샘플 승인 / 고객 승인 완료 | → 승인완료 |
| 발주서에 생산 완료일 | → 검수 |

⚠ **뒤로는 안 갑니다.** 샘플을 하나 더 등록했다고 생산 중인 프로젝트가
샘플 단계로 되돌아가면 화면 보는 사람이 무엇이 맞는지 모릅니다.
되돌리거나 건너뛰는 것은 사람이 상태 단추로 정합니다.

---

## 8. 로그인 화면

**넷이 됐습니다.** 네 앱이 같은 차례·같은 문구를 씁니다.

```js
const APPS     = ['rebind','recall','restore','reos'];
const ONE_ROOF = { rebind:'/bind', recall:'/call', restore:'/store', reos:'/os' };
```

⚠ **뒤에 붙였습니다.** 앞에 끼우면 기기에 저장된 선택(`localStorage['dnalabs-app']`
과 토글 자리 `i0`·`i1`·`i2`)이 딴 것을 가리킵니다.

토글이 셋에서 넷이 되면서 **390px 폰에서 한 칸이 78px** 밖에 안 남습니다.
그래서 좁은 화면에서는 설명줄(`i`)을 감추고 이름과 그림만 둡니다 —
글자를 더 줄이면 읽을 수 없게 됩니다. PC 에서는 다시 보입니다.

**로그인 정보는 네 서비스가 똑같습니다.** 보관 자리도 넷 다 `ndna-auth` 입니다.

---

## 9. 고칠 때 지키는 것

**1. 문법 검사만으로는 부족합니다.** 한 파일이라 초기화 순서 오류(TDZ)는 안 걸러집니다.

```bash
python3 -c "
import io,re
s=io.open('reos.html',encoding='utf-8').read()
io.open('/tmp/app.js','w',encoding='utf-8').write(re.findall(r'<script>(.*?)</script>',s,re.S)[-1])
" && node --check /tmp/app.js
```

**2. 반드시 브라우저로 열어 보고 콘솔까지 봅니다.**
한 지붕 동작을 보려면 `/bind`·`/call`·`/store`·`/os` 를 한 주소에서
내려 주는 작은 서버를 띄워야 합니다(그래야 `underOneRoof` 가 켜집니다).

**3. 바깥 화면은 시크릿 창에서 봅니다.** 로그인이 남아 있으면 회사 화면이 뜹니다.

**4. 파이썬으로 고칩니다.** 파일이 커서 통째로 다시 쓰지 않습니다.
`assert old in s` 로 자리를 확인하고 `replace(old,new,1)` 합니다.

**5. 올린 뒤에도 운영 주소를 열어 봅니다.** GitHub Pages 는 1~2분,
브라우저가 옛 파일을 한동안 보여 줍니다 — 안 바뀐 것 같으면 `?v=2`.

---

## 10. 배포

| 무엇 | 어떻게 |
|---|---|
| 앱 (`reos.html`) | `git push` → GitHub Pages 1~2분 |
| 서버 함수 | `supabase functions deploy reos-gate --no-verify-jwt --project-ref izrtclsqhsgkuwsffifn` |
| SQL | `supabase db query --linked -f sql/000N_….sql` |
| **rewrite (`/os`)** | `cd ~/Desktop/05_개발프로젝트/network-dna && npx vercel --prod --scope chhanj40-5991s-projects` |
| 로고 | `python3 ~/Desktop/05_개발프로젝트/Rebind/make-logo.py` → **네 앱에 함께**. 저장소 넷을 각각 커밋 |

`--scope` 를 빼면 `Not authorized` 가 납니다.

`dnalabs.kr/os` 는 rewrite 라 **GitHub Pages 만 반영되면 함께 바뀝니다.**

---

## 11. 함정 모음

| | |
|---|---|
| 표 이름 | 전부 `os_` 로 시작합니다. `projects` 는 Re:Bind 것입니다 |
| 새 회사 | `apps` 에 `reos` 를 꼭 함께 넣으세요. 안 넣으면 화면이 통째로 빕니다 |
| 금액 | `os_money`·`os_cost_items` 로 나눠 둔 원칙을 깨지 마세요. 한 표로 합치면 직원에게 그대로 내려갑니다 |
| 공유 링크 | 언제나 `dnalabs.kr/os?t=…`. github.io 주소로 나가면 문지기가 막습니다 |
| 핀 세는 자리 | **`os_pin_tries` 표.** 메모리로 되돌리면 잠금이 안 걸립니다 |
| `os_pin_tries` 정책 | **없는 게 맞습니다.** 만들지 마세요 |
| 사양 FINAL | 한 판만입니다. 새로 정하면 앞의 것이 풀립니다 |
| 최종본 파일 | 같은 이름 안에서 하나만. 최종본이 둘이면 최종이 아닙니다 |
| 그리드 `1fr` | 안에 든 것보다 작아지지 않습니다. 긴 금액이 칸을 밀어내 화면 밖으로 나갑니다 — `minmax(0,1fr)` 로 두세요 |
| 닫힌 시트 | PC 에서는 가운데에 투명하게 남습니다. `visibility:hidden` 을 **미끄러져 내려간 뒤**에 걸어야 클릭을 안 먹고 닫히는 모습도 보입니다 |
| `word-break:keep-all` | 혼자 두면 긴 주소 하나에 가로 스크롤이 생깁니다. `overflow-wrap:break-word` 를 **꼭 같이** |
| 날짜 | `toISOString()` 을 그냥 쓰면 밤 아홉 시 넘어 만든 것이 어제로 찍힙니다. `todayKST()` 를 쓰세요 |
| **사양 제품명** | 업체가 만들려면 있어야 해서 **그대로 나갑니다.** 거기에 고객사 이름이 들어 있으면 감출 방법이 없습니다 — 링크 만드는 자리에서 알려 주기만 합니다 |

---

## 12. 아직 안 한 것

지시서 95장 중 **Phase 1(MVP)** 까지 했습니다. 남은 것:

- **생산 공정 관리** — 인쇄→코팅→후가공→제본 공정별 담당업체·일정·불량수량.
  지금은 발주서의 `make_done_on` 하나로만 봅니다
- **QC 와 불량** — 제품 유형별 검수 체크리스트, 불량 기록, 비용부담 주체
- **출고·납품** — 분할 납품(1차 4,000 / 2차 6,000)을 담을 표가 없습니다
- **정산** — 계약금·중도금·잔금, 미수금·미지급금
- **서류 PDF** — 견적서·발주서·작업지시서·거래명세서
- **Excel 들이기/내보내기**
- **리포트** — 월별 매출·이익, 업체별 발주금액, 납기 준수율
- **고객 승인 링크** — 표(`os_approvals.token`)와 칸은 만들어 두었지만
  고객이 웹에서 누르는 화면은 아직입니다. 지금은 안에서 기록만 합니다
- **알림을 밖으로** — 화면 안 종만 있습니다. 메일·알림톡은 없습니다
- **AI** — 견적 보조·업체 추천·요약. 자료 구조는 그쪽을 보고 짰습니다
- **요금제** — Re:O-S 를 파는 요금제가 없습니다. `9DORO`(Re:Store)와 같은
  처지입니다 — `companies.apps` 에 손으로 넣었습니다.
  자세한 것은 `RECALL.md` 7장, `RESTORE.md` 7장
- **목록을 한 번에 다 읽습니다.** 프로젝트가 수천 건이 되면 첫 화면이 느려집니다.
  그때 서버 쪽 쪽나누기(pagination)로 바꿔야 합니다. 지금은 프로젝트 속살만
  열 때 따로 읽습니다

---

## 13. 말투

한국어로 씁니다. **무엇을 했는지가 아니라 왜 그렇게 했는지**를 적습니다.
과장하지 않고, 안 된 것은 안 됐다고 적습니다.
사용자는 개발자가 아닙니다 — 전문 용어는 한 줄로 풀어 줍니다.
