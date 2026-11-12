import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';

/// Toko, menu, batch, pengguna, resep, hari buka/tutup.
class SettingsRepository {
  final SupabaseClient _db;
  SettingsRepository(this._db);

  // ---------------------------------------------------------------- toko
  Future<void> updateStore(String storeId, {required String name, String? photoUrl, bool clearPhoto = false}) =>
      _db.from('stores').update({'name': name.trim(), if (photoUrl != null || clearPhoto) 'photo_url': photoUrl}).eq('id', storeId);

  /// Foto toko sudah diperkecil (maks. 480 px) oleh image_picker.
  Future<String> uploadStorePhoto(String storeId, Uint8List bytes) async {
    final path = '$storeId/logo.jpg';
    await _db.storage.from('store-photos').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
    final url = _db.storage.from('store-photos').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> removeStorePhoto(String storeId) async {
    await _db.storage.from('store-photos').remove(['$storeId/logo.jpg']);
    await _db.from('stores').update({'photo_url': null}).eq('id', storeId);
  }

  // ---------------------------------------------------------------- menu
  Future<List<MenuItem>> menus() async {
    final rows = await _db.from('menu_items').select().eq('active', true).order('sort_order').order('created_at');
    return rows.map(MenuItem.fromJson).toList();
  }

  /// Simpan menu. [photo] = foto baru (sudah diperkecil); [removePhoto] menghapus foto.
  Future<void> saveMenu({String? id, required String name, required int price, required MenuCategory category, bool isAlacarte = false, String? description, Uint8List? photo, bool removePhoto = false}) async {
    final data = <String, dynamic>{
      'name': name.trim(), 'price': price, 'category': category.name,
      'is_alacarte': category == MenuCategory.menu && isAlacarte,
      'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
      if (removePhoto) 'photo_url': null,
    };
    final String menuId;
    if (id == null) {
      final row = await _db.from('menu_items').insert(data).select('id, store_id').single();
      menuId = row['id'] as String;
    } else {
      await _db.from('menu_items').update(data).eq('id', id);
      menuId = id;
    }
    if (photo != null) {
      final row = await _db.from('menu_items').select('store_id').eq('id', menuId).single();
      final path = '${row['store_id']}/menu/$menuId.jpg';
      await _db.storage.from('store-photos').uploadBinary(path, photo, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      final url = '${_db.storage.from('store-photos').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await _db.from('menu_items').update({'photo_url': url}).eq('id', menuId);
    }
  }

  /// Soft delete agar order lama tetap utuh.
  Future<void> deleteMenu(String id) => _db.from('menu_items').update({'active': false}).eq('id', id);

  // ---------------------------------------------------------------- batch
  Future<List<Batch>> batches() async {
    final rows = await _db.from('batches').select().order('start_date');
    return rows.map(Batch.fromJson).toList();
  }

  Future<Map<String, int>> orderCountPerBatch() async {
    final rows = await _db.from('orders').select('batch_id');
    final m = <String, int>{};
    for (final r in rows) {
      final b = r['batch_id'] as String?;
      if (b != null) m[b] = (m[b] ?? 0) + 1;
    }
    return m;
  }

  Future<void> saveBatch({String? id, required String name, required DateTime start, required DateTime end, required bool open}) async {
    final data = {'name': name.trim(), 'start_date': Fmt.iso(start), 'end_date': Fmt.iso(end), 'status': open ? 'buka' : 'tutup'};
    if (id == null) {
      await _db.from('batches').insert(data);
    } else {
      await _db.from('batches').update(data).eq('id', id);
    }
  }

  Future<void> deleteBatch(String id) => _db.from('batches').delete().eq('id', id);

  // ---------------------------------------------------------------- pengguna
  Future<List<Profile>> users() async {
    final rows = await _db.from('profiles').select().order('created_at');
    return rows.map(Profile.fromJson).toList();
  }

  Future<void> setRole(String userId, Role role) => _db.from('profiles').update({'role': role.name}).eq('id', userId);

  Future<void> inviteStaff(String name, String email, String password) =>
      _db.functions.invoke('invite_staff', body: {'name': name.trim(), 'email': email.trim(), 'password': password});

  Future<void> setStaffPassword(String userId, String password) =>
      _db.functions.invoke('set_staff_password', body: {'user_id': userId, 'password': password});

  Future<void> deleteUser(String userId) => _db.functions.invoke('delete_user', body: {'user_id': userId});

  // ---------------------------------------------------------------- resep (modal bahan)
  Future<Map<String, int>> recipeBases() async {
    final rows = await _db.from('menu_recipes').select();
    return {for (final r in rows) r['menu_item_id'] as String: (r['base_portions'] as num).toInt()};
  }

  Future<List<Ingredient>> recipeItems([String? menuId]) async {
    var q = _db.from('recipe_items').select();
    if (menuId != null) q = q.eq('menu_item_id', menuId);
    final rows = await q.order('created_at');
    return rows.map((r) => Ingredient.fromJson({...r, 'batch_id': r['menu_item_id']})).toList();
  }

  Future<void> setBasePortions(String menuId, int n) =>
      _db.from('menu_recipes').upsert({'menu_item_id': menuId, 'base_portions': n});

  Future<void> addRecipeItem(String menuId, {required String name, required double qty, required String unit, required int unitPrice, double? packContent, String? packUnit}) async {
    await _db.from('menu_recipes').upsert({'menu_item_id': menuId}, ignoreDuplicates: true);
    await _db.from('recipe_items').insert({
      'menu_item_id': menuId, 'name': name.trim(), 'qty': qty, 'unit': unit, 'unit_price': unitPrice,
      'pack_content': unit == 'pack' ? packContent : null, 'pack_unit': unit == 'pack' ? packUnit : null,
    });
  }

  Future<void> deleteRecipeItem(String id) => _db.from('recipe_items').delete().eq('id', id);

  // ---------------------------------------------------------------- hari buka/tutup (website)
  Future<Map<String, String>> closedDates() async {
    final rows = await _db.from('closed_dates').select('tanggal, catatan');
    return {for (final r in rows) r['tanggal'] as String: (r['catatan'] as String?) ?? ''};
  }

  Future<Set<int>> closedWeekdays() async {
    final rows = await _db.from('closed_weekdays').select('dow');
    return rows.map((r) => (r['dow'] as num).toInt()).toSet();
  }

  Future<void> setWeekday(int dow, bool closed) async {
    final uid = _db.auth.currentUser?.id;
    if (closed) {
      await _db.from('closed_weekdays').upsert({'dow': dow, 'updated_by': uid, 'updated_at': DateTime.now().toIso8601String()});
    } else {
      await _db.from('closed_weekdays').delete().eq('dow', dow);
    }
  }

  Future<void> closeDate(DateTime d, String note) => _db.from('closed_dates').upsert({
        'tanggal': Fmt.iso(d), 'catatan': note.trim().isEmpty ? null : note.trim(),
        'updated_by': _db.auth.currentUser?.id, 'updated_at': DateTime.now().toIso8601String(),
      });

  Future<void> openDate(DateTime d) => _db.from('closed_dates').delete().eq('tanggal', Fmt.iso(d));
}

final settingsRepositoryProvider = Provider((ref) => SettingsRepository(ref.watch(supabaseProvider)));

// ------------------------------------------------------------------ provider data bersama
final menusProvider = FutureProvider<List<MenuItem>>((ref) {
  ref.watch(refreshTickProvider);
  ref.watch(currentUserIdProvider);
  return ref.watch(settingsRepositoryProvider).menus();
});

final batchesProvider = FutureProvider<List<Batch>>((ref) {
  ref.watch(refreshTickProvider);
  ref.watch(currentUserIdProvider);
  return ref.watch(settingsRepositoryProvider).batches();
});

/// Hari tutup website: (tanggal -> catatan, hari rutin)
final closedDaysProvider = FutureProvider<(Map<String, String>, Set<int>)>((ref) async {
  ref.watch(refreshTickProvider);
  final r = ref.watch(settingsRepositoryProvider);
  return (await r.closedDates(), await r.closedWeekdays());
});

/// DateTime.weekday (1=Sen..7=Min) -> dow Postgres (0=Min..6=Sab)
int dowOf(DateTime d) => d.weekday % 7;

bool isClosedOnWebsite(DateTime d, (Map<String, String>, Set<int>)? data) =>
    data != null && (data.$1.containsKey(Fmt.iso(d)) || data.$2.contains(dowOf(d)));
