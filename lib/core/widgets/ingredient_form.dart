import 'package:flutter/material.dart';

import '../calc.dart';
import '../format.dart';
import '../models.dart';
import 'common.dart';

/// Hasil form bahan
class IngredientInput {
  final String name;
  final double qty;
  final String unit;
  final int unitPrice;
  final double? packContent;
  final String? packUnit;
  const IngredientInput(this.name, this.qty, this.unit, this.unitPrice, this.packContent, this.packUnit);
}

/// Form bahan (belanja & resep): nama, jumlah desimal, satuan, harga per satuan,
/// isi per pack (jika pack) dan perkiraan total langsung.
class IngredientForm extends StatefulWidget {
  final String title;
  final List<String> units;
  final Future<bool> Function(IngredientInput) onSubmit;
  const IngredientForm({super.key, required this.title, required this.units, required this.onSubmit});
  @override
  State<IngredientForm> createState() => _IngredientFormState();
}

class _IngredientFormState extends State<IngredientForm> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _content = TextEditingController();
  late String _unit = widget.units.first;
  String _packUnit = 'pcs';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _qty, _price, _content]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l;
    final n = _name.text.trim(), q = Fmt.parseQty(_qty.text), p = Fmt.parsePrice(_price.text);
    if (n.isEmpty || q <= 0 || p <= 0) return toastMsg(l.fillIngredient(_unit));
    final c = Fmt.parseQty(_content.text);
    if (_unit == 'pack' && c <= 0) return toastMsg(l.fillPackContent);
    setState(() => _busy = true);
    final ok = await widget.onSubmit(IngredientInput(n, q, _unit, p, _unit == 'pack' ? c : null, _unit == 'pack' ? _packUnit : null));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _name.clear();
      _qty.clear();
      _price.clear();
      _content.clear();
    }
  }

  void toastMsg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final q = Fmt.parseQty(_qty.text), p = Fmt.parsePrice(_price.text), c = Fmt.parseQty(_content.text);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(controller: _name, decoration: InputDecoration(hintText: l.ingredientName)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [qtyFormatter],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: l.quantity),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 104, child: SelectBox<String>(value: _unit, items: widget.units, label: (u) => u, onChanged: (u) => setState(() => _unit = u))),
        ]),
        if (_unit == 'pack') ...[
          FieldLabel(l.packContent),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _content,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [qtyFormatter],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: l.packContentHint),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 104, child: SelectBox<String>(value: _packUnit, items: packUnits, label: (u) => u, onChanged: (u) => setState(() => _packUnit = u))),
          ]),
          if (c > 0 && p > 0)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.perContent(Fmt.rp(Calc.pricePerContent(p, c)), _packUnit), style: Theme.of(context).textTheme.bodySmall)),
        ],
        FieldLabel(l.pricePer(_unit)),
        MoneyField(controller: _price, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(l.estimatedTotal, style: Theme.of(context).textTheme.bodySmall)),
          Text(Fmt.rp(Calc.ingredientTotal(q, p)), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _busy ? null : _submit, icon: const Icon(Icons.add_rounded), label: Text(widget.title)),
      ]),
    );
  }
}

/// "50 kg × Rp12.000/kg" atau "1 pack (isi 25 pcs) × Rp6.250/pack · Rp250/pcs"
String ingredientLine(BuildContext context, Ingredient i) {
  final pack = i.unit == 'pack' && i.packContent != null && i.packUnit != null;
  final contains = pack ? ' ${context.l.containsPack(Fmt.qty(i.packContent!), i.packUnit!)}' : '';
  final per = pack ? ' · ${Fmt.rp(Calc.pricePerContent(i.unitPrice, i.packContent!))}/${i.packUnit}' : '';
  return '${Fmt.qty(i.qty)} ${i.unit}$contains × ${Fmt.rp(i.unitPrice)}/${i.unit}$per';
}
