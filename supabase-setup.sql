-- Create the administrator in Supabase Auth before adding their UUID below.
-- Public customers can insert validated requests, but RLS never lets them read orders.
-- Add CAPTCHA or a server-side rate limit before a high-traffic public launch.

create table if not exists public.order_requests (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null check (char_length(trim(customer_name)) between 2 and 120),
  phone text not null check (phone ~ '^\+?[0-9]{8,15}$'),
  city text not null check (char_length(trim(city)) between 2 and 100),
  district text not null check (char_length(trim(district)) between 2 and 120),
  street text not null default '' check (char_length(street) <= 200),
  building text not null default '' check (char_length(building) <= 100),
  liters integer not null check (liters between 1 and 5000),
  notes text not null default '' check (char_length(notes) <= 500),
  status text not null default 'new'
    check (status in ('new', 'accepted', 'preparing', 'delivered', 'cancelled')),
  created_at timestamptz not null default now()
);

alter table public.order_requests
  add column if not exists latitude double precision
  constraint order_requests_latitude_check check (latitude is null or (latitude between -90 and 90));

alter table public.order_requests
  add column if not exists longitude double precision
  constraint order_requests_longitude_check check (longitude is null or (longitude between -180 and 180));

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade
);

alter table public.order_requests enable row level security;
alter table public.admin_users enable row level security;

create or replace function public.is_water_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = auth.uid()
  );
$$;

revoke all on function public.is_water_admin() from public;
grant execute on function public.is_water_admin() to authenticated;

drop policy if exists "Public can submit new requests" on public.order_requests;
create policy "Public can submit new requests"
  on public.order_requests
  for insert
  to anon, authenticated
  with check (status = 'new');

drop policy if exists "Admins can read requests" on public.order_requests;
create policy "Admins can read requests"
  on public.order_requests
  for select
  to authenticated
  using (public.is_water_admin());

drop policy if exists "Admins can update request status" on public.order_requests;
create policy "Admins can update request status"
  on public.order_requests
  for update
  to authenticated
  using (public.is_water_admin())
  with check (public.is_water_admin());

drop policy if exists "Admins can verify their own membership" on public.admin_users;
create policy "Admins can verify their own membership"
  on public.admin_users
  for select
  to authenticated
  using (user_id = auth.uid());

revoke all on public.order_requests from anon, authenticated;
grant insert (customer_name, phone, city, district, street, building, liters, notes, latitude, longitude)
  on public.order_requests to anon, authenticated;
grant select on public.order_requests to authenticated;
grant update (status) on public.order_requests to authenticated;

revoke all on public.admin_users from anon, authenticated;
grant select (user_id) on public.admin_users to authenticated;

-- After creating the administrator in Supabase Auth, add their UUID here:
-- insert into public.admin_users (user_id) values ('ADMIN_USER_UUID');
-- Or replace the email below and run this query:
-- insert into public.admin_users (user_id)
-- select id from auth.users where email = 'admin@example.com'
-- on conflict do nothing;
