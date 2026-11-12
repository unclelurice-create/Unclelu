/// Aturan perhitungan (bagian 7 prompt). Murni, tanpa Flutter/Supabase.
library;

import 'format.dart';
import 'models.dart';

// ---------------------------------------------------------------- keranjang
/// Keranjang order per menu. Untuk menu à la carte, [flavors] berisi qty per rasa
/// dan [qty] = jumlah semua rasa.
class CartEntry {
  final int qty;
  final Map<String, int> flavors; // flavorMenuId -> qty
  final Map<String, int> additions; // additionalId -> qty
  const CartEntry({this.qty = 0, this.flavors = const {}, this.additions = const {}});
  CartEntry copyWith({int? qty, Map<String, int>? flavors, Map<String, int>? additions}) =>
      CartEntry(qty: qty ?? this.qty, flavors: flavors ?? this.flavors, additions: additions ?? this.additions);
}

class CartLine {
  final String label;
  final int qty;
  final int subtotal;
  const CartLine(this.label, this.qty, this.subtotal);
}

class Cart {
  /// Total = Σ(harga menu × qty) + Σ(harga additional × qty additional)
  static int total(Map<String, CartEntry> cart, List<MenuItem> menus, List<MenuItem> adds) =>
      lines(cart, menus, adds).fold(0, (s, l) => s + l.subtotal);

  static int itemCount(Map<String, CartEntry> cart) => cart.values.fold(0, (s, c) => s + c.qty);

  static List<CartLine> lines(Map<String, CartEntry> cart, List<MenuItem> menus, List<MenuItem> adds) {
    final out = <CartLine>[];
    final flavorsList = menus.where((m) => !m.isAlacarte).toList();
    for (final m in menus) {
      final c = cart[m.id];
      if (c == null || c.qty <= 0) continue;
      if (m.isAlacarte) {
        for (final f in flavorsList) {
          final q = c.flavors[f.id] ?? 0;
          if (q > 0) out.add(CartLine('${m.name} – ${f.name}', q, m.price * q));
        }
      } else {
        out.add(CartLine(m.name, c.qty, m.price * c.qty));
      }
      for (final a in adds) {
        final q = c.additions[a.id] ?? 0;
        if (q > 0) out.add(CartLine('+ ${a.name} (${m.name})', q, a.price * q));
      }
    }
    return out;
  }

  // Operasi keranjang (immutable) -------------------------------------
  static Map<String, CartEntry> incMenu(Map<String, CartEntry> cart, String menuId) {
    final c = cart[menuId] ?? const CartEntry();
    return {...cart, menuId: c.copyWith(qty: c.qty + 1)};
  }

  /// Menurunkan menu ke 0 menghapus menu beserta additional-nya.
  static Map<String, CartEntry> decMenu(Map<String, CartEntry> cart, String menuId) {
    final c = cart[menuId];
    if (c == null) return cart;
    final next = Map<String, CartEntry>.from(cart);
    if (c.qty <= 1) {
      next.remove(menuId);
    } else {
      next[menuId] = c.copyWith(qty: c.qty - 1);
    }
    return next;
  }

  static Map<String, CartEntry> incFlavor(Map<String, CartEntry> cart, String menuId, String flavorId) {
    final c = cart[menuId] ?? const CartEntry();
    final f = Map<String, int>.from(c.flavors)..update(flavorId, (v) => v + 1, ifAbsent: () => 1);
    return {...cart, menuId: c.copyWith(qty: c.qty + 1, flavors: f)};
  }

  static Map<String, CartEntry> decFlavor(Map<String, CartEntry> cart, String menuId, String flavorId) {
    final c = cart[menuId];
    final q = c?.flavors[flavorId] ?? 0;
    if (c == null || q <= 0) return cart;
    final f = Map<String, int>.from(c.flavors);
    if (q <= 1) {
      f.remove(flavorId);
    } else {
      f[flavorId] = q - 1;
    }
    final next = Map<String, CartEntry>.from(cart);
    if (c.qty - 1 <= 0) {
      next.remove(menuId);
    } else {
      next[menuId] = c.copyWith(qty: c.qty - 1, flavors: f);
    }
    return next;
  }

  /// Menekan + additional saat menu belum dipilih otomatis menambah menu 1 porsi
  /// (kecuali menu à la carte: return null = "Pilih rasa dulu").
  static Map<String, CartEntry>? incAdd(Map<String, CartEntry> cart, MenuItem menu, String addId) {
    final c = cart[menu.id];
    if (c == null || c.qty <= 0) {
      if (menu.isAlacarte) return null;
      return {...cart, menu.id: CartEntry(qty: 1, additions: {addId: 1})};
    }
    final a = Map<String, int>.from(c.additions)..update(addId, (v) => v + 1, ifAbsent: () => 1);
    return {...cart, menu.id: c.copyWith(additions: a)};
  }

