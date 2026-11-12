-- =====================================================================
-- Data contoh (studi kasus Uncle Lu Rice Bowl) - HANYA untuk demo / lokal.
-- Jangan jalankan di project produksi.
-- Pengguna demo: admin@unclelu.id / rahasia123 (Owner/Admin)
--                staff@unclelu.id / staff123   (Staff)
-- =====================================================================
do $$
declare v_admin uuid := gen_random_uuid(); v_staff uuid := gen_random_uuid(); v_store uuid;
  m_menu text[] := array['Ayam Pedas Manis Daun Jeruk','Salted Egg Chicken','Buttermilk Chicken','Blackpepper Chicken','Sweet & Sour Chicken'];
  i int; v_mon date := date_trunc('week', current_date)::date;
begin
  if exists (select 1 from auth.users where email = 'admin@unclelu.id') then return; end if;

  -- Owner: lewat trigger handle_new_user -> toko + profil owner otomatis
  insert into auth.users(instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new)
  values ('00000000-0000-0000-0000-000000000000', v_admin, 'authenticated', 'authenticated', 'admin@unclelu.id',
    crypt('rahasia123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}',
    '{"store_name":"Uncle Lu Rice Bowl","phone":"6287778203066"}', now(), now(), '', '', '', '');
  insert into auth.identities(id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_admin, v_admin::text, jsonb_build_object('sub', v_admin::text, 'email', 'admin@unclelu.id'), 'email', now(), now(), now());

  select store_id into v_store from public.profiles where id = v_admin;

  -- Staff: invited=true agar trigger tidak membuat toko baru
  insert into auth.users(instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new)
  values ('00000000-0000-0000-0000-000000000000', v_staff, 'authenticated', 'authenticated', 'staff@unclelu.id',
    crypt('staff123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}',
    '{"invited":"true","full_name":"Rina"}', now(), now(), '', '', '', '');
  insert into auth.identities(id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), v_staff, v_staff::text, jsonb_build_object('sub', v_staff::text, 'email', 'staff@unclelu.id'), 'email', now(), now(), now());
  insert into public.profiles(id, full_name, email, role, store_id) values (v_staff, 'Rina', 'staff@unclelu.id', 'staff', v_store);

  -- Menu, à la carte, additional
  for i in 1..array_length(m_menu,1) loop
    insert into public.menu_items(store_id, name, price, category, sort_order) values (v_store, m_menu[i], 25000, 'menu', i);
  end loop;
  insert into public.menu_items(store_id, name, price, category, is_alacarte, sort_order)
    values (v_store, 'Chicken Only with Sauce', 32000, 'menu', true, 6);
  insert into public.menu_items(store_id, name, price, category, sort_order) values (v_store, 'Egg', 5000, 'additional', 1);

  -- 4 batch mingguan (Senin-Minggu) mulai pekan ini
  for i in 0..3 loop
    insert into public.batches(store_id, name, start_date, end_date)
    values (v_store, 'Batch ' || lpad((i+1)::text, 2, '0'), v_mon + 7*i, v_mon + 7*i + 6);
  end loop;
end $$;
