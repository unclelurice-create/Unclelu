-- =====================================================================
-- Satu Pintu - skema utama (multi-toko) untuk Supabase
-- Aman dijalankan di project yang sudah berisi supabase-hari-buka-tutup.sql
-- =====================================================================
create extension if not exists btree_gist;
create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1. Toko & profil
-- ---------------------------------------------------------------------
create table if not exists public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  name text not null default 'Toko Saya'
);
alter table public.stores add column if not exists photo_url text;
-- Toko yang hari buka/tutup & order website-nya dikelola (website Netlify)
alter table public.stores add column if not exists is_website_store boolean not null default false;
alter table public.stores add column if not exists created_at timestamptz not null default now();

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  phone text,
  role text not null default 'staff' check (role in ('owner','staff')),
  store_id uuid not null references public.stores(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists profiles_store_idx on public.profiles(store_id);

create or replace function public.my_store_id()
returns uuid language sql stable security definer set search_path = public as $$
  select store_id from public.profiles where id = auth.uid();
$$;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'owner' from public.profiles where id = auth.uid()), false);
$$;

-- Dipakai tabel website (closed_dates, closed_weekdays, web_orders):
-- hanya Owner/Admin dari toko website yang boleh mengubah.
create or replace function public.is_store_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p join public.stores s on s.id = p.store_id
    where p.id = auth.uid() and p.role = 'owner' and s.is_website_store
  );
$$;

revoke all on function public.my_store_id(), public.is_owner(), public.is_store_owner() from public;
grant execute on function public.my_store_id(), public.is_owner(), public.is_store_owner() to authenticated;

-- Pendaftaran lewat layar "Daftar akun" = toko baru + profil owner.
-- Staff dibuat oleh Edge Function invite_staff (metadata invited=true), jadi dilewati di sini.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_store uuid; v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if coalesce(v_meta->>'invited','false') = 'true' then
    return new;
  end if;
  insert into public.stores(owner_id, name, is_website_store)
  values (new.id,
          coalesce(nullif(trim(v_meta->>'store_name'),''), 'Toko Saya'),
          lower(new.email) = 'unclelurice@gmail.com'
            and not exists (select 1 from public.stores where is_website_store))
  returning id into v_store;
  insert into public.profiles(id, full_name, email, phone, role, store_id)
  values (new.id, coalesce(nullif(trim(v_meta->>'store_name'),''), split_part(new.email,'@',1)),
          new.email, v_meta->>'phone', 'owner', v_store);
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists trg_auto_assign_store_owner on auth.users;
drop function if exists public.auto_assign_store_owner();
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Toko lama tanpa profil (dibuat sebelum migrasi ini) -> buatkan profil owner
insert into public.profiles(id, full_name, email, role, store_id)
select s.owner_id, s.name, u.email, 'owner', s.id
from public.stores s join auth.users u on u.id = s.owner_id
where not exists (select 1 from public.profiles p where p.id = s.owner_id);

-- ---------------------------------------------------------------------
-- 2. Menu, batch, order
-- ---------------------------------------------------------------------
create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade default public.my_store_id(),
  name text not null,
  price integer not null check (price >= 0),
  category text not null default 'menu' check (category in ('menu','additional')),
  is_alacarte boolean not null default false,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists menu_items_store_idx on public.menu_items(store_id, active);

create table if not exists public.batches (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade default public.my_store_id(),
  name text not null,
  start_date date not null,
  end_date date not null,
  status text not null default 'buka' check (status in ('buka','tutup')),
  created_at timestamptz not null default now(),
  check (end_date >= start_date),
  constraint batches_no_overlap exclude using gist
    (store_id with =, daterange(start_date, end_date, '[]') with &&)
);

