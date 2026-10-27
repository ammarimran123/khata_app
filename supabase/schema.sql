-- Khata App — Phase 1 schema
-- Run this once in the Supabase SQL Editor (Project → SQL Editor → New query).
-- Safe to re-run: guarded with IF NOT EXISTS / OR REPLACE where possible.

create extension if not exists "pgcrypto";

-- ═══════════════════════════════════════════════════════════════════════
-- profiles — one row per authenticated user
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  business_name text,
  phone text,
  currency text not null default 'PKR',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ═══════════════════════════════════════════════════════════════════════
-- categories — income/expense categories, seeded per user, user-extendable
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  type text not null check (type in ('income', 'expense')),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, type, name)
);

create index if not exists categories_user_id_idx on public.categories (user_id);

-- ═══════════════════════════════════════════════════════════════════════
-- clients
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  phone text not null,
  phone_normalized text generated always as (regexp_replace(phone, '\D', '', 'g')) stored,
  business_name text,
  notes text,
  opening_balance numeric(14, 2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists clients_user_id_idx on public.clients (user_id);
create index if not exists clients_user_active_idx on public.clients (user_id, is_active);
create unique index if not exists clients_user_phone_unique
  on public.clients (user_id, phone_normalized)
  where phone_normalized <> '';

-- ═══════════════════════════════════════════════════════════════════════
-- client_transactions — the ledger (credit/debit against a client)
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.client_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id uuid not null references public.clients (id) on delete cascade,
  type text not null check (type in ('credit', 'debit')),
  amount numeric(14, 2) not null check (amount > 0),
  occurred_at timestamptz not null default now(),
  description text,
  payment_method text check (payment_method in ('Cash', 'Bank Transfer', 'Card', 'Cheque', 'Other')),
  reference_no text,
  notes text,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  deleted_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists client_tx_client_id_idx on public.client_transactions (client_id);
create index if not exists client_tx_user_occurred_idx on public.client_transactions (user_id, occurred_at desc);
create index if not exists client_tx_user_deleted_idx on public.client_transactions (user_id, is_deleted);

-- ═══════════════════════════════════════════════════════════════════════
-- income_expenses — business income/expense, independent of client ledger
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.income_expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('income', 'expense')),
  category_id uuid references public.categories (id) on delete set null,
  amount numeric(14, 2) not null check (amount > 0),
  occurred_at timestamptz not null default now(),
  description text,
  payment_method text check (payment_method in ('Cash', 'Bank Transfer', 'Card', 'Cheque', 'Other')),
  reference_no text,
  notes text,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  deleted_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists income_expenses_user_occurred_idx on public.income_expenses (user_id, occurred_at desc);
create index if not exists income_expenses_category_idx on public.income_expenses (category_id);
create index if not exists income_expenses_user_type_idx on public.income_expenses (user_id, type);

-- ═══════════════════════════════════════════════════════════════════════
-- reminders
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_id uuid references public.clients (id) on delete cascade,
  title text not null,
  notes text,
  remind_at timestamptz not null,
  is_completed boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists reminders_user_remind_idx on public.reminders (user_id, remind_at);
create index if not exists reminders_client_idx on public.reminders (client_id);

-- ═══════════════════════════════════════════════════════════════════════
-- client_balances — convenience view, security_invoker so RLS still applies
-- ═══════════════════════════════════════════════════════════════════════
create or replace view public.client_balances
  with (security_invoker = true) as
select
  c.id as client_id,
  c.user_id,
  c.opening_balance
    + coalesce(sum(t.amount) filter (where t.type = 'credit'), 0)
    - coalesce(sum(t.amount) filter (where t.type = 'debit'), 0) as balance,
  max(t.occurred_at) as last_transaction_at,
  count(t.id) as transaction_count
from public.clients c
left join public.client_transactions t
  on t.client_id = c.id and t.is_deleted = false
group by c.id, c.user_id, c.opening_balance;

-- ═══════════════════════════════════════════════════════════════════════
-- updated_at trigger helper
-- ═══════════════════════════════════════════════════════════════════════
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_updated_at on public.profiles;
create trigger set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.clients;
create trigger set_updated_at before update on public.clients
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.client_transactions;
create trigger set_updated_at before update on public.client_transactions
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.income_expenses;
create trigger set_updated_at before update on public.income_expenses
  for each row execute function public.set_updated_at();

-- ═══════════════════════════════════════════════════════════════════════
-- new-user bootstrap — create profile + seed default categories
-- ═══════════════════════════════════════════════════════════════════════
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name');

  insert into public.categories (user_id, name, type, is_default) values
    (new.id, 'Sales', 'income', true),
    (new.id, 'Service income', 'income', true),
    (new.id, 'Other income', 'income', true),
    (new.id, 'Purchases', 'expense', true),
    (new.id, 'Rent', 'expense', true),
    (new.id, 'Salaries', 'expense', true),
    (new.id, 'Utilities', 'expense', true),
    (new.id, 'Transportation', 'expense', true),
    (new.id, 'Maintenance', 'expense', true),
    (new.id, 'Other', 'expense', true);

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ═══════════════════════════════════════════════════════════════════════
-- Row Level Security — every table, owner-only access via auth.uid()
-- ═══════════════════════════════════════════════════════════════════════
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.clients enable row level security;
alter table public.client_transactions enable row level security;
alter table public.income_expenses enable row level security;
alter table public.reminders enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select using (id = auth.uid());
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (id = auth.uid());

drop policy if exists "categories_all_own" on public.categories;
create policy "categories_all_own" on public.categories for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "clients_all_own" on public.clients;
create policy "clients_all_own" on public.clients for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "client_tx_all_own" on public.client_transactions;
create policy "client_tx_all_own" on public.client_transactions for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "income_expenses_all_own" on public.income_expenses;
create policy "income_expenses_all_own" on public.income_expenses for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "reminders_all_own" on public.reminders;
create policy "reminders_all_own" on public.reminders for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ═══════════════════════════════════════════════════════════════════════
-- Table-level grants — required alongside RLS. Postgres checks base
-- privileges before RLS policies ever run, so anon/authenticated need
-- explicit grants here or every request 42501s regardless of policy.
-- RLS still fully restricts which rows each grant can actually touch.
-- ═══════════════════════════════════════════════════════════════════════
grant usage on schema public to anon, authenticated;

grant select, update on public.profiles to anon, authenticated;
grant select, insert, update, delete on public.categories to anon, authenticated;
grant select, insert, update, delete on public.clients to anon, authenticated;
grant select, insert, update, delete on public.client_transactions to anon, authenticated;
grant select, insert, update, delete on public.income_expenses to anon, authenticated;
grant select, insert, update, delete on public.reminders to anon, authenticated;
grant select on public.client_balances to anon, authenticated;

alter default privileges in schema public
  grant select, insert, update, delete on tables to anon, authenticated;
