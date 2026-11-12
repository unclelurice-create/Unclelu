import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import '../../settings/data/settings_repository.dart';
import '../data/order_repository.dart';
import 'order_form_screen.dart';

/// Order masuk dari website (status baru, terbaru di atas)
class WebOrdersScreen extends ConsumerWidget {
  const WebOrdersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: l.webOrders, onBack: () => context.pop()),
          Expanded(
            child: AsyncView(
              value: ref.watch(webOrdersProvider),
              data: (list) => RefreshIndicator(
                onRefresh: () async => bumpRefresh(ref),
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                  if (list.isEmpty) EmptyText(l.noWebOrders),
                  for (final w in list) _WebOrderCard(order: w),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _WebOrderCard extends ConsumerWidget {
  final WebOrder order;
  const _WebOrderCard({required this.order});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final w = order;
    final items = w.items.map((i) {
      final extra = [if (i['sauce'] != null) i['sauce'], ...((i['tambahan'] as List?) ?? const []).map((e) => '+$e')].join(', ');
      return '${i['menu']} ×${i['qty']}${extra.isEmpty ? '' : ' ($extra)'}';
    }).join(' · ');
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(w.nama, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(Fmt.rp(w.total), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 2),
        Text('${Fmt.date(w.tanggal, context.locale)} · ${w.phone}${w.pengambilan == null ? '' : ' · ${w.pengambilan}'}', style: Theme.of(context).textTheme.bodySmall),
        if (w.alamat != null) Text(w.alamat!, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Text(items, style: const TextStyle(fontSize: 13)),
        if (w.catatan != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('“${w.catatan}”', style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () {
            final menus = ref.read(menusProvider).valueOrNull ?? const <MenuItem>[];
            final (cart, missing) = cartFromWebItems(w.items, menus);
            for (final m in missing) {
              toast(context, l.menuNotFound(m));
            }
            final note = [
              if (w.pengambilan != null) '${l.pickup}: ${w.pengambilan}',
              if (w.alamat != null) w.alamat!,
              w.phone,
              if (w.ongkir > 0) 'Ongkir ${Fmt.rp(w.ongkir)}',
              if (w.catatan != null) w.catatan!,
            ].join(' · ');
            context.push('/orders/new', extra: OrderFormSeed(customer: w.nama, date: w.tanggal, note: note, cart: cart, webOrderId: w.id));
          },
          child: Text(l.makeOrder),
        ),
      ]),
    );
  }
}
