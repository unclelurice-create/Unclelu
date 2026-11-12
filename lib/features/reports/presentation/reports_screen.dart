import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calc.dart';
import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/calendar.dart';
import '../../../core/widgets/common.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../settings/data/settings_repository.dart';
import '../data/exporter.dart';
import '../data/report_repository.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = context.tk;
    final batches = ref.watch(batchesProvider).valueOrNull ?? const <Batch>[];
    final sel = ref.watch(batchFilterProvider);
    final all = ref.watch(batchReportProvider).valueOrNull ?? const <BatchReport>[];
    final rows = sel == null ? all : all.where((b) => b.batchId == sel).toList();
    final daily = ref.watch(dailyReportProvider).valueOrNull ?? const <DailyReport>[];
    final purchases = ref.watch(purchasesProvider).valueOrNull ?? const <Ingredient>[];
    final ids = rows.map((b) => b.batchId).toSet();
    int sum(int Function(BatchReport) f) => rows.fold(0, (a, b) => a + f(b));
    final sales = sum((b) => b.sales), buy = sum((b) => b.purchases), cost = sum((b) => b.costs);
    final profit = Calc.netProfit(sales, buy, cost);

    Widget body;
    if (_tab < 2) {
      final isSales = _tab == 0;
      final color = isSales ? t.accent : const Color(0xFF2B59C3);
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: StatCard(label: isSales ? l.totalSales : l.totalPurchasesShort, value: Fmt.compact(isSales ? sales : buy))),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              label: isSales ? l.totalOrders : l.totalIngredients,
              value: isSales ? '${sum((b) => b.orderCount)}' : l.nItems('${purchases.where((p) => ids.contains(p.batchId)).length}'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isSales ? l.salesTrend : l.purchaseTrend, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            SizedBox(height: 150, child: _TrendChart(values: [for (final d in daily) (isSales ? d.sales : d.purchases).toDouble()], color: color)),
          ]),
        ),
        SectionHeader(l.detailsPerBatch),
        if (rows.isEmpty) EmptyText(l.noData),
        for (final b in rows) ListRow(title: b.name, subtitle: Fmt.range(b.start, b.end, context.locale), trailing: Text(Fmt.rp(isSales ? b.sales : b.purchases), style: const TextStyle(fontWeight: FontWeight.w800))),
      ]);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.comparisonPerBatch, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            SizedBox(height: 170, child: _CompareChart(rows: rows, a: t.accent, b: const Color(0xFF2B59C3), ink2: t.ink2)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Legend(color: t.accent, label: l.sales),
              const SizedBox(width: 16),
              _Legend(color: const Color(0xFF2B59C3), label: l.purchasesTitle),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatCard(label: l.sales, value: Fmt.compact(sales))),
          const SizedBox(width: 12),
          Expanded(child: StatCard(label: l.purchasesTitle, value: Fmt.compact(buy))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatCard(label: l.operatingCosts, value: Fmt.compact(cost))),
          const SizedBox(width: 12),
          Expanded(child: StatCard(label: l.netProfit, value: Fmt.compact(profit), valueColor: profit < 0 ? t.accent : t.ok, border: t.accent)),
        ]),
        SectionHeader(l.profitPerBatch),
        if (rows.isEmpty) EmptyText(l.noData),
        for (final b in rows) ListRow(title: b.name, trailing: Text(Fmt.rp(b.profit), style: TextStyle(fontWeight: FontWeight.w800, color: b.profit < 0 ? t.accent : t.ok))),
      ]);
    }

    return RefreshIndicator(
      onRefresh: () async => bumpRefresh(ref),
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        TopBar(title: l.reportsTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [const Expanded(child: PeriodButton()), const SizedBox(width: 8), Expanded(child: BatchSelect(batches: batches))]),
            const SizedBox(height: 12),
            SegTabs(labels: [l.sales, l.purchasesTitle, l.tabSummary], index: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 12),
            body,
            const SizedBox(height: 12),
            GhostButton(label: l.exportReport, icon: Icons.download_rounded, onPressed: () => showAppSheet(context, (_) => _ExportSheet(rows: rows, initial: ReportKind.values[_tab]))),
          ]),
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ]);
}

