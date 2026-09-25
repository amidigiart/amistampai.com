-- AmiStampAI: one-time stamp packs (e.g. 100 stamps). Run once in Supabase → SQL Editor. Safe to re-run.
-- Requires 20260924_phase_c.sql.
-- Order of use: Pro = unlimited; otherwise the 5 free stamps of the month; then stamps from packs (oldest first).

-- 1. packs: written only by the Stripe webhook (service role); users can read their own
create table if not exists public.stamp_packs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  stamps_count int not null,
  stamps_used int default 0,
  purchased_at timestamptz default now(),
  payment_method text
);
alter table public.stamp_packs add column if not exists stripe_session_id text;
create unique index if not exists stamp_packs_session_uidx
  on public.stamp_packs (stripe_session_id) where stripe_session_id is not null;   -- same Stripe event twice = one pack
alter table public.stamp_packs enable row level security;
do $$
declare p record;
begin
  for p in select policyname from pg_policies where schemaname = 'public' and tablename = 'stamp_packs' loop
    execute format('drop policy %I on public.stamp_packs', p.policyname);
  end loop;
end $$;
create policy "Users read own packs" on public.stamp_packs for select using (auth.uid() = user_id);
revoke insert, update, delete on public.stamp_packs from anon, authenticated;

-- 2. each stamp remembers which pack paid for it (null = free quota or Pro)
alter table public.stamps add column if not exists pack_id uuid references public.stamp_packs(id);

-- 3. free quota counts only stamps not paid by a pack
create or replace function public.stamp_quota_ok(uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
           select 1 from subscriptions s
           where s.user_id = uid and s.plan = 'pro' and s.status in ('active', 'trialing')
             and (s.current_period_end is null or s.current_period_end > now())
         )
      or (select count(*) from stamps t
          where t.user_id = uid and t.pack_id is null and t.synced_at >= date_trunc('month', now())) < 5
$$;
revoke all on function public.stamp_quota_ok(uuid) from public;
grant execute on function public.stamp_quota_ok(uuid) to authenticated;

-- 4. when the free quota is used up, take one stamp from the oldest pack that still has some.
--    pack_id sent by the browser is always ignored; only this trigger sets it.
create or replace function public.stamps_use_pack() returns trigger
language plpgsql security definer set search_path = public as $$
declare pid uuid;
begin
  new.pack_id := null;
  if public.stamp_quota_ok(new.user_id) then
    return new;
  end if;
  select id into pid from stamp_packs
   where user_id = new.user_id and stamps_used < stamps_count
   order by purchased_at, id limit 1 for update;
  if pid is not null then
    update stamp_packs set stamps_used = stamps_used + 1 where id = pid;
    new.pack_id := pid;
  end if;
  return new;
end $$;
drop trigger if exists stamps_use_pack on public.stamps;
create trigger stamps_use_pack before insert on public.stamps
  for each row execute function public.stamps_use_pack();

-- 5. insert allowed within the free quota or when a pack paid for the stamp
drop policy if exists "Users insert own within quota" on public.stamps;
create policy "Users insert own within quota" on public.stamps for insert
  with check (auth.uid() = user_id and (public.stamp_quota_ok(auth.uid()) or pack_id is not null));
