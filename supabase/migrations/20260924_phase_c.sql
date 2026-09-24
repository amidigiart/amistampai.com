-- AmiStampAI phase C: paid plans enforced server-side, private stamp listing, public single-stamp lookup.
-- Run once in Supabase → SQL Editor. Safe to re-run.

-- 1. subscriptions: fields written by the Stripe webhook (service role only)
alter table public.subscriptions add column if not exists status text not null default 'inactive';
alter table public.subscriptions add column if not exists stripe_subscription_id text;
alter table public.subscriptions enable row level security;
drop policy if exists "Users read own sub" on public.subscriptions;
create policy "Users read own sub" on public.subscriptions for select using (auth.uid() = user_id);
-- no insert/update/delete policies: only the service role (webhook) writes here

-- 2. stamps: server-side sync time, so the monthly quota cannot be dodged by back-dating created_at
alter table public.stamps add column if not exists synced_at timestamptz not null default now();
create or replace function public.stamps_set_synced_at() returns trigger
language plpgsql as $$
begin
  new.synced_at := now();
  return new;
end $$;
drop trigger if exists stamps_synced_at on public.stamps;
create trigger stamps_synced_at before insert on public.stamps
  for each row execute function public.stamps_set_synced_at();
create index if not exists stamps_user_synced_idx on public.stamps (user_id, synced_at);

-- 3. quota: Pro (active) = unlimited; otherwise 5 synced stamps per calendar month
create or replace function public.stamp_quota_ok(uid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
           select 1 from subscriptions s
           where s.user_id = uid and s.plan = 'pro' and s.status in ('active', 'trialing')
             and (s.current_period_end is null or s.current_period_end > now())
         )
      or (select count(*) from stamps t
          where t.user_id = uid and t.synced_at >= date_trunc('month', now())) < 5
$$;
revoke all on function public.stamp_quota_ok(uuid) from public;
grant execute on function public.stamp_quota_ok(uuid) to authenticated;

-- 4. stamps policies: no more public listing of everyone's stamps
alter table public.stamps enable row level security;
drop policy if exists "Public verify by id" on public.stamps;
drop policy if exists "Users read own" on public.stamps;
drop policy if exists "Users insert own" on public.stamps;
drop policy if exists "Users insert own within quota" on public.stamps;
drop policy if exists "Users update own anchors" on public.stamps;
create policy "Users read own" on public.stamps for select using (auth.uid() = user_id);
create policy "Users insert own within quota" on public.stamps for insert
  with check (auth.uid() = user_id and public.stamp_quota_ok(auth.uid()));
create policy "Users update own anchors" on public.stamps for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- owners may only change anchor fields after creation
revoke update on public.stamps from authenticated, anon;
grant update (blockchain_tx, blockchain_network, context_graph) on public.stamps to authenticated;

-- 5. public verification of ONE stamp by id (no listing, owner id not exposed)
drop function if exists public.get_stamp(uuid);
create function public.get_stamp(p_id uuid)
returns table (id uuid, content_hash text, sens text, intentie text, signature text, public_key jsonb,
               blockchain_tx text, blockchain_network text, context_graph jsonb, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select id, content_hash, sens, intentie, signature, public_key, blockchain_tx, blockchain_network, context_graph, created_at
  from stamps where id = p_id limit 1
$$;
revoke all on function public.get_stamp(uuid) from public;
grant execute on function public.get_stamp(uuid) to anon, authenticated;
