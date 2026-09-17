-- Operational schema for Sky Bedsheet.
-- Run this in the Supabase SQL Editor before enabling the frontend persistence code.

create extension if not exists pgcrypto;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  area text not null,
  customer_name text not null,
  phone text not null,
  address text not null,
  location_url text,
  amount numeric(12,2) not null default 0,
  payment_method text not null default 'Cash',
  payment_status text not null default 'Unpaid',
  notes text not null default '',
  order_date date not null default current_date,
  delivery_date date,
  delivery_time text,
  status text not null default 'pending' check (status in ('pending','out_for_delivery','awaiting_confirmation','confirmed','cancelled','failed')),
  assigned_user_id uuid,
  created_by uuid,
  delivered_at timestamptz,
  confirmed_at timestamptz,
  amount_collected numeric(12,2),
  remarks_delivery text,
  proof_image boolean not null default false,
  rate_per_set numeric(12,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  design text not null,
  size text not null,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default now()
);

create table if not exists public.order_activity (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  actor_id uuid,
  action text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.stock (
  design text not null,
  size text not null check (size in ('Single','Supersingle / Double','Queen','King')),
  quantity integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key (design, size)
);

create table if not exists public.payouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  period_start date,
  period_end date,
  amount numeric(12,2) not null check (amount >= 0),
  payment_date date not null default current_date,
  reference text not null default '',
  notes text not null default '',
  created_by uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_by uuid,
  updated_at timestamptz not null default now()
);

create or replace function public.is_active_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and status = 'active'
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and status = 'active' and role = 'admin'
  );
$$;

create or replace function public.is_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and status = 'active' and role in ('admin','manager')
  );
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists orders_touch_updated_at on public.orders;
create trigger orders_touch_updated_at before update on public.orders
for each row execute function public.touch_updated_at();

drop trigger if exists stock_touch_updated_at on public.stock;
create trigger stock_touch_updated_at before update on public.stock
for each row execute function public.touch_updated_at();

drop trigger if exists settings_touch_updated_at on public.app_settings;
create trigger settings_touch_updated_at before update on public.app_settings
for each row execute function public.touch_updated_at();

alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_activity enable row level security;
alter table public.stock enable row level security;
alter table public.payouts enable row level security;
alter table public.app_settings enable row level security;

drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders for select to authenticated using (public.is_active_staff());
drop policy if exists orders_write on public.orders;
create policy orders_write on public.orders for all to authenticated using (public.is_manager() or assigned_user_id = auth.uid()) with check (public.is_manager() or assigned_user_id = auth.uid());

drop policy if exists order_items_read on public.order_items;
create policy order_items_read on public.order_items for select to authenticated using (public.is_active_staff());
drop policy if exists order_items_write on public.order_items;
create policy order_items_write on public.order_items for all to authenticated using (public.is_manager()) with check (public.is_manager());

drop policy if exists order_activity_read on public.order_activity;
create policy order_activity_read on public.order_activity for select to authenticated using (public.is_active_staff());
drop policy if exists order_activity_write on public.order_activity;
create policy order_activity_write on public.order_activity for insert to authenticated with check (public.is_active_staff());

drop policy if exists stock_read on public.stock;
create policy stock_read on public.stock for select to authenticated using (public.is_active_staff());
drop policy if exists stock_write on public.stock;
create policy stock_write on public.stock for all to authenticated using (public.is_admin() or public.is_active_staff()) with check (public.is_admin() or public.is_active_staff());

drop policy if exists payouts_read on public.payouts;
create policy payouts_read on public.payouts for select to authenticated using (public.is_active_staff());
drop policy if exists payouts_write on public.payouts;
create policy payouts_write on public.payouts for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists settings_read on public.app_settings;
create policy settings_read on public.app_settings for select to authenticated using (public.is_active_staff());
drop policy if exists settings_write on public.app_settings;
create policy settings_write on public.app_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());
