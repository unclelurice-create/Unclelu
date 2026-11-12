import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calc.dart';
import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/calendar.dart';
import '../../../core/widgets/common.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/presentation/orders_screen.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../settings/data/settings_repository.dart';

/// Penjualan per menu dalam periode
final salesMixProvider = FutureProvider<(Map<String?, int>, int)>((ref) {
  ref.watch(refreshTickProvider);
  final (s, e) = ref.watch(periodProvider);
  return ref.watch(orderRepositoryProvider).salesByMenu(s, e);
});

const _donutColors = [Color(0xFFF97066), Color(0xFFFDB022), Color(0xFF7A5AF8), Color(0xFF2E90FA), Color(0xFF12B76A), Color(0xFFEE46BC)];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = context.tk;
    final owner = ref.watch(isOwnerProvider);
    final store = ref.watch(storeProvider).valueOrNull;
    final (s, e) = ref.watch(periodProvider);
    final orders = ref.watch(allOrdersProvider).valueOrNull ?? const <Order>[];
    final purchases = ref.watch(purchasesProvider).valueOrNull ?? const <Ingredient>[];
    final costs = ref.watch(costsProvider).valueOrNull ?? const <OperatingCost>[];
    final batches = ref.watch(batchesProvider).valueOrNull ?? const <Batch>[];

    bool inP(DateTime d, DateTime a, DateTime b) => !d.isBefore(a) && !d.isAfter(b);
    final inPeriod = orders.where((o) => inP(o.date, s, e)).toList();
    final sales = Calc.salesTotal(inPeriod);
    final (ps, pe) = Calc.previousPeriod(s, e);
    final prevSales = Calc.salesTotal(orders.where((o) => inP(o.date, ps, pe)));
    final change = Calc.changePct(sales, prevSales);
    final orderCount = inPeriod.where((o) => o.status != OrderStatus.batal).length;

    // Belanja & biaya: per batch yang masuk periode (sesuai batch-nya)
    final batchIds = Calc.batchesInPeriod(batches, s, e).map((b) => b.id).toSet();
    final purchaseSum = Calc.purchaseTotal(purchases.where((p) => batchIds.contains(p.batchId)));
    final costSum = costs.where((c) => batchIds.contains(c.batchId)).fold<int>(0, (a, c) => a + c.amount);
    final profit = Calc.netProfit(sales, purchaseSum, costSum);
    final unpaidOrders = orders.where((o) => o.status != OrderStatus.batal && o.payment == PaymentStatus.belum).toList();

    return RefreshIndicator(
      onRefresh: () async => bumpRefresh(ref),
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
        Row(children: [
          const StoreAvatar(size: 46, radius: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.hello, style: Theme.of(context).textTheme.bodySmall),
              Text(l.helloStore(store?.name ?? ''), style: Theme.of(context).textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          IconBtn(
            label: l.language,
            onTap: () => ref.read(uiPrefsProvider.notifier).toggleLang(),
            child: Text(context.locale == 'en' ? 'Id' : 'En', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: t.accent)),
          ),
        ]),
        const SizedBox(height: 12),
        const PeriodButton(),
        const SizedBox(height: 12),
        HeroCard(children: [
          Text(l.totalSales, style: const TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF))),
          Padding(padding: const EdgeInsets.only(top: 6, bottom: 10), child: Text(Fmt.rp(sales), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1))),
          if (change != null)
            Pill('${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1).replaceAll('.', context.locale == 'id' ? ',' : '.')}% ${l.vsPrevious}', bg: const Color(0x24FFFFFF), fg: Colors.white),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatCard(label: l.totalOrders, value: '$orderCount')),
          const SizedBox(width: 12),
          Expanded(child: StatCard(label: l.ingredientPurchases, value: Fmt.compact(purchaseSum))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (owner) ...[
            Expanded(
              child: StatCard(
                label: l.netProfit,
                value: Fmt.compact(profit),
                valueColor: profit < 0 ? t.accent : t.ok,
                extra: Pill(l.marginPct('${Calc.profitMargin(profit, sales)}')),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: StatCard(
              label: l.unpaid,
              value: Fmt.compact(Calc.unpaidTotal(orders)),
              extra: Pill(l.nOrders('${unpaidOrders.length}'), bg: t.warnTint, fg: t.warn),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        const _SalesDonut(),
        SectionHeader(l.recentOrders, trailing: TextButton(onPressed: () => context.go('/orders'), child: Text(l.seeAll))),
        if (orders.isEmpty) EmptyText(l.noOrdersYet) else for (final o in orders.take(2)) OrderTile(order: o),
      ]),
    );
  }
}

class _SalesDonut extends ConsumerWidget {
  const _SalesDonut();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final menus = (ref.watch(menusProvider).valueOrNull ?? const <MenuItem>[]).where((m) => !m.isAdditional).toList();
    final mix = ref.watch(salesMixProvider).valueOrNull ?? (const <String?, int>{}, 0);
    final shares = menuShares(menus, mix.$1, mix.$2);
    final colors = [for (var i = 0; i < shares.length; i++) shares[i].isAdditional ? const Color(0xFFD5C9C5) : (i == 0 ? t.accent : _donutColors[(i - 1) % _donutColors.length])];
    final empty = shares.every((x) => x.amount == 0);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l.salesByMenu, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        Row(children: [
          SizedBox(
            width: 104,
            height: 104,
            child: PieChart(PieChartData(
              centerSpaceRadius: 31,
              sectionsSpace: 0,
              startDegreeOffset: -90,
              sections: empty
                  ? [PieChartSectionData(value: 1, color: t.line, radius: 21, showTitle: false)]
                  : [
                      for (var i = 0; i < shares.length; i++)
                        if (shares[i].amount > 0) PieChartSectionData(value: shares[i].amount.toDouble(), color: colors[i], radius: 21, showTitle: false)
                    ],
            ), duration: context.noAnim ? Duration.zero : const Duration(milliseconds: 250)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(children: [
              for (var i = 0; i < shares.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(shares[i].isAdditional ? context.l.additional : shares[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
                    Text(shares[i].pct > 0 && shares[i].pct < 1 ? '<1%' : '${shares[i].pct.round()}%', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
        ]),
      ]),
    );
  }
}
