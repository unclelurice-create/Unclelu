import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:satu_pintu/core/format.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('id'));

  group('Format angka ringkas', () {
    test('miliar, juta, ribu, satuan', () {
      expect(Fmt.compact(1200000000), 'Rp1,2 M');
      expect(Fmt.compact(125430000), 'Rp125,4 jt');
      expect(Fmt.compact(2000000), 'Rp2 jt');
      expect(Fmt.compact(800000), 'Rp800 rb');
      expect(Fmt.compact(750), 'Rp750');
      expect(Fmt.compact(0), 'Rp0');
      expect(Fmt.compact(-1500000), '-Rp1,5 jt');
    });
    test('format penuh', () {
      expect(Fmt.rp(125430000), 'Rp125.430.000');
      expect(Fmt.rp(5000), 'Rp5.000');
      expect(Fmt.rp(0), 'Rp0');
    });
  });

  group('Parser', () {
    test('jumlah menerima koma dan titik', () {
      expect(Fmt.parseQty('2,5'), 2.5);
      expect(Fmt.parseQty('2.5'), 2.5);
      expect(Fmt.parseQty(''), 0);
      expect(Fmt.parseQty('abc'), 0);
    });
    test('harga hanya mengambil digit', () {
      expect(Fmt.parsePrice('56.000'), 56000);
      expect(Fmt.parsePrice('Rp 12.500,-'), 12500);
      expect(Fmt.parsePrice(''), 0);
    });
    test('titik ribuan input', () => expect(Fmt.thousands(56000), '56.000'));
  });

  group('Tanggal', () {
    test('iso tanpa UTC', () {
      expect(Fmt.iso(DateTime(2025, 3, 8, 23, 59)), '2025-03-08');
      expect(Fmt.parseIso('2025-03-08'), DateTime(2025, 3, 8));
    });
    test('rentang', () {
      expect(Fmt.range(DateTime(2025, 3, 8), DateTime(2025, 3, 14), 'id'), '8 – 14 Mar 2025');
    });
  });
}