create sequence if not exists public.order_code_seq;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade default public.my_store_id(),
  code text not null unique default ('ORD-' || lpad(nextval('public.order_code_seq')::text, 5, '0')),
  order_date date not null,
  customer_name text not null default 'Pelanggan umum',
  status text not null default 'diproses' check (status in ('diproses','selesai','batal')),
  payment_status text not null default 'belum' check (payment_status in ('lunas','belum')),
  payment_method text check (payment_method in ('tunai','transfer','qris')),
  paid_at timestamptz,
  note text,
  total integer not null default 0,
  batch_id uuid references public.batches(id) on delete restrict,
  web_order_id bigint references public.web_orders(id) on delete set null,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  check ((payment_status = 'lunas') = (payment_method is not null))
);
create index if not exists orders_store_date_idx on public.orders(store_id, order_date);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id) on delete set null,
  name_snapshot text not null,
  price integer not null,
  qty integer not null check (qty > 0),
  parent_item_id uuid references public.order_items(id) on delete cascade,
  flavor_item_id uuid references public.menu_items(id) on delete set null,
  category text not null default 'menu' check (category in ('menu','additional'))
);
create index if not exists order_items_order_idx on public.order_items(order_id);

-- ---------------------------------------------------------------------
-- 3. Belanja, biaya, resep
-- ---------------------------------------------------------------------
create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade default public.my_store_id(),
  batch_id uuid references public.batches(id) on delete set null,
  name text not null,
  qty numeric(12,3) not null check (qty > 0),
  unit text not null check (unit in ('kg','liter','pcs','pack')),
  unit_price integer not null check (unit_price >= 0),
  pack_content numeric(12,3),
  pack_unit text check (pack_unit in ('pcs','gram','ml','kg','liter')),
  purchase_date date not null default current_date,
  created_at timestamptz not null default now(),
  check (unit <> 'pack' or (pack_content > 0 and pack_unit is not null))
);
create index if not exists purchase_items_store_idx on public.purchase_items(store_id, batch_id);

create table if not exists public.operating_costs (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade default public.my_store_id(),
  batch_id uuid references public.batches(id) on delete set null,
  name text not null,
  category text not null check (category in ('kemasan','gas_listrik','gaji','sewa','lainnya')),
  amount integer not null check (amount >= 0),
  cost_date date not null default current_date,
  created_at timestamptz not null default now()
);

create table if not exists public.menu_recipes (
  menu_item_id uuid primary key references public.menu_items(id) on delete cascade,
  base_portions integer not null default 25 check (base_portions > 0)
);

create table if not exists public.recipe_items (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references public.menu_items(id) on delete cascade,
  name text not null,
  qty numeric(12,3) not null check (qty > 0),
  unit text not null check (unit in ('kg','gram','liter','ml','pcs','pack')),
  unit_price integer not null check (unit_price >= 0),
  pack_content numeric(12,3),
  pack_unit text check (pack_unit in ('pcs','gram','ml','kg','liter')),
  created_at timestamptz not null default now(),
  check (unit <> 'pack' or (pack_content > 0 and pack_unit is not null))
);

-- ---------------------------------------------------------------------
-- 4. RLS
-- ---------------------------------------------------------------------
alter table public.stores          enable row level security;
alter table public.profiles        enable row level security;
alter table public.menu_items      enable row level security;
alter table public.batches         enable row level security;
alter table public.orders          enable row level security;
alter table public.order_items     enable row level security;
alter table public.purchase_items  enable row level security;
alter table public.operating_costs enable row level security;
alter table public.menu_recipes    enable row level security;
alter table public.recipe_items    enable row level security;

drop policy if exists "owner baca toko" on public.stores;
drop policy if exists "anggota baca toko" on public.stores;
create policy "anggota baca toko" on public.stores for select to authenticated
  using (id = public.my_store_id());
drop policy if exists "owner ubah toko" on public.stores;
create policy "owner ubah toko" on public.stores for update to authenticated
  using (id = public.my_store_id() and public.is_owner())
  with check (id = public.my_store_id() and public.is_owner());

drop policy if exists "anggota baca profil" on public.profiles;
create policy "anggota baca profil" on public.profiles for select to authenticated
  using (store_id = public.my_store_id());
drop policy if exists "owner ubah profil" on public.profiles;
create policy "owner ubah profil" on public.profiles for update to authenticated
  using (store_id = public.my_store_id() and public.is_owner() and id <> auth.uid())
  with check (store_id = public.my_store_id());

