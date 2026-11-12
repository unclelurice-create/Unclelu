-- Website (anon) boleh membaca menu aktif milik toko website (menu & harga dari aplikasi)
create or replace function public.is_website_store_id(p uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_website_store from public.stores where id = p), false);
$$;
revoke all on function public.is_website_store_id(uuid) from public;
grant execute on function public.is_website_store_id(uuid) to anon, authenticated;
grant select (id, name, price, category, is_alacarte, active, sort_order, created_at, store_id) on public.menu_items to anon;
drop policy if exists "website baca menu" on public.menu_items;
create policy "website baca menu" on public.menu_items for select to anon
  using (active and public.is_website_store_id(store_id));

-- Edge Function (service_role) butuh hak tabel eksplisit di project ini
grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;
alter default privileges in schema public grant select, insert, update, delete on tables to service_role;
alter default privileges in schema public grant usage, select on sequences to service_role;

-- Deskripsi & foto menu (diatur di Kelola menu, tampil di website)
alter table public.menu_items add column if not exists description text;
alter table public.menu_items add column if not exists photo_url text;
grant select (description, photo_url) on public.menu_items to anon;

-- Staff toko website juga boleh melihat & memproses order website
create or replace function public.is_website_member()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p join public.stores s on s.id = p.store_id
                 where p.id = auth.uid() and s.is_website_store);
$$;
revoke all on function public.is_website_member() from public;
grant execute on function public.is_website_member() to authenticated;
drop policy if exists "anggota baca order website" on public.web_orders;
create policy "anggota baca order website" on public.web_orders for select to authenticated using (public.is_website_member());
drop policy if exists "anggota proses order website" on public.web_orders;
create policy "anggota proses order website" on public.web_orders for update to authenticated
  using (public.is_website_member()) with check (public.is_website_member());
