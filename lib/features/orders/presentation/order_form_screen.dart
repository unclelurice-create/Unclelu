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
import '../../settings/data/settings_repository.dart';
import '../data/order_repository.dart';
import 'orders_screen.dart';

/// Data awal (mis. dari order website)
class OrderFormSeed {
  final String customer;
  final DateTime date;
  final String note;
  final Map<String, CartEntry> cart;
  final int? webOrderId;
  const OrderFormSeed({this.customer = '', required this.date, this.note = '', this.cart = const {}, this.webOrderId});
}

class OrderFormScreen extends ConsumerStatefulWidget {
  final String? editId;
  final OrderFormSeed? seed;
  const OrderFormScreen({super.key, this.editId, this.seed});
  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  // Keranjang di ValueNotifier: +/- hanya membangun ulang kartu & footer.
  final cart = ValueNotifier<Map<String, CartEntry>>({});
  final pay = ValueNotifier<(PaymentStatus, PaymentMethod)>((PaymentStatus.belum, PaymentMethod.tunai));
  final _customer = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = today();
  Order? _editing;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.seed;
    if (s != null) {
      _customer.text = s.customer;
      _note.text = s.note;
      _date = s.date;
      cart.value = s.cart;
    }
  }

  void _loadEdit(List<Order> orders) {
    if (_loaded || widget.editId == null) return;
    final o = orders.where((x) => x.id == widget.editId).firstOrNull;
    if (o == null) return;
    _loaded = true;
    _editing = o;
    _customer.text = o.customer == 'Pelanggan umum' ? '' : o.customer;
    _note.text = o.note ?? '';
    _date = o.date;
    cart.value = Cart.fromLines(o.lines);
    pay.value = (o.payment, o.method ?? PaymentMethod.tunai);
  }

  Future<void> _save(List<MenuItem> menus, List<MenuItem> adds, List<Batch> batches) async {
    final l = context.l;
    final c = Cart.prune(cart.value, menus, adds);
    if (Cart.itemCount(c) == 0) return toast(context, l.addAtLeastOne);
    final b = Calc.batchFor(_date, batches);
    if (b == null) return toast(context, l.noBatchForDate);
    if (!b.isOpen) return toast(context, l.batchClosedError);
    setState(() => _busy = true);
    final repo = ref.read(orderRepositoryProvider);
    final items = Cart.toRpc(c, menus);
    try {
      if (_editing != null) {
        final o = await repo.update(_editing!.id, customer: _customer.text, date: _date, note: _note.text, items: items, pay: pay.value.$1, method: pay.value.$2);
        bumpRefresh(ref);
        if (!mounted) return;
        toast(context, l.orderUpdated(o.code));
        context.pop();
      } else {
        final o = await repo.create(customer: _customer.text, date: _date, note: _note.text, items: items, pay: pay.value.$1, method: pay.value.$2, webOrderId: widget.seed?.webOrderId);
        bumpRefresh(ref);
        if (!mounted) return;
        toast(context, l.orderSaved(o.code));
        context.go('/orders');
      }
    } catch (e) {
      if (!mounted) return;
      toast(context, isBatchClosed(e) ? l.batchClosedError : (isNoBatch(e) ? l.noBatchForDate : l.genericError));
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    cart.dispose();
    pay.dispose();
    _customer.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final owner = ref.watch(isOwnerProvider);
    final allMenus = ref.watch(menusProvider).valueOrNull ?? const <MenuItem>[];
    final menus = allMenus.where((m) => !m.isAdditional).toList();
    final adds = allMenus.where((m) => m.isAdditional).toList();
    final batches = ref.watch(batchesProvider).valueOrNull ?? const <Batch>[];
    final closed = ref.watch(closedDaysProvider).valueOrNull;
    if (widget.editId != null) _loadEdit(ref.watch(allOrdersProvider).valueOrNull ?? const []);
    // Menu yang dihapus ikut hilang dari keranjang
    final pruned = Cart.prune(cart.value, menus, adds);
    if (pruned.length != cart.value.length) WidgetsBinding.instance.addPostFrameCallback((_) => cart.value = Cart.prune(cart.value, menus, adds));

    final b = Calc.batchFor(_date, batches);
    final batchNote = b == null
        ? l.noBatchForDate
        : l.inBatch('${b.name} (${Fmt.range(b.start, b.end, context.locale)})', b.isOpen ? l.open : l.closed) + (isClosedOnWebsite(_date, closed) ? l.closedOnWebsite : '');

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: _editing != null || widget.editId != null ? l.editOrder : l.newOrder, onBack: () => context.pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), children: [
              FieldLabel(l.orderDate),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final r = await pickDate(context, initial: _date);
                  if (r != null) setState(() => _date = r.$1);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 18), const SizedBox(width: 10), Text(Fmt.date(_date, context.locale))]),
                ),
              ),
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(batchNote, style: Theme.of(context).textTheme.bodySmall)),
              FieldLabel(l.customer),
              TextField(controller: _customer, decoration: InputDecoration(hintText: l.customerHint)),
              SectionHeader(l.products, padding: const EdgeInsets.fromLTRB(0, 22, 0, 10), trailing: owner ? TextButton(onPressed: () => context.push('/settings/menus'), child: Text(l.manageMenu)) : null),
              if (menus.isEmpty) EmptyText(l.noMenusAdd),
              for (final m in menus)
                ValueListenableBuilder<Map<String, CartEntry>>(
                  key: ValueKey(m.id),
                  valueListenable: cart,
                  builder: (_, c, __) => m.isAlacarte
                      ? _AlacarteCard(menu: m, flavors: menus.where((x) => !x.isAlacarte).toList(), adds: adds, entry: c[m.id], cart: cart)
                      : _MenuCard(menu: m, adds: adds, entry: c[m.id], cart: cart),
                ),
              FieldLabel(l.payment),
              ValueListenableBuilder(
                valueListenable: pay,
                builder: (_, p, __) => PaymentPicker(status: p.$1, method: p.$2, onChanged: (s, m) => pay.value = (s, m)),
              ),
              FieldLabel(l.noteOptional),
              TextField(controller: _note, maxLines: 2, decoration: InputDecoration(hintText: l.noteHint)),
            ]),
          ),
          ValueListenableBuilder<Map<String, CartEntry>>(
            valueListenable: cart,
            builder: (_, c, __) {
              final n = Cart.itemCount(c);
              final t = context.tk;
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(l.nItems('$n'), style: Theme.of(context).textTheme.bodySmall),
                      Text(Fmt.rp(Cart.total(c, menus, adds)), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  Opacity(
                    opacity: n == 0 ? .45 : 1,
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 52), padding: const EdgeInsets.symmetric(horizontal: 26)),
                      onPressed: _busy ? null : () => _save(menus, adds, batches),
                      child: Text(_editing != null ? l.saveChanges : l.saveOrder),
                    ),
                  ),
                ]),
              );
            },
          ),
        ]),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItem menu;
  final List<MenuItem> adds;
  final CartEntry? entry;
  final ValueNotifier<Map<String, CartEntry>> cart;
  const _MenuCard({required this.menu, required this.adds, required this.entry, required this.cart});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final q = entry?.qty ?? 0;
    return _CardShell(
      on: q > 0,
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(menu.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(Fmt.rp(menu.price), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          if (q > 0)
            QtyStepper(value: q, onDec: () => cart.value = Cart.decMenu(cart.value, menu.id), onInc: () => cart.value = Cart.incMenu(cart.value, menu.id))
          else
            Material(
              color: t.accentTint,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => cart.value = Cart.incMenu(cart.value, menu.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 16, color: t.accent),
                    const SizedBox(width: 4),
                    Text(context.l.add, style: TextStyle(color: t.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
            ),
        ]),
        for (final a in adds) _AddRow(menu: menu, add: a, qty: entry?.additions[a.id] ?? 0, enabled: q > 0, cart: cart),
      ],
    );
  }
}

