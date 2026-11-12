import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../providers.dart';
import '../theme.dart';

extension L10nX on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
  String get locale => Localizations.localeOf(this).languageCode;
  bool get noAnim => MediaQuery.of(this).disableAnimations;
}

String statusLabel(BuildContext c, OrderStatus s) => switch (s) {
      OrderStatus.diproses => c.l.statusDiproses,
      OrderStatus.selesai => c.l.statusSelesai,
      OrderStatus.batal => c.l.statusBatal,
    };

String methodLabel(BuildContext c, PaymentMethod m) => switch (m) {
      PaymentMethod.tunai => c.l.cash,
      PaymentMethod.transfer => c.l.transfer,
      PaymentMethod.qris => c.l.qris,
    };

String costCatLabel(BuildContext c, String k) => switch (k) {
      'kemasan' => c.l.catKemasan,
      'gas_listrik' => c.l.catGasListrik,
      'gaji' => c.l.catGaji,
      'sewa' => c.l.catSewa,
      _ => c.l.catLainnya,
    };

/// Kartu putih membulat
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor, this.onTap, this.margin = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: margin,
      child: Material(
        color: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: borderColor ?? t.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Kartu "hero" gelap dengan lingkaran aksen
class HeroCard extends StatelessWidget {
  final List<Widget> children;
  const HeroCard({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      decoration: BoxDecoration(color: t.hero, borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(right: -40, top: -40, child: Container(width: 140, height: 140, decoration: BoxDecoration(color: t.accent.withValues(alpha: .9), shape: BoxShape.circle))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color? bg;
  final Color? fg;
  const Pill(this.text, {super.key, this.bg, this.fg});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg ?? t.okTint, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg ?? t.ok)),
    );
  }
}

/// Badge status/pembayaran
class StatusBadge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const StatusBadge(this.text, {super.key, required this.bg, required this.fg});
  factory StatusBadge.order(BuildContext c, OrderStatus s) {
    final t = c.tk;
    return switch (s) {
      OrderStatus.diproses => StatusBadge(statusLabel(c, s), bg: t.blueTint, fg: t.blue),
      OrderStatus.selesai => StatusBadge(statusLabel(c, s), bg: t.okTint, fg: t.ok),
      OrderStatus.batal => StatusBadge(statusLabel(c, s), bg: t.accentTint, fg: t.accent),
    };
  }
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
      );
}

/// Segmented tabs (gaya .seg)
class SegTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const SegTabs({super.key, required this.labels, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.seg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: i == index
                    ? BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(11), boxShadow: const [BoxShadow(color: Color(0x1F3C140A), blurRadius: 4, offset: Offset(0, 1))])
                    : null,
                child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: i == index ? t.accent : t.ink2)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Chip pilihan tunggal
class ChoiceChips<T> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  const ChoiceChips({super.key, required this.values, required this.selected, required this.label, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final v in values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: v == selected ? t.ink : t.card,
                  border: Border.all(color: v == selected ? t.ink : t.line),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(label(v), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: v == selected ? t.bg : t.ink2)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Stepper − / +
class QtyStepper extends StatelessWidget {
  final int value;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const QtyStepper({super.key, required this.value, required this.onDec, required this.onInc});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    Widget b(String s, VoidCallback f, String label) => Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: f,
            borderRadius: BorderRadius.circular(9),
            child: Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(9)), child: Text(s, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.seg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        b('−', onDec, '-'),
        SizedBox(width: 30, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
        b('+', onInc, '+'),
      ]),
    );
  }
}

/// Logo aplikasi sebagai mask berwarna aksen (terang) / putih di atas aksen (gelap)
class LogoTile extends StatelessWidget {
  final double size;
  final double radius;
  final double padding;
  final bool forceLight;
  const LogoTile({super.key, required this.size, required this.radius, this.padding = 10, this.forceLight = false});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final dark = t.dark && !forceLight;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(color: dark ? t.accent : t.accentTint, borderRadius: BorderRadius.circular(radius)),
      child: Image.asset(AppConfig.logoAsset, color: dark ? Colors.white : t.accent, colorBlendMode: BlendMode.srcIn, semanticLabel: AppConfig.appName),
    );
  }
}

/// Foto toko atau logo default
class StoreAvatar extends ConsumerWidget {
  final double size;
  final double radius;
  const StoreAvatar({super.key, required this.size, required this.radius});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(storeProvider).valueOrNull?.photoUrl;
    if (url == null || url.isEmpty) return LogoTile(size: size, radius: radius, padding: size / 9);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => LogoTile(size: size, radius: radius, padding: size / 9)),
    );
  }
}

