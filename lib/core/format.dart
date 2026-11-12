import 'package:intl/intl.dart';

/// Format & parser angka/tanggal. Murni (tanpa Flutter) supaya mudah dites.
class Fmt {
  static final _id = NumberFormat.decimalPattern('id_ID');

  /// Rp125.430.000
  static String rp(num n) => 'Rp${_thousands(n.round())}';

  static String _thousands(int n) {
    final neg = n < 0;
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${neg ? '-' : ''}$b';
  }

  /// 56000 -> "56.000" (untuk kolom input harga)
  static String thousands(int n) => _thousands(n);

  /// Format ringkas untuk kartu: Rp1,2 M / Rp125,4 jt / Rp800 rb / Rp750
  static String compact(num n) {
    final neg = n < 0;
    final a = n.abs();
    String one(double x) {
      final r = (x * 10).round() / 10;
      final t = r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1).replaceAll('.', ',');
      return t;
    }
    String out;
    if (a >= 1e9) {
      out = 'Rp${one(a / 1e9)} M';
    } else if (a >= 1e6) {
      out = 'Rp${one(a / 1e6)} jt';
    } else if (a >= 1e3) {
      out = 'Rp${(a / 1e3).round()} rb';
    } else {
      out = rp(a);
    }
    return neg ? '-$out' : out;
  }

  /// Parser jumlah: menerima "2,5" dan "2.5". Nilai tidak valid -> 0.
  static double parseQty(String s) {
    final t = s.trim().replaceAll(',', '.');
    return double.tryParse(t) ?? 0;
  }

  /// Parser harga: hanya mengambil digit. "Rp56.000" -> 56000
  static int parsePrice(String s) {
    final d = s.replaceAll(RegExp(r'\D'), '');
    return d.isEmpty ? 0 : int.parse(d);
  }

  /// Angka kuantitas maks. 3 desimal, koma Indonesia: 2.5 -> "2,5"
  static String qty(num n) {
    final f = NumberFormat('#,##0.###', 'id_ID');
    return f.format(n);
  }

  static String number(num n) => _id.format(n);

  /// Tanggal ke yyyy-mm-dd (kolom date, tanpa UTC)
  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime parseIso(String s) {
    final p = s.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// 12 Mar 2025
  static String date(DateTime d, String locale) => DateFormat('d MMM y', locale).format(d);

  /// 8 – 14 Mar 2025 / 28 Feb – 6 Mar 2025 / 28 Des 2024 – 3 Jan 2025
  static String range(DateTime a, DateTime b, String locale) {
    final sameY = a.year == b.year;
    if (sameY && a.month == b.month) {
      if (a.day == b.day) return date(b, locale);
      return '${a.day} – ${date(b, locale)}';
    }
    final left = DateFormat(sameY ? 'd MMM' : 'd MMM y', locale).format(a);
    return '$left – ${date(b, locale)}';
  }
}