-- Menu & batch: semua anggota baca, owner tulis
do $$ declare t text; begin
  foreach t in array array['menu_items','batches'] loop
    execute format('drop policy if exists "anggota baca" on public.%I', t);
    execute format('create policy "anggota baca" on public.%I for select to authenticated using (store_id = public.my_store_id())', t);
    execute format('drop policy if exists "owner tulis" on public.%I', t);
    execute format('create policy "owner tulis" on public.%I for all to authenticated using (store_id = public.my_store_id() and public.is_owner()) with check (store_id = public.my_store_id() and public.is_owner())', t);
  end loop;
end $$;

-- Order & belanja: semua anggota baca/tulis di tokonya
do $$ declare t text; begin
  foreach t in array array['orders','purchase_items'] loop
    execute format('drop policy if exists "anggota kelola" on public.%I', t);
    execute format('create policy "anggota kelola" on public.%I for all to authenticated using (store_id = public.my_store_id()) with check (store_id = public.my_store_id())', t);
  end loop;
end $$;

drop policy if exists "anggota kelola" on public.order_items;
create policy "anggota kelola" on public.order_items for all to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and o.store_id = public.my_store_id()))
  with check (exists (select 1 from public.orders o where o.id = order_id and o.store_id = public.my_store_id()));

-- Biaya operasional & resep: hanya owner
drop policy if exists "owner kelola" on public.operating_costs;
create policy "owner kelola" on public.operating_costs for all to authenticated
  using (store_id = public.my_store_id() and public.is_owner())
  with check (store_id = public.my_store_id() and public.is_owner());

