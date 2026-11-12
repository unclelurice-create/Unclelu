-- =====================================================================
-- Tes RLS, trigger, dan RPC Satu Pintu.
-- Jalankan di SQL Editor. Semua perubahan di-rollback otomatis (exception di akhir).
-- Hasil: pesan "SEMUA TES LULUS" berarti lulus; pesan lain = tes yang gagal.
-- =====================================================================
do $$
declare
  ow uuid := gen_random_uuid(); st uuid := gen_random_uuid(); ow2 uuid := gen_random_uuid();
  s uuid; s2 uuid; m1 uuid; m2 uuid; eg uuid; b1 uuid; o public.orders; n int;
begin
  -- Toko A (owner + staff), Toko B (owner lain)
  insert into auth.users(id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  values (ow, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','tes-owner@example.com','{"store_name":"Toko A"}', now(), now()),
         (ow2,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','tes-owner2@example.com','{"store_name":"Toko B"}', now(), now()),
         (st, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','tes-staff@example.com','{"invited":"true"}', now(), now());
  select store_id into s from public.profiles where id = ow;
  select store_id into s2 from public.profiles where id = ow2;
  insert into public.profiles(id, full_name, email, role, store_id) values (st, 'Staff', 'tes-staff@example.com', 'staff', s);
  update public.stores set is_website_store = (id = s) where id in (s, s2);

  -- ===== sebagai OWNER toko A
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', ow, 'role','authenticated')::text, true);
  insert into public.menu_items(name, price) values ('Salted Egg', 25000) returning id into m1;
  insert into public.menu_items(name, price) values ('Blackpepper', 25000) returning id into m2;
  insert into public.menu_items(name, price, category) values ('Egg', 5000, 'additional') returning id into eg;
  insert into public.batches(name, start_date, end_date) values ('B1', current_date, current_date + 6) returning id into b1;
  insert into public.operating_costs(name, category, amount, batch_id) values ('Gas', 'gas_listrik', 50000, b1);

  -- batch tidak boleh bertabrakan
  begin
    insert into public.batches(name, start_date, end_date) values ('B2', current_date + 3, current_date + 9);
    raise exception 'GAGAL: batch bertabrakan diterima';
  exception when exclusion_violation then null; end;

  o := public.create_order('Budi', current_date, null,
        jsonb_build_array(jsonb_build_object('menu_item_id', m1, 'qty', 2,
          'additions', jsonb_build_array(jsonb_build_object('menu_item_id', eg, 'qty', 1)))), 'lunas', 'qris');
  if o.total <> 55000 then raise exception 'GAGAL: total order % (harus 55000)', o.total; end if;
  if o.batch_id <> b1 then raise exception 'GAGAL: batch_id tidak terisi'; end if;

  -- edit order menghitung ulang total, kode tetap
  o := public.update_order(o.id, 'Budi', current_date, null,
        jsonb_build_array(jsonb_build_object('menu_item_id', m2, 'qty', 1)), 'belum', null);
  if o.total <> 25000 then raise exception 'GAGAL: total setelah edit %', o.total; end if;

  -- batch ditutup menolak order baru & edit
  update public.batches set status = 'tutup' where id = b1;
  begin
    perform public.create_order('X', current_date, null, jsonb_build_array(jsonb_build_object('menu_item_id', m1, 'qty', 1)), 'belum', null);
    raise exception 'GAGAL: batch ditutup menerima order';
  exception when others then if sqlerrm not like '%BATCH_DITUTUP%' then raise; end if; end;
  begin
    perform public.update_order(o.id, 'X', current_date, null, jsonb_build_array(jsonb_build_object('menu_item_id', m1, 'qty', 1)), 'belum', null);
    raise exception 'GAGAL: batch ditutup menerima edit';
  exception when others then if sqlerrm not like '%BATCH_DITUTUP%' then raise; end if; end;

  -- batch berisi order tidak bisa dihapus
  begin
    delete from public.batches where id = b1;
    raise exception 'GAGAL: batch berisi order terhapus';
  exception when others then if sqlerrm not like '%BATCH_ADA_ORDER%' then raise; end if; end;

  -- owner toko website boleh menutup tanggal
  insert into public.closed_dates(tanggal, catatan) values (current_date + 2, 'Libur');

  -- ===== sebagai STAFF toko A
  perform set_config('request.jwt.claims', json_build_object('sub', st, 'role','authenticated')::text, true);
  select count(*) into n from public.operating_costs;
  if n <> 0 then raise exception 'GAGAL: staff bisa membaca operating_costs'; end if;
  begin
    perform * from public.report_by_batch(current_date - 30, current_date + 30);
    raise exception 'GAGAL: staff bisa membaca laporan';
  exception when others then if sqlerrm not like '%KHUSUS_OWNER%' then raise; end if; end;
  update public.stores set name = 'Diretas' where id = s;
  if (select name from public.stores where id = s) = 'Diretas' then raise exception 'GAGAL: staff bisa mengubah nama toko'; end if;
  begin
    insert into public.menu_items(name, price) values ('Ilegal', 1);
    raise exception 'GAGAL: staff bisa menambah menu';
  exception when insufficient_privilege then null; end;
  update public.profiles set role = 'owner' where id = st;
  if (select role from public.profiles where id = st) <> 'staff' then raise exception 'GAGAL: staff bisa mengubah role'; end if;
  select count(*) into n from public.orders;
  if n <> 1 then raise exception 'GAGAL: staff tidak melihat order tokonya'; end if;

  -- ===== sebagai OWNER toko B: data toko A tidak terlihat
  perform set_config('request.jwt.claims', json_build_object('sub', ow2, 'role','authenticated')::text, true);
  select count(*) into n from public.orders;
  if n <> 0 then raise exception 'GAGAL: toko lain bisa melihat order'; end if;
  select count(*) into n from public.menu_items;
  if n <> 0 then raise exception 'GAGAL: toko lain bisa melihat menu'; end if;
  begin
    insert into public.closed_dates(tanggal) values (current_date + 5);
    raise exception 'GAGAL: owner toko non-website bisa menutup tanggal';
  exception when insufficient_privilege then null; end;

  -- ===== sebagai ANON (website)
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
  begin
    insert into public.closed_dates(tanggal) values (current_date + 6);
    raise exception 'GAGAL: anon bisa menulis closed_dates';
  exception when insufficient_privilege then null; end;
  begin
    select count(*) into n from public.web_orders;
    raise exception 'GAGAL: anon bisa membaca web_orders';
  exception when insufficient_privilege then null; end;
  -- order website di tanggal tutup ditolak trigger
  begin
    insert into public.web_orders(nama, phone, tanggal) values ('A', '1', current_date + 2);
    raise exception 'GAGAL: order website di hari tutup diterima';
  exception when others then if sqlerrm not like '%HARI_TUTUP%' then raise; end if; end;
  -- tanggal buka diterima
  insert into public.web_orders(nama, phone, tanggal) values ('A', '1', current_date + 3);
  select count(*) into n from public.closed_dates;
  if n <> 1 then raise exception 'GAGAL: anon tidak bisa membaca closed_dates'; end if;

  raise exception 'SEMUA TES LULUS';
end $$;
