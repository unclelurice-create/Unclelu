import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models.dart';
import '../../../core/providers.dart';

class PurchaseRepository {
  final SupabaseClient _db;
  PurchaseRepository(this._db);

  Future<List<Ingredient>> purchases() async {
    final rows = await _db.from('purchase_items').select().order('created_at', ascending: false);
    return rows.map(Ingredient.fromJson).toList();
  }

  Future<void> addPurchase({required String? batchId, required String name, required double qty, required String unit, required int unitPrice, double? packContent, String? packUnit}) =>
      _db.from('purchase_items').insert({
        'batch_id': batchId, 'name': name.trim(), 'qty': qty, 'unit': unit, 'unit_price': unitPrice,
        'pack_content': unit == 'pack' ? packContent : null, 'pack_unit': unit == 'pack' ? packUnit : null,
      });

  Future<void> deletePurchase(String id) => _db.from('purchase_items').delete().eq('id', id);

  Future<List<OperatingCost>> costs() async {
    final rows = await _db.from('operating_costs').select().order('created_at', ascending: false);
    return rows.map(OperatingCost.fromJson).toList();
  }

  Future<void> addCost({required String? batchId, required String name, required String category, required int amount}) =>
      _db.from('operating_costs').insert({'batch_id': batchId, 'name': name.trim(), 'category': category, 'amount': amount});

  Future<void> deleteCost(String id) => _db.from('operating_costs').delete().eq('id', id);
}

final purchaseRepositoryProvider = Provider((ref) => PurchaseRepository(ref.watch(supabaseProvider)));

final purchasesProvider = FutureProvider<List<Ingredient>>((ref) {
  ref.watch(refreshTickProvider);
  ref.watch(currentUserIdProvider);
  return ref.watch(purchaseRepositoryProvider).purchases();
});

/// Khusus owner (RLS menolak staff); staff mendapat daftar kosong.
final costsProvider = FutureProvider<List<OperatingCost>>((ref) async {
  ref.watch(refreshTickProvider);
  if (!ref.watch(isOwnerProvider)) return const [];
  return ref.watch(purchaseRepositoryProvider).costs();
});
