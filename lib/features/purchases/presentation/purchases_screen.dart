import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calc.dart';
import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/calendar.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ingredient_form.dart';
import '../../settings/data/settings_repository.dart';
import '../data/purchase_repository.dart';

/// Batch tujuan input baru: batch terpilih, atau batch hari ini, atau batch terakhir.
String? targetBatchId(List<Batch> batches, String? selected) {
  if (selected != null) return selected;
  final b = Calc.batchFor(today(), batches) ?? (batches.isEmpty ? null : batches.last);
  return b?.id;
}

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});
  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  int _tab = 1;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final owner = ref.watch(isOwnerProvider);
    final batches = ref.watch(batchesProvider).valueOrNull ?? const <Batch>[];
    final (s, e) = ref.watch(periodProvider);
    final sel = ref.watch(batchFilterProvider);
    final visible = Calc.batchesInPeriod(batches, s, e, only: sel);
    final ids = visible.map((b) => b.id).toSet();
    final purchases = (ref.watch(purchasesProvider).valueOrNull ?? const <Ingredient>[]).where((p) => ids.contains(p.batchId)).toList();
    final tabs = [l.tabAdd, l.tabList, l.tabSummary, if (owner) l.tabCosts];
    if (_tab >= tabs.length) _tab = 1;

    Widget body;
    switch (_tab) {
      case 0:
        body = IngredientForm(
          title: l.addIngredient,
          units: purchaseUnits,
          onSubmit: (i) async {
            final b = targetBatchId(batches, sel);
            if (b == null) {
              toast(context, l.chooseBatchFirst);
              return false;
            }
            try {
              await ref.read(purchaseRepositoryProvider).addPurchase(batchId: b, name: i.name, qty: i.qty, unit: i.unit, unitPrice: i.unitPrice, packContent: i.packContent, packUnit: i.packUnit);
              bumpRefresh(ref);
              if (mounted) {
                toast(context, l.added(i.name));
                setState(() => _tab = 1);
              }
              return true;
            } catch (_) {
              if (mounted) toast(context, l.genericError);
              return false;
            }
          },
        );
      case 1:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader(l.ingredientList, padding: const EdgeInsets.fromLTRB(0, 4, 0, 10), trailing: Text(l.nItems('${purchases.length}'), style: Theme.of(context).textTheme.bodySmall)),
          if (purchases.isEmpty) EmptyText(l.noPurchases),
          for (final p in purchases)
            ListRow(
              title: p.name,
              subtitle: ingredientLine(context, p),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(Fmt.rp(Calc.ingredientTotal(p.qty, p.unitPrice)), style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: l.delete,
                  icon: Icon(Icons.delete_outline_rounded, color: context.tk.accent),
                  onPressed: () async {
                    await ref.read(purchaseRepositoryProvider).deletePurchase(p.id);
                    bumpRefresh(ref);
                  },
                ),
              ]),
            ),
          TotalRow(l.totalPurchases, Fmt.rp(Calc.purchaseTotal(purchases))),
        ]);
      case 2:
        final all = ref.watch(purchasesProvider).valueOrNull ?? const <Ingredient>[];
        final sums = {for (final b in visible) b.id: Calc.purchaseTotal(all.where((p) => p.batchId == b.id))};
        final mx = sums.values.fold<int>(0, (a, b) => a > b ? a : b);
        body = AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.purchasesPerBatch, style: Theme.of(context).textTheme.titleMedium),
            if (visible.isEmpty) EmptyText(l.noData),
            for (final b in visible) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 5),
                child: Row(children: [
                  Expanded(child: Text('${b.name} (${Fmt.range(b.start, b.end, context.locale)})', style: Theme.of(context).textTheme.bodySmall)),
                  Text(Fmt.rp(sums[b.id]!), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: mx == 0 ? 0 : sums[b.id]! / mx, minHeight: 8, backgroundColor: context.tk.seg, color: context.tk.accent),
              ),
            ],
          ]),
        );
      default:
        body = _CostsTab(batches: batches, visibleIds: ids, selected: sel);
    }

    return ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 24), children: [
      TopBar(title: l.purchasesTitle),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [const Expanded(child: PeriodButton()), const SizedBox(width: 8), Expanded(child: BatchSelect(batches: batches))]),
          const SizedBox(height: 12),
          SegTabs(labels: tabs, index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 12),
          body,
        ]),
      ),
    ]);
  }
}

class _CostsTab extends ConsumerStatefulWidget {
  final List<Batch> batches;
  final Set<String> visibleIds;
  final String? selected;
  const _CostsTab({required this.batches, required this.visibleIds, required this.selected});
  @override
  ConsumerState<_CostsTab> createState() => _CostsTabState();
}

class _CostsTabState extends ConsumerState<_CostsTab> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  String _cat = costCategories.first;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final costs = (ref.watch(costsProvider).valueOrNull ?? const <OperatingCost>[]).where((c) => widget.visibleIds.contains(c.batchId)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.addCost, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(controller: _name, decoration: InputDecoration(hintText: l.costName)),
          const SizedBox(height: 12),
          ChoiceChips<String>(values: costCategories, selected: _cat, label: (k) => costCatLabel(context, k), onSelected: (k) => setState(() => _cat = k)),
          FieldLabel(l.costAmount),
          MoneyField(controller: _amount),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(l.addCost),
            onPressed: () async {
              final n = _name.text.trim(), a = Fmt.parsePrice(_amount.text);
              if (n.isEmpty || a <= 0) return toast(context, l.fillCost);
              final b = targetBatchId(widget.batches, widget.selected);
              if (b == null) return toast(context, l.chooseBatchFirst);
              await ref.read(purchaseRepositoryProvider).addCost(batchId: b, name: n, category: _cat, amount: a);
              bumpRefresh(ref);
              _name.clear();
              _amount.clear();
              if (context.mounted) toast(context, l.added(n));
            },
          ),
        ]),
      ),
      SectionHeader(l.costList, trailing: Text(l.nItems('${costs.length}'), style: Theme.of(context).textTheme.bodySmall)),
      if (costs.isEmpty) EmptyText(l.noCosts),
      for (final c in costs)
        ListRow(
          title: c.name,
          subtitle: costCatLabel(context, c.category),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(Fmt.rp(c.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(
              tooltip: l.delete,
              icon: Icon(Icons.delete_outline_rounded, color: context.tk.accent),
              onPressed: () async {
                await ref.read(purchaseRepositoryProvider).deleteCost(c.id);
                bumpRefresh(ref);
              },
            ),
          ]),
        ),
      TotalRow(l.totalCosts, Fmt.rp(costs.fold<int>(0, (a, c) => a + c.amount))),
    ]);
  }
}
