import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../format.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';
import 'common.dart';

/// Nama hari Senin..Minggu sesuai bahasa
List<String> weekdayShort(String locale) {
  final f = DateFormat.E(locale);
  // 2024-01-01 adalah Senin
  return [for (var i = 0; i < 7; i++) f.format(DateTime(2024, 1, 1 + i))];
}

/// Grid bulan 7 kolom, Senin awal pekan. Sel persegi seragam.
class MonthGrid extends StatelessWidget {
  final DateTime month;
  final Widget Function(DateTime day) cell;
  const MonthGrid({super.key, required this.month, required this.cell});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final first = DateTime(month.year, month.month, 1);
    final dim = DateTime(month.year, month.month + 1, 0).day;
    final off = first.weekday - 1;
    final cells = <Widget>[
      for (final w in weekdayShort(context.locale))
        Center(child: Text(w, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: t.ink2))),
      for (var i = 0; i < off; i++) const SizedBox.shrink(),
      for (var d = 1; d <= dim; d++) cell(DateTime(month.year, month.month, d)),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      childAspectRatio: 1,
      children: cells,
    );
  }
}

class MonthNav extends StatelessWidget {
  final DateTime month;
  final ValueChanged<int> onMove;
  const MonthNav({super.key, required this.month, required this.onMove});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          IconBtn(icon: Icons.chevron_left_rounded, label: context.l.prevMonth, onTap: () => onMove(-1)),
          Expanded(child: Text(DateFormat('MMMM y', context.locale).format(month), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
          IconBtn(icon: Icons.chevron_right_rounded, label: context.l.nextMonth, onTap: () => onMove(1)),
        ]),
      );
}

/// Sel tanggal standar
class DayCell extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final bool inRange;
  final bool isToday;
  final bool disabled;
  final bool strike;
  final Color? bg;
  final Color? fg;
  final VoidCallback? onTap;
  const DayCell({super.key, required this.day, this.selected = false, this.inRange = false, this.isToday = false, this.disabled = false, this.strike = false, this.bg, this.fg, this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final color = selected ? Colors.white : (fg ?? (inRange ? t.accent : t.ink));
    return Opacity(
      opacity: disabled ? .35 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: inRange ? 0 : 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? t.accent : (inRange ? t.accentTint : bg),
            borderRadius: inRange ? BorderRadius.zero : BorderRadius.circular(12),
            border: isToday && !selected ? Border.all(color: t.accent, width: 1.5) : null,
          ),
          child: Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color, decoration: strike ? TextDecoration.lineThrough : null)),
        ),
      ),
    );
  }
}

/// Pemilih tanggal kustom (bottom sheet). range=true untuk periode.
/// Hanya isi sheet yang dibangun ulang saat pindah bulan/pilih tanggal.
Future<(DateTime, DateTime?)?> pickDate(BuildContext context, {required DateTime initial, DateTime? initialEnd, bool range = false}) {
  return showAppSheet<(DateTime, DateTime?)>(context, (c) => _DateSheet(initial: initial, initialEnd: initialEnd, range: range));
}

class _DateSheet extends StatefulWidget {
  final DateTime initial;
  final DateTime? initialEnd;
  final bool range;
  const _DateSheet({required this.initial, this.initialEnd, required this.range});
  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime month = DateTime(widget.initial.year, widget.initial.month);
  late DateTime? s = widget.initial;
  late DateTime? e = widget.initialEnd;

  void tap(DateTime d) => setState(() {
        if (!widget.range) {
          s = d;
          return;
        }
        if (s == null || e != null) {
          s = d;
          e = null;
        } else if (d.isBefore(s!)) {
          s = d;
        } else {
          e = d;
        }
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final ready = s != null && (!widget.range || e != null);
    final now = today();
    String hint;
    if (widget.range) {
      hint = s == null ? l.selectStart : (e == null ? l.selectEnd : Fmt.range(s!, e!, context.locale));
    } else {
      hint = Fmt.date(s!, context.locale);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Text(widget.range ? l.selectPeriod : l.selectOrderDate, style: Theme.of(context).textTheme.titleMedium)),
        IconBtn(icon: Icons.close_rounded, label: l.close, onTap: () => Navigator.pop(context)),
      ]),
      MonthNav(month: month, onMove: (d) => setState(() => month = DateTime(month.year, month.month + d))),
      MonthGrid(
        month: month,
        cell: (d) {
          final on = d == s || d == e;
          final mid = widget.range && s != null && e != null && d.isAfter(s!) && d.isBefore(e!);
          return DayCell(day: d, selected: on, inRange: mid, isToday: d == now, onTap: () => tap(d));
        },
      ),
      Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(hint, style: Theme.of(context).textTheme.bodySmall)),
      FilledButton(
        onPressed: ready ? () => Navigator.pop(context, (s!, e)) : null,
        child: Text(l.apply),
      ),
    ]);
  }
}

/// Tombol periode (kalender rentang) — mengubah periodProvider
class PeriodButton extends ConsumerWidget {
  const PeriodButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (s, e) = ref.watch(periodProvider);
    final t = context.tk;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final r = await pickDate(context, initial: s, initialEnd: e, range: true);
        if (r != null && r.$2 != null) {
          ref.read(periodProvider.notifier).set(r.$1, r.$2!);
          ref.read(batchFilterProvider.notifier).state = null;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: t.card, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 18, color: t.ink),
          const SizedBox(width: 8),
          Expanded(child: Text(Fmt.range(s, e, context.locale), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

/// Dropdown batch ("Semua batch" + daftar batch)
class BatchSelect extends ConsumerWidget {
  final List<Batch> batches;
  const BatchSelect({super.key, required this.batches});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(batchFilterProvider);
    final ids = <String?>[null, ...batches.map((b) => b.id)];
    return SelectBox<String?>(
      value: ids.contains(sel) ? sel : null,
      items: ids,
      label: (id) {
        if (id == null) return context.l.allBatches;
        final b = batches.firstWhere((x) => x.id == id);
        return '${b.name} (${Fmt.range(b.start, b.end, context.locale)})';
      },
      onChanged: (v) => ref.read(batchFilterProvider.notifier).state = v,
    );
  }
}