do $$ declare t text; begin
  foreach t in array array['menu_recipes','recipe_items'] loop
    execute format('drop policy if exists "owner kelola" on public.%I', t);
    execute format('create policy "owner kelola" on public.%I for all to authenticated using (public.is_owner() and exists (select 1 from public.menu_items m where m.id = menu_item_id and m.store_id = public.my_store_id())) with check (public.is_owner() and exists (select 1 from public.menu_items m where m.id = menu_item_id and m.store_id = public.my_store_id()))', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 5. Order RPC
-- items: [{ "menu_item_id": uuid, "qty": int,
--           "flavors":   [{ "menu_item_id": uuid, "qty": int }],   -- hanya menu à la carte
--           "additions": [{ "menu_item_id": uuid, "qty": int }] }]
-- ---------------------------------------------------------------------
create or replace function public._batch_for(p_store uuid, p_date date)
returns public.batches language sql stable security definer set search_path = public as $$
  select * from public.batches where store_id = p_store and p_date between start_date and end_date limit 1;
$$;
revoke all on function public._batch_for(uuid, date) from public, anon, authenticated;

create or replace function public._write_order_items(p_order uuid, p_store uuid, p_items jsonb, p_old jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare it jsonb; fl jsonb; ad jsonb; m public.menu_items; f public.menu_items; a public.menu_items;
  v_parent uuid; v_total integer := 0; v_name text; v_price integer; v_qty integer; v_old jsonb;
begin
  for it in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
    select * into m from public.menu_items where id = (it->>'menu_item_id')::uuid and store_id = p_store and category = 'menu';
    if not found then raise exception 'MENU_TIDAK_DITEMUKAN' using errcode = 'P0001'; end if;
    v_parent := null;
    if m.is_alacarte then
      for fl in select * from jsonb_array_elements(coalesce(it->'flavors','[]'::jsonb)) loop
        v_qty := (fl->>'qty')::int;
        continue when coalesce(v_qty,0) <= 0;
        select * into f from public.menu_items where id = (fl->>'menu_item_id')::uuid and store_id = p_store and category = 'menu' and not is_alacarte;
        if not found then raise exception 'RASA_TIDAK_DITEMUKAN' using errcode = 'P0001'; end if;
        v_name := m.name || ' – ' || f.name; v_price := m.price;
        -- item yang tidak diubah tetap memakai snapshot lama
        select o into v_old from jsonb_array_elements(coalesce(p_old,'[]'::jsonb)) o
          where o->>'menu_item_id' = m.id::text and o->>'flavor_item_id' = f.id::text and o->>'parent_item_id' is null
            and (o->>'qty')::int = v_qty limit 1;
        if v_old is not null then v_name := v_old->>'name_snapshot'; v_price := (v_old->>'price')::int; end if;
        insert into public.order_items(order_id, menu_item_id, flavor_item_id, name_snapshot, price, qty, category)
          values (p_order, m.id, f.id, v_name, v_price, v_qty, 'menu') returning id into v_parent;
        v_total := v_total + v_price * v_qty;
        v_old := null;
      end loop;
    else
      v_qty := (it->>'qty')::int;
      if coalesce(v_qty,0) > 0 then
        v_name := m.name; v_price := m.price;
        select o into v_old from jsonb_array_elements(coalesce(p_old,'[]'::jsonb)) o
          where o->>'menu_item_id' = m.id::text and o->>'flavor_item_id' is null and o->>'parent_item_id' is null
            and (o->>'qty')::int = v_qty limit 1;
        if v_old is not null then v_name := v_old->>'name_snapshot'; v_price := (v_old->>'price')::int; end if;
        insert into public.order_items(order_id, menu_item_id, name_snapshot, price, qty, category)
          values (p_order, m.id, v_name, v_price, v_qty, 'menu') returning id into v_parent;
        v_total := v_total + v_price * v_qty;
        v_old := null;
      end if;
    end if;
    continue when v_parent is null;
    for ad in select * from jsonb_array_elements(coalesce(it->'additions','[]'::jsonb)) loop
      v_qty := (ad->>'qty')::int;
      continue when coalesce(v_qty,0) <= 0;
      select * into a from public.menu_items where id = (ad->>'menu_item_id')::uuid and store_id = p_store and category = 'additional';
      if not found then raise exception 'ADDITIONAL_TIDAK_DITEMUKAN' using errcode = 'P0001'; end if;
      v_name := a.name; v_price := a.price;
      select o into v_old from jsonb_array_elements(coalesce(p_old,'[]'::jsonb)) o
        where o->>'menu_item_id' = a.id::text and o->>'parent_menu_item_id' = m.id::text and (o->>'qty')::int = v_qty limit 1;
      if v_old is not null then v_name := v_old->>'name_snapshot'; v_price := (v_old->>'price')::int; end if;
      insert into public.order_items(order_id, menu_item_id, name_snapshot, price, qty, parent_item_id, category)
        values (p_order, a.id, v_name, v_price, v_qty, v_parent, 'additional');
      v_total := v_total + v_price * v_qty;
      v_old := null;
    end loop;
  end loop;
  if v_total <= 0 then raise exception 'ORDER_KOSONG' using errcode = 'P0001'; end if;
  return v_total;
end;
$$;
revoke all on function public._write_order_items(uuid, uuid, jsonb, jsonb) from public, anon, authenticated;

create or replace function public.create_order(customer text, order_date date, note text, items jsonb,
  payment_status text default 'belum', payment_method text default null)
returns public.orders language plpgsql security definer set search_path = public as $$
declare v_store uuid := public.my_store_id(); b public.batches; o public.orders; v_total integer;
begin
  if v_store is null then raise exception 'TIDAK_ADA_AKSES' using errcode = '42501'; end if;
  b := public._batch_for(v_store, order_date);
  if b.id is null then raise exception 'TANPA_BATCH' using errcode = 'P0001'; end if;
  if b.status = 'tutup' then raise exception 'BATCH_DITUTUP' using errcode = 'P0001'; end if;
  insert into public.orders(store_id, order_date, customer_name, note, batch_id, payment_status, payment_method, paid_at)
  values (v_store, order_date, coalesce(nullif(trim(customer),''),'Pelanggan umum'), nullif(trim(note),''), b.id,
          payment_status, case when payment_status = 'lunas' then payment_method end,
          case when payment_status = 'lunas' then now() end)
  returning * into o;
  v_total := public._write_order_items(o.id, v_store, items, null);
  update public.orders set total = v_total where id = o.id returning * into o;
  return o;
end;
$$;

create or replace function public.update_order(order_id uuid, customer text, order_date date, note text, items jsonb,
  payment_status text default 'belum', payment_method text default null)
returns public.orders language plpgsql security definer set search_path = public as $$
declare v_store uuid := public.my_store_id(); b public.batches; o public.orders; v_total integer; v_old jsonb;
begin
  select * into o from public.orders where id = update_order.order_id and store_id = v_store for update;
  if not found then raise exception 'ORDER_TIDAK_DITEMUKAN' using errcode = 'P0001'; end if;
  if exists (select 1 from public.batches where id = o.batch_id and status = 'tutup') then
    raise exception 'BATCH_DITUTUP' using errcode = 'P0001'; end if;
  b := public._batch_for(v_store, update_order.order_date);
  if b.id is null then raise exception 'TANPA_BATCH' using errcode = 'P0001'; end if;
  if b.status = 'tutup' then raise exception 'BATCH_DITUTUP' using errcode = 'P0001'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
      'menu_item_id', i.menu_item_id, 'flavor_item_id', i.flavor_item_id,
      'parent_item_id', i.parent_item_id, 'parent_menu_item_id', p.menu_item_id,
      'name_snapshot', i.name_snapshot, 'price', i.price, 'qty', i.qty)), '[]'::jsonb)
    into v_old
    from public.order_items i left join public.order_items p on p.id = i.parent_item_id
    where i.order_id = o.id;
  delete from public.order_items where order_items.order_id = o.id;
  v_total := public._write_order_items(o.id, v_store, items, v_old);
  update public.orders set
    order_date = update_order.order_date, batch_id = b.id,
    customer_name = coalesce(nullif(trim(customer),''),'Pelanggan umum'),
    note = nullif(trim(update_order.note),''),
    payment_status = update_order.payment_status,
    payment_method = case when update_order.payment_status = 'lunas' then update_order.payment_method end,
    paid_at = case when update_order.payment_status = 'lunas' then coalesce(orders.paid_at, now()) end,
    total = v_total
  where id = o.id returning * into o;
  return o;
