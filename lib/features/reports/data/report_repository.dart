import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/format.dart';
import '../../../core/providers.dart';

class BatchReport {
  final String batchId;
  final String name;
  final DateTime start;
  final DateTime end;
  final int sales;
  final int orderCount;
  final int purchases;
  final int costs;
  const BatchReport({required this.batchId, required this.name, required this.start, required this.end, required this.sales, required this.orderCount, required this.purchases, required this.costs});
  int get profit => sales - purchases - costs;
}

class DailyReport {
  final DateTime day;
  final int sales;
  final int purchases;
  final int costs;
  const DailyReport(this.day, this.sales, this.purchases, this.costs);
}

class ReportRepository {
  final SupabaseClient _db;
  ReportRepository(this._db);

  Future<List<BatchReport>> byBatch(DateTime s, DateTime e) async {
    final rows = await _db.rpc('report_by_batch', params: {'p_start': Fmt.iso(s), 'p_end': Fmt.iso(e)}) as List;
    return [
      for (final r in rows)
        BatchReport(
          batchId: r['batch_id'] as String,
          name: r['name'] as String,
          start: Fmt.parseIso(r['start_date'] as String),
          end: Fmt.parseIso(r['end_date'] as String),
          sales: (r['sales'] as num).toInt(),
          orderCount: (r['order_count'] as num).toInt(),
          purchases: (r['purchases'] as num).toInt(),
          costs: (r['costs'] as num).toInt(),
        )
    ];
  }

  Future<List<DailyReport>> daily(DateTime s, DateTime e) async {
    final rows = await _db.rpc('report_daily', params: {'p_start': Fmt.iso(s), 'p_end': Fmt.iso(e)}) as List;
    return [
      for (final r in rows)
        DailyReport(Fmt.parseIso(r['day'] as String), (r['sales'] as num).toInt(), (r['purchases'] as num).toInt(), (r['costs'] as num).toInt())
    ];
  }
}

final reportRepositoryProvider = Provider((ref) => ReportRepository(ref.watch(supabaseProvider)));

final batchReportProvider = FutureProvider<List<BatchReport>>((ref) {
  ref.watch(refreshTickProvider);
  final (s, e) = ref.watch(periodProvider);
  if (!ref.watch(isOwnerProvider)) return const [];
  return ref.watch(reportRepositoryProvider).byBatch(s, e);
});

final dailyReportProvider = FutureProvider<List<DailyReport>>((ref) {
  ref.watch(refreshTickProvider);
  final (s, e) = ref.watch(periodProvider);
  if (!ref.watch(isOwnerProvider)) return const [];
  return ref.watch(reportRepositoryProvider).daily(s, e);
});
