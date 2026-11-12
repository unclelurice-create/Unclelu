/// Model data bersama. Semua nominal rupiah disimpan sebagai int.
library;

import 'format.dart';

enum Role { owner, staff }

Role roleFrom(String? s) => s == 'owner' ? Role.owner : Role.staff;

class Profile {
  final String id;
  final String fullName;
  final String email;
  final Role role;
  final String storeId;
  const Profile({required this.id, required this.fullName, required this.email, required this.role, required this.storeId});
  bool get isOwner => role == Role.owner;
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        fullName: (j['full_name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        role: roleFrom(j['role'] as String?),
        storeId: j['store_id'] as String,
      );
}

class Store {
  final String id;
  final String name;
  final String? photoUrl;
  final bool isWebsiteStore;
  const Store({required this.id, required this.name, this.photoUrl, this.isWebsiteStore = false});
  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        photoUrl: j['photo_url'] as String?,
        isWebsiteStore: (j['is_website_store'] as bool?) ?? false,
      );
}

enum MenuCategory { menu, additional }

class MenuItem {
  final String id;
  final String name;
  final int price;
  final MenuCategory category;
  final bool isAlacarte;
  const MenuItem({required this.id, required this.name, required this.price, this.category = MenuCategory.menu, this.isAlacarte = false});
  bool get isAdditional => category == MenuCategory.additional;
  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toInt(),
        category: j['category'] == 'additional' ? MenuCategory.additional : MenuCategory.menu,
        isAlacarte: (j['is_alacarte'] as bool?) ?? false,
      );
}

enum BatchStatus { buka, tutup }

class Batch {
  final String id;
  final String name;
  final DateTime start;
  final DateTime end;
  final BatchStatus status;
  const Batch({required this.id, required this.name, required this.start, required this.end, this.status = BatchStatus.buka});
  bool get isOpen => status == BatchStatus.buka;
  bool contains(DateTime d) {
    final x = Fmt.dateOnly(d);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  factory Batch.fromJson(Map<String, dynamic> j) => Batch(
        id: j['id'] as String,
        name: j['name'] as String,
        start: Fmt.parseIso(j['start_date'] as String),
        end: Fmt.parseIso(j['end_date'] as String),
        status: j['status'] == 'tutup' ? BatchStatus.tutup : BatchStatus.buka,
      );
}

enum OrderStatus { diproses, selesai, batal }

enum PaymentStatus { lunas, belum }

enum PaymentMethod { tunai, transfer, qris }

OrderStatus orderStatusFrom(String s) => OrderStatus.values.firstWhere((e) => e.name == s, orElse: () => OrderStatus.diproses);
PaymentMethod? paymentMethodFrom(String? s) => s == null ? null : PaymentMethod.values.where((e) => e.name == s).firstOrNull;

class OrderLine {
  final String id;
  final String? menuItemId;
  final String? flavorItemId;
  final String? parentItemId;
  final String name;
  final int price;
  final int qty;
  final bool isAdditional;
  const OrderLine({required this.id, this.menuItemId, this.flavorItemId, this.parentItemId, required this.name, required this.price, required this.qty, this.isAdditional = false});
  int get subtotal => price * qty;
  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        id: j['id'] as String,
        menuItemId: j['menu_item_id'] as String?,
        flavorItemId: j['flavor_item_id'] as String?,
        parentItemId: j['parent_item_id'] as String?,
        name: j['name_snapshot'] as String,
        price: (j['price'] as num).toInt(),
        qty: (j['qty'] as num).toInt(),
        isAdditional: j['category'] == 'additional',
      );
}

class Order {
  final String id;
  final String code;
  final DateTime date;
  final String customer;
  final OrderStatus status;
  final PaymentStatus payment;
  final PaymentMethod? method;
  final String? note;
  final int total;
  final String? batchId;
  final List<OrderLine> lines;
  const Order({required this.id, required this.code, required this.date, required this.customer, required this.status, required this.payment, this.method, this.note, required this.total, this.batchId, this.lines = const []});
  bool get isPaid => payment == PaymentStatus.lunas;
  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        code: j['code'] as String,
        date: Fmt.parseIso(j['order_date'] as String),
        customer: (j['customer_name'] as String?) ?? '',
        status: orderStatusFrom(j['status'] as String),
        payment: j['payment_status'] == 'lunas' ? PaymentStatus.lunas : PaymentStatus.belum,
        method: paymentMethodFrom(j['payment_method'] as String?),
        note: j['note'] as String?,
        total: (j['total'] as num).toInt(),
        batchId: j['batch_id'] as String?,
        lines: ((j['order_items'] as List?) ?? const []).map((e) => OrderLine.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Satuan bahan
const purchaseUnits = ['kg', 'liter', 'pcs', 'pack'];
const recipeUnits = ['kg', 'gram', 'liter', 'ml', 'pcs', 'pack'];
const packUnits = ['pcs', 'gram', 'ml', 'kg', 'liter'];

/// Baris bahan (belanja maupun resep)
class Ingredient {
  final String id;
  final String name;
  final double qty;
  final String unit;
  final int unitPrice; // per satuan yang dipilih (per pack jika pack)
  final double? packContent;
  final String? packUnit;
  final String? batchId;
  const Ingredient({required this.id, required this.name, required this.qty, required this.unit, required this.unitPrice, this.packContent, this.packUnit, this.batchId});
  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'] as String,
        name: j['name'] as String,
        qty: (j['qty'] as num).toDouble(),
        unit: j['unit'] as String,
        unitPrice: (j['unit_price'] as num).toInt(),
        packContent: (j['pack_content'] as num?)?.toDouble(),
        packUnit: j['pack_unit'] as String?,
        batchId: j['batch_id'] as String?,
      );
}

const costCategories = ['kemasan', 'gas_listrik', 'gaji', 'sewa', 'lainnya'];

class OperatingCost {
  final String id;
  final String name;
  final String category;
  final int amount;
  final String? batchId;
  const OperatingCost({required this.id, required this.name, required this.category, required this.amount, this.batchId});
  factory OperatingCost.fromJson(Map<String, dynamic> j) => OperatingCost(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        amount: (j['amount'] as num).toInt(),
        batchId: j['batch_id'] as String?,
      );
}

class WebOrder {
  final int id;
  final String nama;
  final String phone;
  final DateTime tanggal;
  final String? pengambilan;
  final String? alamat;
  final String? catatan;
  final List<Map<String, dynamic>> items;
  final int total;
  final int ongkir;
  final String status;
  const WebOrder({required this.id, required this.nama, required this.phone, required this.tanggal, this.pengambilan, this.alamat, this.catatan, this.items = const [], required this.total, this.ongkir = 0, required this.status});
  factory WebOrder.fromJson(Map<String, dynamic> j) => WebOrder(
        id: (j['id'] as num).toInt(),
        nama: j['nama'] as String,
        phone: j['phone'] as String,
        tanggal: Fmt.parseIso(j['tanggal'] as String),
        pengambilan: j['pengambilan'] as String?,
        alamat: j['alamat'] as String?,
        catatan: j['catatan'] as String?,
        items: ((j['items'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
        total: (j['total'] as num).toInt(),
        ongkir: (j['ongkir'] as num?)?.toInt() ?? 0,
        status: j['status'] as String,
      );
}