end;
$$;

-- Ubah status + pembayaran dari bottom sheet
create or replace function public.set_order_status(order_id uuid, status text, payment_status text, payment_method text default null)
returns public.orders language plpgsql security definer set search_path = public as $$
declare o public.orders;
begin
  update public.orders set
    status = set_order_status.status,
    payment_status = set_order_status.payment_status,
    payment_method = case when set_order_status.payment_status = 'lunas' then set_order_status.payment_method end,
    paid_at = case when set_order_status.payment_status = 'lunas' then coalesce(orders.paid_at, now()) end
  where id = set_order_status.order_id and store_id = public.my_store_id()
  returning * into o;
  if not found then raise exception 'ORDER_TIDAK_DITEMUKAN' using errcode = 'P0001'; end if;
  return o;
end;
$$;

-- Batch berisi order tidak bisa dihapus (pesan jelas, selain FK restrict)
create or replace function public.block_batch_delete()
returns trigger language plpgsql as $$
begin
  if exists (select 1 from public.orders where batch_id = old.id) then
    raise exception 'BATCH_ADA_ORDER' using errcode = 'P0001';
  end if;
  return old;
end;
$$;
drop trigger if exists trg_block_batch_delete on public.batches;
create trigger trg_block_batch_delete before delete on public.batches
  for each row execute function public.block_batch_delete();

-- ---------------------------------------------------------------------
-- 6. Laporan (RPC)
-- ---------------------------------------------------------------------
-- Penjualan per menu (Dashboard, Owner & Staff). Additional digabung jadi satu.
create or replace function public.sales_by_menu(p_start date, p_end date)
returns table(menu_item_id uuid, name text, category text, amount bigint)
language sql stable security definer set search_path = public as $$
  select case when i.category = 'additional' then null else i.menu_item_id end,
         case when i.category = 'additional' then 'Additional' else coalesce(m.name, min(i.name_snapshot)) end,
         i.category, sum(i.price * i.qty)::bigint
  from public.order_items i
  join public.orders o on o.id = i.order_id
  left join public.menu_items m on m.id = i.menu_item_id
  where o.store_id = public.my_store_id() and o.status <> 'batal'
    and o.order_date between p_start and p_end
  group by 1, i.category, m.name;
$$;