  static Map<String, CartEntry> decAdd(Map<String, CartEntry> cart, String menuId, String addId) {
    final c = cart[menuId];
    final q = c?.additions[addId] ?? 0;
    if (c == null || q <= 0) return cart;
    final a = Map<String, int>.from(c.additions);
    if (q <= 1) {
      a.remove(addId);
    } else {
      a[addId] = q - 1;
    }
    return {...cart, menuId: c.copyWith(additions: a)};
  }

  /// Bersihkan keranjang dari menu/additional/rasa yang sudah tidak ada.
  static Map<String, CartEntry> prune(Map<String, CartEntry> cart, List<MenuItem> menus, List<MenuItem> adds) {
    final menuIds = menus.map((m) => m.id).toSet();
    final flavorIds = menus.where((m) => !m.isAlacarte).map((m) => m.id).toSet();
    final addIds = adds.map((a) => a.id).toSet();
    final out = <String, CartEntry>{};
    cart.forEach((id, c) {
      if (!menuIds.contains(id)) return;
      final m = menus.firstWhere((x) => x.id == id);
      var qty = c.qty;
      var flavors = c.flavors;
      if (m.isAlacarte) {
        flavors = Map.fromEntries(c.flavors.entries.where((e) => flavorIds.contains(e.key)));
        qty = flavors.values.fold(0, (s, v) => s + v);
      }
      if (qty <= 0) return;
      out[id] = CartEntry(qty: qty, flavors: flavors, additions: Map.fromEntries(c.additions.entries.where((e) => addIds.contains(e.key))));
    });
    return out;
  }

  /// Payload untuk RPC create_order / update_order.
  static List<Map<String, dynamic>> toRpc(Map<String, CartEntry> cart, List<MenuItem> menus) => [
        for (final m in menus)
          if ((cart[m.id]?.qty ?? 0) > 0)
            {
              'menu_item_id': m.id,
              'qty': cart[m.id]!.qty,
              if (m.isAlacarte)
                'flavors': [
                  for (final e in cart[m.id]!.flavors.entries)
                    if (e.value > 0) {'menu_item_id': e.key, 'qty': e.value}
                ],
              'additions': [
                for (final e in cart[m.id]!.additions.entries)
                  if (e.value > 0) {'menu_item_id': e.key, 'qty': e.value}
              ],
            }
      ];

  /// Bangun keranjang dari baris order (untuk Edit order).
  static Map<String, CartEntry> fromLines(List<OrderLine> lines) {
    final cart = <String, CartEntry>{};
    final byId = {for (final l in lines) l.id: l};
    for (final l in lines.where((l) => !l.isAdditional && l.menuItemId != null)) {
      final c = cart[l.menuItemId!] ?? const CartEntry();
      if (l.flavorItemId != null) {
        final f = Map<String, int>.from(c.flavors)..update(l.flavorItemId!, (v) => v + l.qty, ifAbsent: () => l.qty);
        cart[l.menuItemId!] = c.copyWith(qty: c.qty + l.qty, flavors: f);
      } else {
        cart[l.menuItemId!] = c.copyWith(qty: c.qty + l.qty);
      }
    }
    for (final l in lines.where((l) => l.isAdditional && l.menuItemId != null && l.parentItemId != null)) {
      final parent = byId[l.parentItemId];
      if (parent?.menuItemId == null) continue;
      final c = cart[parent!.menuItemId!];
      if (c == null) continue;
      final a = Map<String, int>.from(c.additions)..update(l.menuItemId!, (v) => v + l.qty, ifAbsent: () => l.qty);
      cart[parent.menuItemId!] = c.copyWith(additions: a);
    }
    return cart;
  }
}

// ---------------------------------------------------------------- bahan & resep
class Calc {
  /// Total bahan = round(qty × unit_price)
  static int ingredientTotal(double qty, int unitPrice) => (qty * unitPrice).round();

  static int purchaseTotal(Iterable<Ingredient> items) => items.fold(0, (s, i) => s + ingredientTotal(i.qty, i.unitPrice));

  /// Harga per isi pack, mis. Rp6.250/pack isi 25 -> 250
  static int pricePerContent(int packPrice, double content) => content > 0 ? (packPrice / content).round() : 0;

  /// Modal per porsi = round(Σ(qty × unit_price) ÷ base_portions)
  static int costPerPortion(Iterable<Ingredient> items, int basePortions) {
    if (basePortions <= 0) return 0;
    final total = items.fold<double>(0, (s, i) => s + i.qty * i.unitPrice);
    return (total / basePortions).round();
  }

  static int recipeTotal(Iterable<Ingredient> items) => items.fold<double>(0, (s, i) => s + i.qty * i.unitPrice).round();

  /// Margin menu (%) = (harga jual − modal) ÷ harga jual × 100, 0 jika harga jual 0
  static int menuMargin(int sellPrice, int cost) => sellPrice == 0 ? 0 : ((sellPrice - cost) / sellPrice * 100).round();

