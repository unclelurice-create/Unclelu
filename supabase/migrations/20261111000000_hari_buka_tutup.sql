-- =====================================================================
-- Hari BUKA / TUTUP + order website Uncle Lu (Netlify) - Supabase
-- Jalankan di: Supabase Dashboard > SQL Editor > New query > Run
-- Aturan: semua hari default BUKA. Hanya hari yang DITUTUP yang dicatat.
-- Tabel ini sama persis dengan yang dibaca website (index.html) dan
-- diatur dari aplikasi Uncle Lu (Pengaturan > Hari buka/tutup).
-- =====================================================================

-- 1) Tanggal tutup khusus (mis. libur, stok habis)
create table if not exists public.closed_dates (
  tanggal    date primary key,
  catatan    text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

-- 2) Hari tutup rutin tiap pekan (0 = Minggu, 1 = Senin, ... 6 = Sabtu)
create table if not exists public.closed_weekdays (
  dow        smallint primary key check (dow between 0 and 6),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

-- 3) Order yang masuk dari website (kolom sama dengan yang dikirim index.html)
create table if not exists public.web_orders (
  id          bigint generated always as identity primary key,
  nama        text not null,
  phone       text not null,
  tanggal     date not null,
  pengambilan text,
  alamat      text,
  lat         double precision,
  lng         double precision,
  catatan     text,
  items       jsonb not null default '[]'::jsonb,
  subtotal    integer not null default 0,
  ongkir      integer not null default 0,
  total       integer not null default 0,
  status      text not null default 'baru',      -- baru | diproses | selesai | batal
  created_at  timestamptz not null default now()
);

-- 0) Tabel toko minimal (dilengkapi di migrasi Satu Pintu)
create table if not exists public.stores(id uuid primary key default gen_random_uuid(), owner_id uuid references auth.users(id), name text);

-- 4) Pemilik toko = akun yang terdaftar sebagai pemilik.
--    Jika tabel public.stores (dari aplikasi Flutter) belum ada, buat dulu seperti ini:
--    create table public.stores(id uuid primary key default gen_random_uuid(), owner_id uuid references auth.users(id), name text);
create or replace function public.is_store_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.stores s where s.owner_id = auth.uid());
$$;
revoke all on function public.is_store_owner() from public;
grant execute on function public.is_store_owner() to authenticated;

-- 5) RLS
alter table public.closed_dates    enable row level security;
alter table public.closed_weekdays enable row level security;
alter table public.web_orders      enable row level security;

-- Website (anon) hanya boleh MEMBACA hari tutup (informasi publik)
drop policy if exists "baca hari tutup"  on public.closed_dates;
create policy "baca hari tutup"  on public.closed_dates    for select to anon, authenticated using (true);
drop policy if exists "baca tutup rutin" on public.closed_weekdays;
create policy "baca tutup rutin" on public.closed_weekdays for select to anon, authenticated using (true);

-- Hanya pemilik yang boleh mengubah (dari aplikasi Flutter atau Table Editor)
drop policy if exists "owner ubah hari tutup" on public.closed_dates;
create policy "owner ubah hari tutup" on public.closed_dates
  for all to authenticated using (public.is_store_owner()) with check (public.is_store_owner());
drop policy if exists "owner ubah tutup rutin" on public.closed_weekdays;
create policy "owner ubah tutup rutin" on public.closed_weekdays
  for all to authenticated using (public.is_store_owner()) with check (public.is_store_owner());

-- Website (anon) hanya boleh MENGIRIM order; membaca/mengubah hanya pemilik
drop policy if exists "website kirim order" on public.web_orders;
create policy "website kirim order" on public.web_orders for insert to anon, authenticated with check (true);
drop policy if exists "owner kelola order website" on public.web_orders;
create policy "owner kelola order website" on public.web_orders
  for all to authenticated using (public.is_store_owner()) with check (public.is_store_owner());

-- 6) Anti-bypass: order untuk hari tutup DITOLAK di server
create or replace function public.block_closed_web_order()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.closed_dates where tanggal = new.tanggal)
     or exists (select 1 from public.closed_weekdays where dow = extract(dow from new.tanggal)::smallint) then
    raise exception 'HARI_TUTUP: tanggal % sedang tutup', new.tanggal using errcode = 'P0001';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_block_closed_web_order on public.web_orders;
create trigger trg_block_closed_web_order before insert on public.web_orders
  for each row execute function public.block_closed_web_order();

-- =====================================================================
-- CARA MENUTUP / MEMBUKA (tanpa coding)
-- A) Dari aplikasi Uncle Lu: Pengaturan > Hari buka/tutup (disarankan).
-- B) Dari Supabase Table Editor:
--    closed_dates    > Insert row: tanggal = 2026-11-20, catatan = 'Libur'
--    closed_weekdays > Insert row: dow = 0  (tutup tiap hari Minggu)
--    Membuka kembali: hapus barisnya.
-- C) Lewat SQL:
--    insert into public.closed_dates(tanggal, catatan) values ('2026-11-20','Libur')
--      on conflict (tanggal) do update set catatan = excluded.catatan, updated_at = now();
--    delete from public.closed_dates where tanggal = '2026-11-20';
-- =====================================================================
