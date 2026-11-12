import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/calc.dart';
import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';

class OrderRepository {
  final SupabaseClient _db;
  OrderRepository(this._db);

  static const _select = '*, order_items(*)';

  Future<List<Order>> orders({DateTime? from, DateTime? to}) async {
    var q = _db.from('orders').select(_select);
    if (from != null) q = q.gte('order_date', Fmt.iso(from));
    if (to != null) q = q.lte('order_date', Fmt.iso(to));
    final rows = await q.order('created_at', ascending: false);
    return rows.map(Order.fromJson).toList();
  }

  Future<Order> create({required String customer, required DateTime date, required String note, required List<Map<String, dynamic>> items, required PaymentStatus pay, PaymentMethod? method, int? webOrderId}) async {
    final row = await _db.rpc('create_order', params: {
      'customer': customer, 'order_date': Fmt.iso(date), 'note': note, 'items': items,
      'payment_status': pay.name, 'payment_method': pay == PaymentStatus.lunas ? method?.name : null,
    });
    final o = Order.fromJson(Map<String, dynamic>.from(row as Map));
    if (webOrderId != null) {
      await _db.from('orders').update({'web_order_id': webOrderId}).eq('id', o.id);
      await _db.from('web_orders').update({'status': 'diproses'}).eq('id', webOrderId);
    }
    return o;
  }

  Future<Order> update(String id, {required String customer, required DateTime date, required String note, required List<Map<String, dynamic>> items, required PaymentStatus pay, PaymentMethod? method}) async {
    final row = await _db.rpc('update_order', params: {
      'order_id': id, 'customer': customer, 'order_date': Fmt.iso(date), 'note': note, 'items': items,
      'payment_status': pay.name, 'payment_method': pay == PaymentStatus.lunas ? method?.name : null,
    });
    return Order.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<void> setStatus(String id, OrderStatus status, PaymentStatus pay, PaymentMethod? method) => _db.rpc('set_order_status', params: {
        'order_id': id, 'status': status.name, 'payment_status': pay.name,
        'payment_method': pay == PaymentStatus.lunas ? method?.name : null,
      });

  Future<List<WebOrder>> newWebOrders() async {
    final rows = await _db.from('web_orders').select().eq('status', 'baru').order('created_at', ascending: false);
    return rows.map(WebOrder.fromJson).toList();
  }

  /// Penjualan per menu (RPC) -> (per menu id, total additional)
  Future<(Map<String?, int>, int)> salesByMenu(DateTime s, DateTime e) async {
    final rows = await _db.rpc('sales_by_menu', params: {'p_start': Fmt.iso(s), 'p_end': Fmt.iso(e)}) as List;
    final m = <String?, int>{};
    var add = 0;
    for (final r in rows) {
      final amt = (r['amount'] as num).toInt();
      if (r['category'] == 'additional') {
        add += amt;
      } else {
        m[r['menu_item_id'] as String?] = (m[r['menu_item_id']] ?? 0) + amt;
      }
    }
    return (m, add);
  }
}

final orderRepositoryProvider = Provider((ref) => OrderRepository(ref.watch(supabaseProvider)));

final allOrdersProvider = FutureProvider<List<Order>>((ref) {
  ref.watch(refreshTickProvider);
  ref.watch(currentUserIdProvider);
  return ref.watch(orderRepositoryProvider).orders();
});

final webOrdersProvider = FutureProvider<List<WebOrder>>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(orderRepositoryProvider).newWebOrders();
});

/// Peta pesan error RPC -> teks ramah (diisi di UI dengan l10n)
bool isBatchClosed(Object e) => errorCode(e).contains('BATCH_DITUTUP');
bool isNoBatch(Object e) => errorCode(e).contains('TANPA_BATCH');

/// Ubah item web order -> keranjang (cocokkan nama menu / rasa / tambahan).
(Map<String, CartEntry>, List<String>) cartFromWebItems(List<Map<String, dynamic>> items, List<MenuItem> menus) {
  var cart = <String, CartEntry>{};
  final missing = <String>[];
  MenuItem? find(String? n, {bool add = false}) {
    if (n == null) return null;
    final k = n.trim().toLowerCase();
    for (final m in menus) {
      if (m.isAdditional == add && m.name.trim().toLowerCase() == k) return m;
    }
    return null;
  }

  for (final it in items) {
    final name = it['menu']?.toString();
    final qty = (it['qty'] as num?)?.toInt() ?? 1;
    final m = find(name);
    if (m == null) {
      if (name != null) missing.add(name);
      continue;
    }
    if (m.isAlacarte) {
      final f = find(it['sauce']?.toString());
      if (f == null) {
        missing.add('$name – ${it['sauce'] ?? '?'}');
        continue;
      }
      for (var i = 0; i < qty; i++) {
        cart = Cart.incFlavor(cart, m.id, f.id);
      }
    } else {
      for (var i = 0; i < qty; i++) {
        cart = Cart.incMenu(cart, m.id);
      }
    }
    for (final t in (it['tambahan'] as List? ?? const [])) {
      final a = find(t.toString(), add: true);
      if (a == null) {
        missing.add(t.toString());
        continue;
      }
      for (var i = 0; i < qty; i++) {
        cart = Cart.incAdd(cart, m, a.id) ?? cart;
      }
    }
  }
  return (cart, missing);
}