  /// Konversi ke N porsi
  static double scaleQty(double qty, int target, int base) => base <= 0 ? 0 : qty * target / base;
  static int scaleCost(double qty, int unitPrice, int target, int base) => base <= 0 ? 0 : (qty * unitPrice * target / base).round();

  /// Kuantitas mudah dibaca: kg < 1 -> gram, liter < 1 -> ml; pack -> "1 pcs · 0,04 pack"
  static String niceQty(double q, String unit, {double? packContent, String? packUnit}) {
    if (unit == 'pack' && packContent != null && packUnit != null) {
      return '${Fmt.qty(q * packContent)} $packUnit · ${Fmt.qty(q)} pack';
    }
    if (unit == 'kg' && q < 1) return '${Fmt.qty(q * 1000)} gram';
    if (unit == 'liter' && q < 1) return '${Fmt.qty(q * 1000)} ml';
    return '${Fmt.qty(q)} $unit';
  }

  // ------------------------------------------------------------ laba & dashboard
  /// Laba bersih = penjualan − belanja bahan − biaya operasional
  static int netProfit(int sales, int purchases, int costs) => sales - purchases - costs;

  /// Margin laba (%) = laba ÷ penjualan × 100, 0 jika penjualan 0
  static int profitMargin(int profit, int sales) => sales == 0 ? 0 : (profit / sales * 100).round();

  /// Persentase perubahan; null jika periode sebelumnya tanpa data
  static double? changePct(int current, int previous) => previous == 0 ? null : (current - previous) / previous * 100;

  /// Belum dibayar = Σ total order bukan batal & payment_status belum
  static int unpaidTotal(Iterable<Order> orders) =>
      orders.where((o) => o.status != OrderStatus.batal && o.payment == PaymentStatus.belum).fold(0, (s, o) => s + o.total);

  static int salesTotal(Iterable<Order> orders) => orders.where((o) => o.status != OrderStatus.batal).fold(0, (s, o) => s + o.total);

  /// Periode sebelumnya dengan panjang sama
  static (DateTime, DateTime) previousPeriod(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    final pe = start.subtract(const Duration(days: 1));
    return (pe.subtract(Duration(days: days - 1)), pe);
  }

  // ------------------------------------------------------------ batch
  /// Batch yang rentangnya memuat tanggal order
  static Batch? batchFor(DateTime date, List<Batch> batches) {
    for (final b in batches) {
      if (b.contains(date)) return b;
    }
    return null;
  }

  /// Usulan batch baru: sehari setelah batch terakhir (atau Senin pekan ini), 7 hari
  static (DateTime, DateTime) nextBatchRange(List<Batch> batches, DateTime today) {
    DateTime start;
    if (batches.isEmpty) {
      final t = Fmt.dateOnly(today);
      start = t.subtract(Duration(days: t.weekday - 1));
    } else {
      final last = batches.map((b) => b.end).reduce((a, b) => a.isAfter(b) ? a : b);
      start = last.add(const Duration(days: 1));
    }
    return (start, start.add(const Duration(days: 6)));
  }

  /// Batch lain yang bertabrakan dengan rentang [s, e] (null = aman)
  static Batch? overlapping(DateTime s, DateTime e, List<Batch> batches, {String? exceptId}) {
    for (final b in batches) {
      if (b.id == exceptId) continue;
      if (!(e.isBefore(b.start) || s.isAfter(b.end))) return b;
    }
    return null;
  }

  /// Filter laporan: batch yang beririsan dengan periode, opsional 1 batch.
  static List<Batch> batchesInPeriod(List<Batch> batches, DateTime s, DateTime e, {String? only}) => batches
      .where((b) => !(b.end.isBefore(s) || b.start.isAfter(e)))
      .where((b) => only == null || b.id == only)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  /// Bagian batch yang masuk periode (0..1), untuk pemotongan proporsional
  static double overlapFraction(Batch b, DateTime s, DateTime e) {
    final os = b.start.isAfter(s) ? b.start : s;
    final oe = b.end.isBefore(e) ? b.end : e;
    if (oe.isBefore(os)) return 0;
    final ov = oe.difference(os).inDays + 1;
    return ov / (b.end.difference(b.start).inDays + 1);
  }
}

// ---------------------------------------------------------------- donut
class MenuShare {
  final String name;
  final int amount;
  final double pct;
  final bool isAdditional;
  const MenuShare(this.name, this.amount, this.pct, {this.isAdditional = false});
}

/// Satu irisan per menu aktif (mulai 0%) + satu irisan "Additional".
List<MenuShare> menuShares(List<MenuItem> activeMenus, Map<String?, int> salesByMenuId, int additionalAmount) {
  final rows = [for (final m in activeMenus) (m.name, salesByMenuId[m.id] ?? 0, false)];
  rows.add(('Additional', additionalAmount, true));
  final tot = rows.fold<int>(0, (s, r) => s + r.$2);
  return [for (final r in rows) MenuShare(r.$1, r.$2, tot == 0 ? 0 : r.$2 / tot * 100, isAdditional: r.$3)];
}
