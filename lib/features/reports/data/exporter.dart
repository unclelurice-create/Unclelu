import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/format.dart';
import 'report_repository.dart';

enum ReportKind { penjualan, bahan, ringkasan }

enum ExportFormat { xlsx, pdf }

/// Tabel laporan (judul kolom + baris) yang dipakai Excel maupun PDF.
class ReportTable {
  final String title;
  final List<String> header;
  final List<List<Object>> rows;
  final Set<int> moneyCols;
  const ReportTable(this.title, this.header, this.rows, {this.moneyCols = const {}});
}

ReportTable buildTable(ReportKind kind, List<BatchReport> batches, String periodLabel, {required Map<String, String> labels}) {
  String l(String k) => labels[k] ?? k;
  switch (kind) {
    case ReportKind.penjualan:
      return ReportTable('${l('sales')} · $periodLabel', ['Batch', l('orders'), l('sales')], [
        for (final b in batches) [b.name, b.orderCount, b.sales],
        [l('total'), batches.fold<int>(0, (a, b) => a + b.orderCount), batches.fold<int>(0, (a, b) => a + b.sales)],
      ], moneyCols: {2});
    case ReportKind.bahan:
      return ReportTable('${l('purchases')} · $periodLabel', ['Batch', l('purchases')], [
        for (final b in batches) [b.name, b.purchases],
        [l('total'), batches.fold<int>(0, (a, b) => a + b.purchases)],
      ], moneyCols: {1});
    case ReportKind.ringkasan:
      return ReportTable('${l('summary')} · $periodLabel', ['Batch', l('sales'), l('purchases'), l('costs'), l('profit')], [
        for (final b in batches) [b.name, b.sales, b.purchases, b.costs, b.profit],
        [
          l('total'),
          batches.fold<int>(0, (a, b) => a + b.sales),
          batches.fold<int>(0, (a, b) => a + b.purchases),
          batches.fold<int>(0, (a, b) => a + b.costs),
          batches.fold<int>(0, (a, b) => a + b.profit),
        ],
      ], moneyCols: {1, 2, 3, 4});
  }
}

Uint8List toXlsx(ReportTable t) {
  final x = Excel.createExcel();
  final name = x.getDefaultSheet() ?? 'Sheet1';
  final sh = x[name];
  sh.appendRow([TextCellValue(t.title)]);
  sh.appendRow([for (final h in t.header) TextCellValue(h)]);
  for (final r in t.rows) {
    sh.appendRow([for (final v in r) v is int ? IntCellValue(v) : TextCellValue(v.toString())]);
  }
  return Uint8List.fromList(x.encode()!);
}

Future<Uint8List> toPdf(ReportTable t) async {
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    build: (_) => [
      pw.Text(t.title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: t.header,
        data: [
          for (final r in t.rows) [for (var i = 0; i < r.length; i++) (r[i] is int && t.moneyCols.contains(i)) ? Fmt.rp(r[i] as int) : r[i].toString()]
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellAlignments: {for (var i = 1; i < t.header.length; i++) i: pw.Alignment.centerRight},
      ),
    ],
  ));
  return doc.save();
}

Future<void> exportAndShare(ReportTable t, ExportFormat f, String fileBase) async {
  final bytes = f == ExportFormat.xlsx ? toXlsx(t) : await toPdf(t);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileBase.${f == ExportFormat.xlsx ? 'xlsx' : 'pdf'}');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path)], subject: t.title);
}
