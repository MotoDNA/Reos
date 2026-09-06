-- ═══════════════════════════════════════════════════════════════
-- 핀을 틀렸을 때 횟수를 올립니다
--
-- 읽고 나서 쓰면, 동시에 두 번 찔렀을 때 둘 다 같은 값을 읽고 지나갑니다.
-- 한 문장으로 올리고 올라간 값을 돌려받습니다.
-- ═══════════════════════════════════════════════════════════════
create or replace function public.os_pin_miss(p_token text)
returns integer language plpgsql security definer set search_path = public as $$
declare v integer;
begin
  insert into public.os_pin_tries (token, tries, updated_at)
       values (p_token, 1, now())
  on conflict (token) do update
     set tries = case when public.os_pin_tries.updated_at < now() - interval '10 minutes'
                      then 1 else public.os_pin_tries.tries + 1 end,
         updated_at = now()
  returning tries into v;
  return v;
end $$;
revoke all on function public.os_pin_miss(text) from public, anon, authenticated;
grant execute on function public.os_pin_miss(text) to service_role;

-- 맞게 들어오면 셈을 지웁니다.
create or replace function public.os_pin_ok(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from public.os_pin_tries where token = p_token
$$;
revoke all on function public.os_pin_ok(text) from public, anon, authenticated;
grant execute on function public.os_pin_ok(text) to service_role;

select 'os_pin_miss · os_pin_ok 준비됨' as 결과;