class _AlacarteCard extends StatelessWidget {
  final MenuItem menu;
  final List<MenuItem> flavors;
  final List<MenuItem> adds;
  final CartEntry? entry;
  final ValueNotifier<Map<String, CartEntry>> cart;
  const _AlacarteCard({required this.menu, required this.flavors, required this.adds, required this.entry, required this.cart});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final l = context.l;
    final q = entry?.qty ?? 0;
    return _CardShell(on: q > 0, children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(menu.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${Fmt.rp(menu.price)} · ${l.aLaCarte}', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        if (q > 0) StatusBadge(l.nPortions('$q'), bg: t.okTint, fg: t.ok),
      ]),
      Padding(padding: const EdgeInsets.only(top: 12), child: Text(l.chooseFlavor, style: Theme.of(context).textTheme.bodySmall)),
      if (flavors.isEmpty) EmptyText(l.noFlavors),
      for (final f in flavors)
        _DashedRow(children: [
          Expanded(child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          QtyStepper(
            value: entry?.flavors[f.id] ?? 0,
            onDec: () => cart.value = Cart.decFlavor(cart.value, menu.id, f.id),
            onInc: () => cart.value = Cart.incFlavor(cart.value, menu.id, f.id),
          ),
        ]),
      for (final a in adds) _AddRow(menu: menu, add: a, qty: entry?.additions[a.id] ?? 0, enabled: q > 0, cart: cart),
    ]);
  }
}

class _AddRow extends StatelessWidget {
  final MenuItem menu;
  final MenuItem add;
  final int qty;
  final bool enabled;
  final ValueNotifier<Map<String, CartEntry>> cart;
  const _AddRow({required this.menu, required this.add, required this.qty, required this.enabled, required this.cart});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : .55,
        child: _DashedRow(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '+ ${add.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              TextSpan(text: '  ${Fmt.rp(add.price)}', style: TextStyle(color: context.tk.ink2, fontSize: 13)),
            ])),
          ),
          QtyStepper(
            value: qty,
            onDec: () => cart.value = Cart.decAdd(cart.value, menu.id, add.id),
            onInc: () {
              final next = Cart.incAdd(cart.value, menu, add.id);
              if (next == null) {
                toast(context, context.l.chooseFlavorFirst);
              } else {
                cart.value = next;
              }
            },
          ),
        ]),
      );
}

class _DashedRow extends StatelessWidget {
  final List<Widget> children;
  const _DashedRow({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.tk.line))),
        child: Row(children: children),
      );
}

class _CardShell extends StatelessWidget {
  final bool on;
  final List<Widget> children;
  const _CardShell({required this.on, required this.children});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return AnimatedContainer(
      duration: context.noAnim ? Duration.zero : const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? t.accent : t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