-- Ringkasan harian (tren) - khusus owner
create or replace function public.report_daily(p_start date, p_end date)
returns table(day date, sales bigint, purchases bigint, costs bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'KHUSUS_OWNER' using errcode = '42501'; end if;
  return query
  select d::date,
    coalesce((select sum(total) from public.orders where store_id = public.my_store_id() and status <> 'batal' and order_date = d::date),0)::bigint,
    coalesce((select sum(round(qty*unit_price)) from public.purchase_items where store_id = public.my_store_id() and purchase_date = d::date),0)::bigint,
    coalesce((select sum(amount) from public.operating_costs where store_id = public.my_store_id() and cost_date = d::date),0)::bigint
  from generate_series(p_start, p_end, interval '1 day') d;
end;
$$;

-- Per batch (yang beririsan dengan periode) - khusus owner
create or replace function public.report_by_batch(p_start date, p_end date)
returns table(batch_id uuid, name text, start_date date, end_date date, status text,
              sales bigint, order_count bigint, purchases bigint, costs bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'KHUSUS_OWNER' using errcode = '42501'; end if;
  return query
  select b.id, b.name, b.start_date, b.end_date, b.status,
    coalesce((select sum(o.total) from public.orders o where o.batch_id = b.id and o.status <> 'batal'
              and o.order_date between p_start and p_end),0)::bigint,
    coalesce((select count(*) from public.orders o where o.batch_id = b.id and o.status <> 'batal'
              and o.order_date between p_start and p_end),0)::bigint,
    coalesce((select sum(round(pi.qty*pi.unit_price)) from public.purchase_items pi where pi.batch_id = b.id),0)::bigint,
    coalesce((select sum(c.amount) from public.operating_costs c where c.batch_id = b.id),0)::bigint
  from public.batches b
  where b.store_id = public.my_store_id() and b.start_date <= p_end and b.end_date >= p_start
  order by b.start_date;
end;
$$;

revoke all on function public.create_order(text,date,text,jsonb,text,text), public.update_order(uuid,text,date,text,jsonb,text,text),
  public.set_order_status(uuid,text,text,text), public.sales_by_menu(date,date), public.report_daily(date,date),
  public.report_by_batch(date,date) from public, anon;
grant execute on function public.create_order(text,date,text,jsonb,text,text), public.update_order(uuid,text,date,text,jsonb,text,text),
  public.set_order_status(uuid,text,text,text), public.sales_by_menu(date,date), public.report_daily(date,date),
  public.report_by_batch(date,date) to authenticated;

-- ---------------------------------------------------------------------
-- 7. Storage: foto toko  ({store_id}/logo.jpg)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public) values ('store-photos','store-photos', true)
on conflict (id) do nothing;

drop policy if exists "foto toko publik" on storage.objects;
create policy "foto toko publik" on storage.objects for select using (bucket_id = 'store-photos');
drop policy if exists "owner unggah foto" on storage.objects;
create policy "owner unggah foto" on storage.objects for insert to authenticated
  with check (bucket_id = 'store-photos' and public.is_owner() and (storage.foldername(name))[1] = public.my_store_id()::text);
drop policy if exists "owner ganti foto" on storage.objects;
create policy "owner ganti foto" on storage.objects for update to authenticated
  using (bucket_id = 'store-photos' and public.is_owner() and (storage.foldername(name))[1] = public.my_store_id()::text);
drop policy if exists "owner hapus foto" on storage.objects;
create policy "owner hapus foto" on storage.objects for delete to authenticated
  using (bucket_id = 'store-photos' and public.is_owner() and (storage.foldername(name))[1] = public.my_store_id()::text);

-- ---------------------------------------------------------------------
-- 8. Pengerasan
-- ---------------------------------------------------------------------
alter function public.block_batch_delete() set search_path = public;
revoke all on function public.block_closed_web_order() from public, anon, authenticated;
revoke all on function public.block_batch_delete() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 9. Hak akses tabel untuk role API (RLS tetap membatasi baris)
--    TRUNCATE melewati RLS, jadi dicabut.
-- ---------------------------------------------------------------------
revoke truncate, references, trigger on all tables in schema public from anon, authenticated;
grant select on public.closed_dates, public.closed_weekdays to anon, authenticated;
grant insert on public.web_orders to anon, authenticated;
grant insert, update, delete on public.closed_dates, public.closed_weekdays to authenticated;
grant select, update, delete on public.web_orders to authenticated;
grant select, update on public.stores to authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.menu_items, public.batches, public.orders, public.order_items,
  public.purchase_items, public.operating_costs, public.menu_recipes, public.recipe_items to authenticated;
grant usage on sequence public.order_code_seq to authenticated;