/// Judul layar + tombol kembali
class TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  const TopBar({super.key, required this.title, this.onBack, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Row(children: [
          if (onBack != null) ...[IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack!, label: context.l.back), const SizedBox(width: 10)],
          Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (trailing != null) trailing!,
        ]),
      );
}

class IconBtn extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback onTap;
  final String label;
  final Color? color;
  const IconBtn({super.key, this.icon, this.child, required this.onTap, required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.line)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(width: 40, height: 40, child: Center(child: child ?? Icon(icon, size: 20, color: color ?? t.ink))),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;
  const SectionHeader(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(0, 20, 0, 10)});
  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), if (trailing != null) trailing!]),
      );
}

class EmptyText extends StatelessWidget {
  final String text;
  const EmptyText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.tk.ink2, fontSize: 13.5)),
      );
}

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 14),
        child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.tk.ink2)),
      );
}

/// Baris daftar (.item)
class ListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? top;
  final Widget? trailing;
  final VoidCallback? onTap;
  const ListRow({super.key, this.leading, required this.title, this.subtitle, this.top, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (top != null) Padding(padding: const EdgeInsets.only(bottom: 5), child: top!),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: TextStyle(fontSize: 12.5, color: t.ink2))),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
    );
  }
}

class TotalRow extends StatelessWidget {
  final String label;
  final String value;
  const TotalRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.tk.line))),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? extra;
  final Color? border;
  const StatCard({super.key, required this.label, required this.value, this.valueColor, this.extra, this.border});
  @override
  Widget build(BuildContext context) => AppCard(
        borderColor: border,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: context.tk.ink2)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: valueColor))),
          if (extra != null) ...[const SizedBox(height: 4), extra!],
        ]),
      );
}

// ------------------------------------------------------------------ input
/// Format titik ribuan saat mengetik: 56000 -> 56.000 (nilai tetap integer)
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final s = d.isEmpty ? '' : Fmt.thousands(int.parse(d));
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

/// Jumlah desimal: hanya digit, koma, titik
final qtyFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const MoneyField({super.key, required this.controller, this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [ThousandsFormatter()],
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '0',
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 6), child: Text('Rp', style: TextStyle(fontWeight: FontWeight.w600, color: context.tk.ink2))),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      );
}

/// Dropdown sederhana bergaya .sel
class SelectBox<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  const SelectBox({super.key, required this.value, required this.items, required this.label, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: t.card, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(14)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: t.card,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: t.ink, fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily),
          items: [for (final i in items) DropdownMenuItem(value: i, child: Text(label(i), overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Kotak centang berwarna aksen
class AccentCheckbox extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  const AccentCheckbox({super.key, required this.value, required this.label, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      checked: value,
      label: label,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: context.noAnim ? Duration.zero : const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: value ? t.accent : Colors.transparent, border: Border.all(color: value ? t.accent : t.ink2, width: 2), borderRadius: BorderRadius.circular(7)),
            child: value ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: TextStyle(color: t.ink2, fontSize: 13))),
        ]),
      ),
    );
  }
}

/// Bottom sheet standar
Future<T?> showAppSheet<T>(BuildContext context, Widget Function(BuildContext) builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: context.noAnim ? AnimationStyle.noAnimation : null,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(c).viewInsets.bottom),
        child: SingleChildScrollView(child: builder(c)),
      ),
    );

/// Konfirmasi hapus
Future<bool> confirmDelete(BuildContext context, String title, String body) async {
  final r = await showAppSheet<bool>(
    context,
    (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: Theme.of(c).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text(body, style: Theme.of(c).textTheme.bodySmall),
      const SizedBox(height: 16),
      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.l.delete)),
      const SizedBox(height: 8),
      GhostButton(label: c.l.cancel, onPressed: () => Navigator.pop(c, false)),
    ]),
  );
  return r ?? false;
}

class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const GhostButton({super.key, required this.label, this.icon, this.onPressed});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final style = FilledButton.styleFrom(backgroundColor: t.accentTint, foregroundColor: t.accent);
    if (icon == null) return FilledButton(onPressed: onPressed, style: style, child: Text(label));
    return FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label), style: style);
  }
}

/// Async helper untuk widget: tampilkan loading/error ringkas
class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T) data;
  const AsyncView({super.key, required this.value, required this.data});
  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => EmptyText('${context.l.genericError}\n${errorCode(e)}'),
      );
}
