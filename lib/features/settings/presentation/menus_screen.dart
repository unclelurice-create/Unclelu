import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config.dart';
import '../../../core/format.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../data/settings_repository.dart';
import 'hpp_screens.dart';

class MenusScreen extends ConsumerWidget {
  const MenusScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final hpp = ref.watch(hppProvider).valueOrNull;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: l.manageMenu, onBack: () => context.pop()),
          Expanded(
            child: AsyncView(
              value: ref.watch(menusProvider),
              data: (all) {
                final menus = all.where((m) => !m.isAdditional).toList();
                final adds = all.where((m) => m.isAdditional).toList();
                Widget row(MenuItem m) {
                  final cost = hpp?.costOf(m.id);
                  return ListRow(
                    leading: m.photoUrl == null
                        ? null
                        : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(m.photoUrl!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48))),
                    title: m.name,
                    subtitle: [Fmt.rp(m.price), if (m.isAlacarte) l.aLaCarte, if (cost != null && cost > 0) l.costHint(Fmt.rp(cost))].join(' · '),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconBtn(icon: Icons.edit_outlined, label: m.isAdditional ? l.editAdditional : l.editMenu, onTap: () => showAppSheet(context, (_) => MenuForm(item: m, category: m.category))),
                      const SizedBox(width: 6),
                      IconBtn(
                        icon: Icons.delete_outline_rounded,
                        color: context.tk.accent,
                        label: l.delete,
                        onTap: () async {
                          if (!await confirmDelete(context, l.deleteQ(m.name), l.deleteMenuInfo)) return;
                          await ref.read(settingsRepositoryProvider).deleteMenu(m.id);
                          bumpRefresh(ref);
                          if (context.mounted) toast(context, l.deleted(m.name));
                        },
                      ),
                    ]),
                  );
                }

                return ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 24), children: [
                  SectionHeader(l.menuSection, padding: const EdgeInsets.only(bottom: 10), trailing: TextButton(onPressed: () => showAppSheet(context, (_) => const MenuForm(category: MenuCategory.menu)), child: Text(l.newMenu))),
                  if (menus.isEmpty) EmptyText(l.noMenus),
                  for (final m in menus) row(m),
                  SectionHeader(l.additional, trailing: TextButton(onPressed: () => showAppSheet(context, (_) => const MenuForm(category: MenuCategory.additional)), child: Text(l.newAdditional))),
                  if (adds.isEmpty) EmptyText(l.noAdditionals),
                  for (final m in adds) row(m),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class MenuForm extends ConsumerStatefulWidget {
  final MenuItem? item;
  final MenuCategory category;
  const MenuForm({super.key, this.item, required this.category});
  @override
  ConsumerState<MenuForm> createState() => _MenuFormState();
}

class _MenuFormState extends ConsumerState<MenuForm> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _price = TextEditingController(text: widget.item == null ? '' : Fmt.thousands(widget.item!.price));
  late bool _ac = widget.item?.isAlacarte ?? false;
  late final _desc = TextEditingController(text: widget.item?.description ?? '');
  Uint8List? _photo;
  bool _removePhoto = false;
  bool _busy = false;

  Future<void> _pickPhoto() async {
    final l = context.l;
    final src = await showAppSheet<ImageSource>(
      context,
      (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(l.fromGallery), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(l.fromCamera), onTap: () => Navigator.pop(c, ImageSource.camera)),
      ]),
    );
    if (src == null) return;
    // Diperkecil sebelum diunggah supaya website tetap ringan
    final f = await ImagePicker().pickImage(source: src, maxWidth: AppConfig.menuPhotoMaxSize, maxHeight: AppConfig.menuPhotoMaxSize, imageQuality: 80);
    if (f == null) return;
    final b = await f.readAsBytes();
    setState(() {
      _photo = b;
      _removePhoto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final isMenu = widget.category == MenuCategory.menu;
    final title = widget.item == null ? (isMenu ? l.addMenu : l.addAdditional) : (isMenu ? l.editMenu : l.editAdditional);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      FieldLabel(l.name),
      TextField(controller: _name, decoration: InputDecoration(hintText: isMenu ? l.menuName : l.additionalName)),
      FieldLabel(l.price),
      MoneyField(controller: _price),
      if (isMenu) ...[
        FieldLabel(l.menuDescription),
        TextField(controller: _desc, maxLines: 2, maxLength: 120, decoration: InputDecoration(hintText: l.menuDescHint, counterText: '')),
        FieldLabel(l.menuPhoto),
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 72,
              child: _photo != null
                  ? Image.memory(_photo!, fit: BoxFit.cover)
                  : (!_removePhoto && widget.item?.photoUrl != null
                      ? Image.network(widget.item!.photoUrl!, fit: BoxFit.cover)
                      : ColoredBox(color: context.tk.seg, child: Icon(Icons.image_outlined, color: context.tk.ink2))),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: _pickPhoto, child: Text(_photo != null || (!_removePhoto && widget.item?.photoUrl != null) ? l.changePhoto : l.addPhoto)),
          if (_photo != null || (!_removePhoto && widget.item?.photoUrl != null))
            TextButton(
              onPressed: () => setState(() {
                _photo = null;
                _removePhoto = true;
              }),
              child: Text(l.removePhoto),
            ),
        ]),
        Padding(padding: const EdgeInsets.only(top: 14), child: AccentCheckbox(value: _ac, label: l.alaCarteCheck, onChanged: (v) => setState(() => _ac = v))),
      ],
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                final n = _name.text.trim(), p = Fmt.parsePrice(_price.text);
                if (n.isEmpty || p <= 0) return toast(context, l.fillNamePrice);
                setState(() => _busy = true);
                try {
                  await ref.read(settingsRepositoryProvider).saveMenu(
                        id: widget.item?.id, name: n, price: p, category: widget.category, isAlacarte: _ac,
                        description: _desc.text, photo: _photo, removePhoto: _removePhoto,
                      );
                  bumpRefresh(ref);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  toast(context, l.saved(n));
                } catch (_) {
                  if (!mounted) return;
                  toast(context, l.genericError);
                  setState(() => _busy = false);
                }
              },
        child: Text(l.save),
      ),
    ]);
  }
}
