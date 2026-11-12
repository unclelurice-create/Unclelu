import 'package:flutter_test/flutter_test.dart';
import 'package:satu_pintu/core/calc.dart';
import 'package:satu_pintu/core/models.dart';

const salted = MenuItem(id: 'm1', name: 'Salted Egg Chicken', price: 25000);
const pepper = MenuItem(id: 'm2', name: 'Blackpepper Chicken', price: 25000);
const alc = MenuItem(id: 'm3', name: 'Chicken Only with Sauce', price: 32000, isAlacarte: true);
const egg = MenuItem(id: 'a1', name: 'Egg', price: 5000, category: MenuCategory.additional);
final menus = [salted, pepper, alc];
final adds = [egg];

Ingredient ing(String n, double q, String u, int p, {double? pc, String? pu}) => Ingredient(id: n, name: n, qty: q, unit: u, unitPrice: p, packContent: pc, packUnit: pu);

void main() {
  group('Total order', () {
    test('menu + additional + à la carte', () {
      var c = <String, CartEntry>{};
      c = Cart.incMenu(c, 'm1');
      c = Cart.incMenu(c, 'm1');
      c = Cart.incAdd(c, salted, 'a1')!;
      c = Cart.incFlavor(c, 'm3', 'm1');
      c = Cart.incFlavor(c, 'm3', 'm1');
      c = Cart.incFlavor(c, 'm3', 'm2');
      // 2×25.000 + 5.000 + 3×32.000
      expect(Cart.total(c, menus, adds), 151000);
      expect(Cart.itemCount(c), 5);
      expect(Cart.lines(c, menus, adds).map((l) => l.label), contains('Chicken Only with Sauce – Salted Egg Chicken'));
    });
    test('+ additional saat menu belum dipilih menambah menu 1 porsi', () {
      final c = Cart.incAdd({}, salted, 'a1')!;
      expect(c['m1']!.qty, 1);
      expect(Cart.total(c, menus, adds), 30000);
    });
    test('additional à la carte tanpa rasa ditolak', () => expect(Cart.incAdd({}, alc, 'a1'), isNull));
    test('menu ke 0 menghapus additional-nya', () {
      var c = Cart.incAdd({}, salted, 'a1')!;
      c = Cart.decMenu(c, 'm1');
      expect(c.containsKey('m1'), isFalse);
      expect(Cart.total(c, menus, adds), 0);
    });
    test('menu/rasa yang dihapus keluar dari keranjang', () {
      var c = Cart.incFlavor({}, 'm3', 'm2');
      c = Cart.incMenu(c, 'm2');
      final pruned = Cart.prune(c, [salted, alc], adds);
      expect(pruned, isEmpty);
    });
    test('payload RPC', () {
      var c = Cart.incFlavor({}, 'm3', 'm2');
      c = Cart.incAdd(c, alc, 'a1')!;
      final p = Cart.toRpc(c, menus);
      expect(p.single['flavors'], [{'menu_item_id': 'm2', 'qty': 1}]);
      expect(p.single['additions'], [{'menu_item_id': 'a1', 'qty': 1}]);
    });
  });

  group('Bahan & modal', () {
    test('total bahan dibulatkan', () {
      expect(Calc.ingredientTotal(2.5, 56000), 140000);
      expect(Calc.ingredientTotal(0.333, 1000), 333);
      expect(Calc.purchaseTotal([ing('a', 50, 'kg', 12000), ing('b', 1.5, 'liter', 19000)]), 628500);
    });
    final recipe = [
      ing('Ayam', 2.8, 'kg', 54000),
      ing('Beras', 2.5, 'kg', 15000),
      ing('Telur asin', 25, 'pcs', 4000),
      ing('Tepung', 1, 'kg', 10000),
      ing('Minyak goreng', 1, 'liter', 19000),
    ];
    test('resep 25 porsi Rp317.700 -> Rp12.708 per porsi', () {
      expect(Calc.recipeTotal(recipe), 317700);
      expect(Calc.costPerPortion(recipe, 25), 12708);
    });
    test('basis 50 porsi -> Rp6.354 per porsi', () => expect(Calc.costPerPortion(recipe, 50), 6354));
    test('margin menu', () {
      expect(Calc.menuMargin(25000, 12708), 49);
      expect(Calc.menuMargin(5000, 4000), 20);
      expect(Calc.menuMargin(0, 100), 0);
    });
    test('konversi porsi & satuan mudah dibaca', () {
      expect(Calc.scaleQty(2.8, 1, 25), closeTo(0.112, 1e-9));
      expect(Calc.niceQty(0.112, 'kg'), '112 gram');
      expect(Calc.niceQty(0.04, 'liter'), '40 ml');
      expect(Calc.niceQty(0.04, 'pack', packContent: 25, packUnit: 'pcs'), '1 pcs · 0,04 pack');
      expect(Calc.scaleCost(25, 4000, 1, 25), 4000);
      expect(Calc.pricePerContent(6250, 25), 250);
    });
  });

  group('Laba & dashboard', () {
    test('laba bersih & margin', () {
      expect(Calc.netProfit(1000000, 400000, 100000), 500000);
      expect(Calc.profitMargin(500000, 1000000), 50);
    });
    test('laba negatif', () {
      final p = Calc.netProfit(100000, 150000, 20000);
      expect(p, -70000);
      expect(Calc.profitMargin(p, 100000), -70);
    });
    test('penjualan 0', () {
      expect(Calc.profitMargin(-5000, 0), 0);
      expect(Calc.changePct(100, 0), isNull);
      expect(Calc.changePct(150, 100), 50);
    });
    Order o(int total, OrderStatus s, PaymentStatus p) => Order(id: '$total', code: 'x', date: DateTime(2025, 3, 8), customer: 'c', status: s, payment: p, total: total);
    test('belum dibayar mengabaikan batal & lunas', () {
      final orders = [o(100, OrderStatus.diproses, PaymentStatus.belum), o(200, OrderStatus.batal, PaymentStatus.belum), o(300, OrderStatus.selesai, PaymentStatus.lunas)];
      expect(Calc.unpaidTotal(orders), 100);
      expect(Calc.salesTotal(orders), 400);
    });
    test('periode sebelumnya sama panjang', () {
      final (s, e) = Calc.previousPeriod(DateTime(2025, 3, 1), DateTime(2025, 3, 31));
      expect(s, DateTime(2025, 1, 29));
      expect(e, DateTime(2025, 2, 28));
    });
  });

  group('Batch', () {
    final b1 = Batch(id: 'b1', name: 'Batch 01', start: DateTime(2025, 3, 3), end: DateTime(2025, 3, 9));
    final b2 = Batch(id: 'b2', name: 'Batch 02', start: DateTime(2025, 3, 10), end: DateTime(2025, 3, 16), status: BatchStatus.tutup);
    test('order masuk batch sesuai tanggal', () {
      expect(Calc.batchFor(DateTime(2025, 3, 9), [b1, b2])!.id, 'b1');
      expect(Calc.batchFor(DateTime(2025, 3, 10), [b1, b2])!.isOpen, isFalse);
      expect(Calc.batchFor(DateTime(2025, 4, 1), [b1, b2]), isNull);
    });
    test('batch baru mulai sehari setelah batch terakhir, 7 hari', () {
      final (s, e) = Calc.nextBatchRange([b1, b2], DateTime(2025, 3, 12));
      expect(s, DateTime(2025, 3, 17));
      expect(e, DateTime(2025, 3, 23));
      final (s0, _) = Calc.nextBatchRange([], DateTime(2025, 3, 12)); // Rabu
      expect(s0, DateTime(2025, 3, 10)); // Senin pekan ini
    });
    test('tabrakan tanggal', () {
      expect(Calc.overlapping(DateTime(2025, 3, 8), DateTime(2025, 3, 12), [b1, b2])!.id, 'b1');
      expect(Calc.overlapping(DateTime(2025, 3, 3), DateTime(2025, 3, 9), [b1, b2], exceptId: 'b1'), isNull);
    });
    test('filter & pembagian periode ke batch', () {
      final r = Calc.batchesInPeriod([b2, b1], DateTime(2025, 3, 8), DateTime(2025, 3, 11));
      expect(r.map((b) => b.id), ['b1', 'b2']);
      expect(Calc.batchesInPeriod([b1, b2], DateTime(2025, 3, 1), DateTime(2025, 3, 31), only: 'b2').single.id, 'b2');
      expect(Calc.overlapFraction(b1, DateTime(2025, 3, 8), DateTime(2025, 3, 31)), closeTo(2 / 7, 1e-9));
    });
  });

  group('Donut penjualan per menu', () {
    test('menu baru mulai 0%, additional digabung', () {
      final s = menuShares([salted, pepper], {'m1': 75000}, 25000);
      expect(s.map((x) => x.pct), [75, 0, 25]);
      expect(s.last.isAdditional, isTrue);
    });
    test('tanpa data semua 0', () => expect(menuShares([salted], {}, 0).every((x) => x.pct == 0), isTrue));
  });
}
