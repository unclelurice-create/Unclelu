import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../data/order_repository.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  OrderStatus? _filter; // null = semua
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    // Owner & Staff toko website sama-sama menerima order website
    final web = ref.watch(storeProvider).valueOrNull?.isWebsiteStore ?? false;
    final webCount = web ? (ref.watch(webOrdersProvider).valueOrNull?.length ?? 0) : 0;
    return Column(children: [
      TopBar(
        title: l.navOrders,
        trailing: web
            ? Badge(
                isLabelVisible: webCount > 0,
                label: Text('$webCount'),
                child: IconBtn(icon: Icons.language_rounded, label: l.webOrders, onTap: () => context.push('/orders/web')),
              )
            : null,
      ),
      Expanded(
        child: AsyncView(
          value: ref.watch(allOrdersProvider),
          data: (orders) {
            int count(OrderStatus? s) => s == null ? orders.length : orders.where((o) => o.status == s).length;
            final q = _q.toLowerCase();
            final list = orders.where((o) => (_filter == null || o.status == _filter) && '${o.code} ${o.customer}'.toLowerCase().contains(q)).toList();
            return RefreshIndicator(
              onRefresh: () async => bumpRefresh(ref),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), children: [
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.searchOrders),
                ),
                const SizedBox(height: 10),
                ChoiceChips<OrderStatus?>(
                  values: const [null, OrderStatus.diproses, OrderStatus.selesai, OrderStatus.batal],
                  selected: _filter,
                  label: (s) => '${s == null ? l.all : statusLabel(context, s)} (${count(s)})',
                  onSelected: (s) => setState(() => _filter = s),
                ),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  EmptyText(orders.isEmpty ? l.noOrdersStart : l.noMatchingOrders)
                else
                  for (final o in list) OrderTile(order: o),
              ]),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: FilledButton.icon(onPressed: () => context.push('/orders/new'), icon: const Icon(Icons.add_rounded), label: Text(l.newOrder)),
      ),
    ]);
  }
}

/// Kartu order + bottom sheet status & pembayaran
class OrderTile extends ConsumerWidget {
  final Order order;
  const OrderTile({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tk;
    final o = order;
    return ListRow(
      onTap: () => showAppSheet(context, (_) => StatusSheet(order: o)),
      top: Wrap(spacing: 6, children: [
        StatusBadge.order(context, o.status),
        if (o.status != OrderStatus.batal)
          o.isPaid
              ? StatusBadge(o.method == null ? context.l.paid : context.l.paidWith(methodLabel(context, o.method!)), bg: t.okTint, fg: t.ok)
              : StatusBadge(context.l.notPaid, bg: t.warnTint, fg: t.warn),
      ]),
      title: '#${o.code}',
      subtitle: '${Fmt.date(o.date, context.locale)} · ${o.customer}',
      trailing: Text(Fmt.rp(o.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}

class StatusSheet extends ConsumerStatefulWidget {
  final Order order;
  const StatusSheet({super.key, required this.order});
  @override
  ConsumerState<StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends ConsumerState<StatusSheet> {
  late OrderStatus _status = widget.order.status;
  late PaymentStatus _pay = widget.order.payment;
  late PaymentMethod _method = widget.order.method ?? PaymentMethod.tunai;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final o = widget.order;
    final items = o.lines.map((x) => x.isAdditional ? '+ ${x.name} ×${x.qty}' : '${x.name} ×${x.qty}').join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(l.updateStatus, style: Theme.of(context).textTheme.titleMedium)),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            context.push('/orders/edit/${o.id}');
          },
          child: Text(l.editOrder),
        ),
      ]),
      Text('#${o.code} · ${o.customer} · ${Fmt.rp(o.total)}', style: Theme.of(context).textTheme.bodySmall),
      if (items.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(items, style: Theme.of(context).textTheme.bodySmall)),
      if (o.note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${o.note}”', style: Theme.of(context).textTheme.bodySmall)),
      for (final s in OrderStatus.values) RadioOption(label: statusLabel(context, s), on: _status == s, onTap: () => setState(() => _status = s)),
      FieldLabel(l.payment),
      PaymentPicker(status: _pay, method: _method, onChanged: (p, m) => setState(() {
            _pay = p;
            _method = m;
          })),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await ref.read(orderRepositoryProvider).setStatus(o.id, _status, _pay, _method);
                  bumpRefresh(ref);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  toast(context, l.statusUpdated);
                } catch (e) {
                  if (!mounted) return;
                  toast(context, l.genericError);
                  setState(() => _busy = false);
                }
              },
        child: Text(l.saveStatus),
      ),
    ]);
  }
}

class RadioOption extends StatelessWidget {
  final String label;
  final String? sub;
  final bool on;
  final VoidCallback onTap;
  const RadioOption({super.key, required this.label, this.sub, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: on ? t.accentTint : t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: on ? t.accent : t.line, width: 1.5)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? t.accent : const Color(0xFFD5C9C5), width: on ? 5 : 2))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (sub != null) Text(sub!, style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Lunas / Belum bayar + metode (hanya bagian ini yang dibangun ulang)
class PaymentPicker extends StatelessWidget {
  final PaymentStatus status;
  final PaymentMethod method;
  final void Function(PaymentStatus, PaymentMethod) onChanged;
  const PaymentPicker({super.key, required this.status, required this.method, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegTabs(labels: [l.paid, l.notPaid], index: status == PaymentStatus.lunas ? 0 : 1, onChanged: (i) => onChanged(i == 0 ? PaymentStatus.lunas : PaymentStatus.belum, method)),
      if (status == PaymentStatus.lunas) ...[
        const SizedBox(height: 10),
        ChoiceChips<PaymentMethod>(values: PaymentMethod.values, selected: method, label: (m) => methodLabel(context, m), onSelected: (m) => onChanged(status, m)),
      ],
    ]);
  }
}
