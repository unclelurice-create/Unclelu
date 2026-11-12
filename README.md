# Satu Pintu

Aplikasi mobile (Android & iOS) untuk mencatat order, belanja bahan, biaya, dan laporan laba UMKM.
Dibangun dengan Flutter (Dart 3, Material 3, Riverpod, go_router) dan Supabase (Auth, Postgres, Storage, Edge Functions).
Uncle Lu Rice Bowl dipakai sebagai studi kasus (`supabase/seed.sql`).

## Isi folder

| Folder | Isi |
|---|---|
| `lib/core` | konfigurasi, tema (5 aksen + mode gelap), router + guard role, format angka, aturan hitung (`calc.dart`), widget bersama |
| `lib/features/*` | `auth`, `dashboard`, `orders`, `purchases`, `reports`, `settings` (masing-masing `data/` + `presentation/`) |
| `lib/l10n` | teks Indonesia (`app_id.arb`, default) dan Inggris (`app_en.arb`) |
| `supabase/migrations` | skema, RLS, RPC, storage, hak akses |
| `supabase/functions` | Edge Function `invite_staff`, `set_staff_password`, `delete_user` |
| `supabase/tests/rls_and_triggers.sql` | tes RLS, trigger, dan RPC (otomatis di-rollback) |
| `supabase/seed.sql` | data demo, **khusus lokal**, jangan dijalankan di produksi |
| `website/` | website pemesanan Netlify (membaca hari tutup, mengirim ke `web_orders`) |
| `test/` | unit test format angka, parser, total order, modal per porsi, laba, batch |

## 1. Supabase

Project **Uncle Lu** (`rjsrnjgivjsxqjlkgjqp`) sudah berisi semua migrasi dan ketiga Edge Function, dan tes RLS-nya sudah lulus.
Untuk project baru:

1. Buat project di <https://supabase.com/dashboard>.
2. Jalankan migrasi berurutan di **SQL Editor** (atau `supabase db push` dengan Supabase CLI):
   `20261111000000_hari_buka_tutup.sql`, lalu `20261112000001_satu_pintu_schema.sql`.
3. Deploy Edge Function: `supabase functions deploy invite_staff set_staff_password delete_user`.
4. (Opsional, lokal) `supabase db reset` memuat `seed.sql`. Akun demo: `admin@unclelu.id` / `rahasia123` dan `staff@unclelu.id` / `staff123`.
5. Jalankan `supabase/tests/rls_and_triggers.sql` di SQL Editor. Pesan **SEMUA TES LULUS** berarti lulus.

Catatan penting:
- **Daftar akun = toko baru.** Trigger `handle_new_user` membuat baris `stores` dan profil `owner`.
- **Toko website.** Hanya toko dengan `stores.is_website_store = true` yang bisa mengubah hari buka/tutup dan melihat order website. Toko ini otomatis ditandai saat `unclelurice@gmail.com` mendaftar. Untuk toko lain, ubah kolom itu di Table Editor.
- **Konfirmasi email.** Supabase mewajibkan konfirmasi email secara default. Untuk mematikannya buka Authentication → Providers → Email → "Confirm email". Kalau tetap aktif, pendaftar harus membuka email konfirmasi sebelum bisa login.

## 2. Aplikasi Flutter

Folder platform (`android/`, `ios/`) belum ada di repo. Buat sekali saja:

```bash
flutter create . --org id.satupintu --platforms=android,ios --project-name satu_pintu
flutter pub get
flutter gen-l10n
```

Tambahkan izin foto/kamera di `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key><string>Untuk memilih foto toko</string>
<key>NSCameraUsageDescription</key><string>Untuk memotret foto toko</string>
```

Jalankan aplikasi (kredensial lewat `--dart-define`, tidak di-hardcode):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://rjsrnjgivjsxqjlkgjqp.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_18vDmtyNXMiFFcie1DOSxw_YoBBUgTg
```

Cek kualitas:

```bash
flutter analyze
flutter test
```

## 3. Aturan yang dijaga server

- Total order dihitung ulang di RPC `create_order` / `update_order`. `batch_id` diisi dari tanggal order, dan batch **Ditutup** menolak order baru maupun edit.
- Saat edit order, snapshot nama/harga lama dipertahankan untuk item yang tidak diubah.
- Batch tidak boleh tumpang-tindih (exclusion constraint `btree_gist`). Batch yang sudah berisi order tidak bisa dihapus.
- Staff tidak bisa membaca `operating_costs`, RPC laporan, atau resep. Staff juga tidak bisa mengubah menu, batch, toko, maupun role.
- Website (anon) hanya bisa membaca `closed_dates` dan `closed_weekdays` serta menambah `web_orders`. Order untuk tanggal tutup ditolak trigger `HARI_TUTUP`.
- Password staff hanya diatur lewat Edge Function (service role) dan tidak pernah disimpan di tabel aplikasi.

## 4. Website (Netlify)

`website/config.js` sudah terisi URL project dan kunci publishable. Website membaca hari tutup setiap 60 detik dan saat tab aktif kembali. Tanggal tutup tampil "Tutup" dengan tooltip catatan.
Deploy lewat <https://app.netlify.com/drop> dengan menyeret folder `website/`. Kalau fungsi ongkir perlu jalan, deploy lewat Git.
