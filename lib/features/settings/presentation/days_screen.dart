import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/calendar.dart';
import '../../../core/widgets/common.dart';
import '../data/settings_repository.dart';

/// Hari buka/tutup website. Semua hari default buka; hanya hari tutup yang dicatat.
class DaysScreen extends ConsumerStatefulWidget {
  const DaysScreen({super.key});
  @override
  ConsumerState<DaysScreen> createState() => _DaysScreenState();
}

class _DaysScreenState extends ConsumerState<DaysScreen> {
  DateTime _month = DateTime(today().year, today().month);

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = context.tk;
    final data = ref.watch(closedDaysProvider).valueOrNull;
    final dates = data?.$1 ?? const <String, String>{};
    final weekly = data?.$2 ?? const <int>{};
    final now = today();
    final names = weekdayShort(context.locale);
    final upcoming = dates.keys.where((k) => k.compareTo(Fmt.iso(now)) >= 0).toList()..sort();

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: l.openClosedDays, onBack: () => context.pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(l.daysInfo, style: Theme.of(context).textTheme.bodySmall),
              SectionHeader(l.weeklyClosed, padding: const EdgeInsets.fromLTRB(0, 16, 0, 8)),
              Row(children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Builder(builder: (_) {
                      final dow = (i + 1) % 7; // Sen=1 .. Min=0
                      final on = weekly.contains(dow);
                      return Semantics(
                        button: true,
                        selected: on,
                        child: GestureDetector(
                          onTap: () async {
                            await ref.read(settingsRepositoryProvider).setWeekday(dow, !on);
                            bumpRefresh(ref);
                          },
                          child: Container(
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: on ? t.accent : t.card, border: Border.all(color: on ? t.accent : t.line), borderRadius: BorderRadius.circular(12)),
                            child: Text(names[i], maxLines: 1, overflow: TextOverflow.clip, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : t.ink2)),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ]),
              const SizedBox(height: 14),
              MonthNav(month: _month, onMove: (d) => setState(() => _month = DateTime(_month.year, _month.month + d))),
              MonthGrid(
                month: _month,
                cell: (d) {
                  final special = dates.containsKey(Fmt.iso(d));
                  final wk = weekly.contains(dowOf(d));
                  return DayCell(
                    day: d,
                    isToday: d == now,
                    disabled: d.isBefore(now),
                    strike: special || wk,
                    bg: special ? t.accentTint : (wk ? t.seg : null),
                    fg: special ? t.accent : (wk ? t.ink2 : null),
                    onTap: () => showAppSheet(context, (_) => _DaySheet(day: d, closedNote: dates[Fmt.iso(d)], weeklyClosed: wk)),
                  );
                },
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 16, runSpacing: 6, children: [
                _Legend(bg: t.accentTint, border: t.accent, label: l.legendSpecial),
                _Legend(bg: t.seg, border: t.ink2, label: l.legendWeekly),
                _Legend(bg: Colors.transparent, border: t.accent, label: l.today),
              ]),
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.tapDateHint, style: Theme.of(context).textTheme.bodySmall)),
              SectionHeader(l.specialClosedDates),
              if (upcoming.isEmpty) EmptyText(l.noSpecialClosed),
              for (final k in upcoming)
                ListRow(
                  title: Fmt.date(Fmt.parseIso(k), context.locale),
                  subtitle: (dates[k] ?? '').isEmpty ? l.noNote : dates[k],
                  trailing: IconButton(
                    tooltip: l.delete,
                    icon: Icon(Icons.delete_outline_rounded, color: t.accent),
                    onPressed: () async {
                      await ref.read(settingsRepositoryProvider).openDate(Fmt.parseIso(k));
                      bumpRefresh(ref);
                    },
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color bg;
  final Color border;
  final String label;
  const _Legend({required this.bg, required this.border, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: border, width: 1.2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.tk.ink2)),
      ]);
}

class _DaySheet extends ConsumerStatefulWidget {
  final DateTime day;
  final String? closedNote;
  final bool weeklyClosed;
  const _DaySheet({required this.day, required this.closedNote, required this.weeklyClosed});
  @override
  ConsumerState<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends ConsumerState<_DaySheet> {
  late bool _open = widget.closedNote == null && !widget.weeklyClosed;
  late final _note = TextEditingController(text: widget.closedNote ?? '');

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final label = Fmt.date(widget.day, context.locale);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      FieldLabel(l.status),
      SegTabs(labels: [l.open, l.closedLabel], index: _open ? 0 : 1, onChanged: (i) => setState(() => _open = i == 0)),
      if (!_open) ...[
        FieldLabel(l.noteOptional),
        TextField(controller: _note, decoration: InputDecoration(hintText: l.closeNoteHint)),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () async {
          final repo = ref.read(settingsRepositoryProvider);
          try {
            if (_open) {
              // Membuka tanggal yang tutup rutin menghapus aturan rutin hari itu
              if (widget.weeklyClosed) await repo.setWeekday(dowOf(widget.day), false);
              await repo.openDate(widget.day);
            } else {
              await repo.closeDate(widget.day, _note.text);
            }
            bumpRefresh(ref);
            if (!context.mounted) return;
            Navigator.pop(context);
            toast(context, _open ? l.dayOpened(label) : l.dayClosed(label));
          } catch (_) {
            if (context.mounted) toast(context, l.genericError);
          }
        },
        child: Text(l.save),
      ),
    ]);
  }
}