class _TrendChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _TrendChart({required this.values, required this.color});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final mx = values.fold<double>(0, (a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: mx == 0 ? 1 : mx * 1.15,
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: mx == 0 ? 1 : mx * 1.15 / 2, getDrawingHorizontalLine: (_) => FlLine(color: t.line, strokeWidth: 1)),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipItems: (s) => [for (final x in s) LineTooltipItem(Fmt.compact(x.y), const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))])),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
            color: color,
            barWidth: 3,
            isCurved: false,
            dotData: FlDotData(show: values.length <= 31, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 3, color: t.card, strokeColor: color, strokeWidth: 2.5)),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .08)),
          ),
        ],
      ),
      duration: context.noAnim ? Duration.zero : const Duration(milliseconds: 250),
    );
  }
}

class _CompareChart extends StatelessWidget {
  final List<BatchReport> rows;
  final Color a;
  final Color b;
  final Color ink2;
  const _CompareChart({required this.rows, required this.a, required this.b, required this.ink2});
  @override
  Widget build(BuildContext context) {
    // Tinggi relatif terhadap nilai terbesar
    final mx = rows.fold<int>(0, (m, r) => [m, r.sales, r.purchases].reduce((x, y) => x > y ? x : y));
    return BarChart(
      BarChartData(
        maxY: mx == 0 ? 1 : mx * 1.05,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('B${(v.toInt() + 1).toString().padLeft(2, '0')}', style: TextStyle(fontSize: 10, color: ink2))),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(x: i, barsSpace: 4, barRods: [
              BarChartRodData(toY: rows[i].sales.toDouble(), color: a, width: 18, borderRadius: BorderRadius.circular(6)),
              BarChartRodData(toY: rows[i].purchases.toDouble(), color: b, width: 18, borderRadius: BorderRadius.circular(6)),
            ]),
        ],
      ),
      duration: context.noAnim ? Duration.zero : const Duration(milliseconds: 250),
    );
  }
}

class _ExportSheet extends ConsumerStatefulWidget {
  final List<BatchReport> rows;
  final ReportKind initial;
  const _ExportSheet({required this.rows, required this.initial});
  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  late ReportKind _kind = widget.initial;
  ExportFormat _fmt = ExportFormat.xlsx;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final names = {ReportKind.penjualan: l.sales, ReportKind.bahan: l.purchasesTitle, ReportKind.ringkasan: l.tabSummary};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.exportReport, style: Theme.of(context).textTheme.titleMedium),
      Text(l.exportHint, style: Theme.of(context).textTheme.bodySmall),
      for (final k in ReportKind.values) RadioOption(label: names[k]!, on: _kind == k, onTap: () => setState(() => _kind = k)),
      const SizedBox(height: 14),
      ChoiceChips<ExportFormat>(values: ExportFormat.values, selected: _fmt, label: (f) => f == ExportFormat.xlsx ? 'Excel (.xlsx)' : 'PDF (.pdf)', onSelected: (f) => setState(() => _fmt = f)),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                final (s, e) = ref.read(periodProvider);
                final period = Fmt.range(s, e, context.locale);
                final table = buildTable(_kind, widget.rows, period, labels: {
                  'sales': l.sales, 'purchases': l.purchasesTitle, 'summary': l.tabSummary, 'costs': l.operatingCosts,
                  'profit': l.netProfit, 'orders': l.totalOrders, 'total': 'Total',
                });
                try {
                  await exportAndShare(table, _fmt, 'laporan-${_kind.name}-${Fmt.iso(s)}_${Fmt.iso(e)}');
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  toast(context, l.reportExported(names[_kind]!));
                } catch (_) {
                  if (context.mounted) toast(context, l.genericError);
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: Text(l.export),
      ),
    ]);
  }
}
