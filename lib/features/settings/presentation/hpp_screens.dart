import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/calc.dart';
import '../../../core/config.dart';
import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/ingredient_form.dart';
import '../data/settings_repository.dart';

/// Semua resep toko (khusus owner)
class HppData {
  final Map<String, int> bases;
  final List<Ingredient> items; // batchId dipakai sebagai menuId
  const HppData(this.bases, this.items);
  int baseOf(String menuId) => bases[menuId] ?? AppConfig.defaultBasePortions;
  List<Ingredient> itemsOf(String menuId) => items.where((i) => i.batchId == menuId).toList();
  int costOf(String menuId) => Calc.costPerPortion(itemsOf(menuId), baseOf(menuId));
}

final hppProvider = FutureProvider<HppData?>((ref) async {
  ref.watch(refreshTickProvider);
  if (!ref.watch(isOwnerProvider)) return null;
  final r = ref.watch(settingsRepositoryProvider);
  return HppData(await r.recipeBases(), await r.recipeItems());
});

class HppListScreen extends ConsumerWidget {
  const HppListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final menus = ref.watch(menusProvider).valueOrNull ?? const <MenuItem>[];
    final hpp = ref.watch(hppProvider).valueOrNull;
    Widget row(MenuItem m) {
      final c = hpp?.costOf(m.id) ?? 0;
      return ListRow(
        onTap: () => context.push('/settings/hpp/${m.id}'),
        title: m.name,
        subtitle: c > 0 ? l.hppRow(Fmt.rp(c), '${Calc.menuMargin(m.price, c)}') : l.notFilled,
        trailing: Text(Fmt.rp(m.price), style: const TextStyle(fontWeight: FontWeight.w800)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: l.ingredientCost, onBack: () => context.pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(l.hppInfo, style: Theme.of(context).textTheme.bodySmall),
              SectionHeader(l.menuSection),
              ...menus.where((m) => !m.isAdditional).map(row),
              if (!menus.any((m) => !m.isAdditional)) EmptyText(l.noMenus),
              SectionHeader(l.additional),
              ...menus.where((m) => m.isAdditional).map(row),
              if (!menus.any((m) => m.isAdditional)) EmptyText(l.noAdditionals),
            ]),
          ),
        ]),
      ),
    );
  }
}

class HppDetailScreen extends ConsumerStatefulWidget {
  final String menuId;
  const HppDetailScreen({super.key, required this.menuId});
  @override
  ConsumerState<HppDetailScreen> createState() => _HppDetailScreenState();
}

class _HppDetailScreenState extends ConsumerState<HppDetailScreen> {
  int _target = 1;
  final _base = TextEditingController();
  bool _init = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = context.tk;
    final menu = (ref.watch(menusProvider).valueOrNull ?? const <MenuItem>[]).where((m) => m.id == widget.menuId).firstOrNull;
    final hpp = ref.watch(hppProvider).valueOrNull;
    if (menu == null || hpp == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final base = hpp.baseOf(menu.id);
    if (!_init) {
      _init = true;
      _base.text = '$base';
    }
    final items = hpp.itemsOf(menu.id);
    final total = Calc.recipeTotal(items);
    final per = Calc.costPerPortion(items, base);
    final profit = menu.price - per;
    final k = _target;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: l.ingredientCost, onBack: () => context.pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(menu.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              HeroCard(children: [
                Text(l.costForN('$base'), style: const TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF))),
                Padding(padding: const EdgeInsets.only(top: 6, bottom: 10), child: Text(Fmt.rp(total), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white))),
                Pill(l.perPortion(Fmt.rp(per)), bg: const Color(0x24FFFFFF), fg: Colors.white),
                const SizedBox(height: 14),
                Wrap(spacing: 12, runSpacing: 4, children: [
                  Text(l.sellPrice(Fmt.rp(menu.price)), style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                  Text(l.profitPerPortion(Fmt.rp(profit)), style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                  Text(l.marginPct('${Calc.menuMargin(menu.price, per)}'), style: const TextStyle(fontSize: 12.5, color: Colors.white)),
                ]),
              ]),
              FieldLabel(l.recipePortions),
              TextField(
                controller: _base,
                keyboardType: TextInputType.number,
                onSubmitted: (v) => _saveBase(v),
                onTapOutside: (_) => _saveBase(_base.text),
              ),
              SectionHeader(l.portionConversion, padding: const EdgeInsets.fromLTRB(0, 22, 0, 10)),
              ChoiceChips<int>(values: const [1, 5, 10, 25, 50], selected: _target, label: (n) => l.nPortions('$n'), onSelected: (n) => setState(() => _target = n)),
              const SizedBox(height: 10),
              AppCard(
                child: items.isEmpty
                    ? EmptyText(l.noIngredients)
                    : Column(children: [
                        for (final i in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(i.name),
                                  Text(Calc.niceQty(Calc.scaleQty(i.qty, k, base), i.unit, packContent: i.packContent, packUnit: i.packUnit), style: TextStyle(fontSize: 12.5, color: t.ink2)),
                                ]),
                              ),
                              Text(Fmt.rp(Calc.scaleCost(i.qty, i.unitPrice, k, base)), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        TotalRow(l.costNPortions('$k'), Fmt.rp((total * k / base).round())),
                      ]),
              ),
              SectionHeader(l.recipeIngredients, trailing: Text(l.nItems('${items.length}'), style: Theme.of(context).textTheme.bodySmall)),
              for (final i in items)
                ListRow(
                  title: i.name,
                  subtitle: ingredientLine(context, i),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(Fmt.rp(Calc.ingredientTotal(i.qty, i.unitPrice)), style: const TextStyle(fontWeight: FontWeight.w800)),
                    IconButton(
                      tooltip: l.delete,
                      icon: Icon(Icons.delete_outline_rounded, color: t.accent),
                      onPressed: () async {
                        await ref.read(settingsRepositoryProvider).deleteRecipeItem(i.id);
                        bumpRefresh(ref);
                      },
                    ),
                  ]),
                ),
              const SizedBox(height: 6),
              IngredientForm(
                title: l.addIngredient,
                units: recipeUnits,
                onSubmit: (i) async {
                  try {
                    await ref.read(settingsRepositoryProvider).addRecipeItem(menu.id, name: i.name, qty: i.qty, unit: i.unit, unitPrice: i.unitPrice, packContent: i.packContent, packUnit: i.packUnit);
                    bumpRefresh(ref);
                    if (mounted) toast(context, l.added(i.name));
                    return true;
                  } catch (_) {
                    if (mounted) toast(context, l.genericError);
                    return false;
                  }
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _saveBase(String v) async {
    final n = int.tryParse(v.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final hpp = ref.read(hppProvider).valueOrNull;
    if (n <= 0) {
      _base.text = '${hpp?.baseOf(widget.menuId) ?? AppConfig.defaultBasePortions}';
      return;
    }
    if (hpp != null && hpp.baseOf(widget.menuId) == n) return;
    await ref.read(settingsRepositoryProvider).setBasePortions(widget.menuId, n);
    bumpRefresh(ref);
  }
}
