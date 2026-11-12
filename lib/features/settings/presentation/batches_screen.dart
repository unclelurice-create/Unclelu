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
import '../data/settings_repository.dart';

final batchOrderCountProvider = FutureProvider<Map<String, int>>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(settingsRepositoryProvider).orderCountPerBatch();
});

class BatchesScreen extends ConsumerWidget {
  const BatchesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = context.tk;
    final counts = ref.watch(batchOrderCountProvider).valueOrNull ?? const <String, int>{};
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: l.manageBatches, onBack: () => context.pop()),
          Expanded(
            child: AsyncView(
              value: ref.watch(batchesProvider),
              data: (batches) => ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(l.batchInfo, style: Theme.of(context).textTheme.bodySmall)),
                  TextButton(onPressed: () => showAppSheet(context, (_) => BatchForm(batches: batches)), child: Text(l.newBatchBtn)),
                ]),
                const SizedBox(height: 10),
                if (batches.isEmpty) EmptyText(l.noBatches),
                for (final b in batches)
                  ListRow(
                    onTap: () => showAppSheet(context, (_) => BatchForm(batches: batches, batch: b, orderCount: counts[b.id] ?? 0)),
                    title: b.name,
                    subtitle: l.batchOrders(Fmt.range(b.start, b.end, context.locale), '${counts[b.id] ?? 0}'),
                    trailing: b.isOpen ? StatusBadge(l.open, bg: t.okTint, fg: t.ok) : StatusBadge(l.closed, bg: t.warnTint, fg: t.warn),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class BatchForm extends ConsumerStatefulWidget {
  final List<Batch> batches;
  final Batch? batch;
  final int orderCount;
  const BatchForm({super.key, required this.batches, this.batch, this.orderCount = 0});
  @override
  ConsumerState<BatchForm> createState() => _BatchFormState();
}

class _BatchFormState extends ConsumerState<BatchForm> {
  late final TextEditingController _name;
  late DateTime _s;
  late DateTime _e;
  late bool _open;

  @override
  void initState() {
    super.initState();
    final b = widget.batch;
    if (b != null) {
      _name = TextEditingController(text: b.name);
      _s = b.start;
      _e = b.end;
      _open = b.isOpen;
    } else {
      final (s, e) = Calc.nextBatchRange(widget.batches, today());
      _name = TextEditingController(text: 'Batch ${(widget.batches.length + 1).toString().padLeft(2, '0')}');
      _s = s;
      _e = e;
      _open = true;
    }
  }

  Future<void> _save() async {
    final l = context.l;
    final n = _name.text.trim();
    if (n.isEmpty) return toast(context, l.fillBatchName);
    if (_e.isBefore(_s)) return toast(context, l.endBeforeStart);
    final x = Calc.overlapping(_s, _e, widget.batches, exceptId: widget.batch?.id);
    if (x != null) return toast(context, l.overlapsWith(x.name));
    try {
      await ref.read(settingsRepositoryProvider).saveBatch(id: widget.batch?.id, name: n, start: _s, end: _e, open: _open);
      bumpRefresh(ref);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.saved(n));
    } catch (e) {
      if (mounted) toast(context, errorCode(e).contains('batches_no_overlap') ? l.overlapsWith('?') : l.genericError);
    }
  }

  Future<void> _delete() async {
    final l = context.l;
    final b = widget.batch!;
    if (widget.orderCount > 0) return toast(context, l.batchHasOrders);
    if (!await confirmDelete(context, l.deleteQ(b.name), l.batchHasOrdersInfo)) return;
    try {
      await ref.read(settingsRepositoryProvider).deleteBatch(b.id);
      bumpRefresh(ref);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.deleted(b.name));
    } catch (e) {
      if (mounted) toast(context, errorCode(e).contains('BATCH_ADA_ORDER') ? l.batchHasOrders : l.genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.batch == null ? l.newBatch : l.editBatch, style: Theme.of(context).textTheme.titleMedium),
      FieldLabel(l.batchName),
      TextField(controller: _name, decoration: InputDecoration(hintText: l.batchName)),
      FieldLabel(l.period),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final r = await pickDate(context, initial: _s, initialEnd: _e, range: true);
          if (r != null && r.$2 != null) {
            setState(() {
              _s = r.$1;
              _e = r.$2!;
            });
          }
        },
        child: InputDecorator(
          decoration: const InputDecoration(),
          child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 18), const SizedBox(width: 10), Text(Fmt.range(_s, _e, context.locale))]),
        ),
      ),
      FieldLabel(l.status),
      SegTabs(labels: [l.open, l.closed], index: _open ? 0 : 1, onChanged: (i) => setState(() => _open = i == 0)),
      const SizedBox(height: 16),
      FilledButton(onPressed: _save, child: Text(l.save)),
      if (widget.batch != null) ...[const SizedBox(height: 8), GhostButton(label: l.deleteBatch, onPressed: _delete)],
    ]);
  }
}
