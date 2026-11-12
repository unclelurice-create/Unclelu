import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../data/settings_repository.dart';

class StoreProfileScreen extends ConsumerStatefulWidget {
  const StoreProfileScreen({super.key});
  @override
  ConsumerState<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends ConsumerState<StoreProfileScreen> {
  final _name = TextEditingController();
  Uint8List? _newPhoto;
  bool _removePhoto = false;
  bool _init = false;
  bool _busy = false;

  Future<void> _pick(ImageSource src) async {
    // Diperkecil maks. 480 px sebelum diunggah
    final f = await ImagePicker().pickImage(source: src, maxWidth: AppConfig.photoMaxSize, maxHeight: AppConfig.photoMaxSize, imageQuality: 85);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() {
      _newPhoto = bytes;
      _removePhoto = false;
    });
  }

  Future<void> _choose() async {
    final l = context.l;
    final src = await showAppSheet<ImageSource>(
      context,
      (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(l.fromGallery), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(l.fromCamera), onTap: () => Navigator.pop(c, ImageSource.camera)),
      ]),
    );
    if (src != null) await _pick(src);
  }

  Future<void> _save(String storeId) async {
    final l = context.l;
    final n = _name.text.trim();
    if (n.isEmpty) return toast(context, l.storeNameEmpty);
    setState(() => _busy = true);
    final repo = ref.read(settingsRepositoryProvider);
    try {
      if (_newPhoto != null) {
        final url = await repo.uploadStorePhoto(storeId, _newPhoto!);
        await repo.updateStore(storeId, name: n, photoUrl: url);
      } else if (_removePhoto) {
        await repo.removeStorePhoto(storeId);
        await repo.updateStore(storeId, name: n);
      } else {
        await repo.updateStore(storeId, name: n);
      }
      ref.invalidate(storeProvider);
      if (!mounted) return;
      toast(context, l.storeSaved);
      context.pop();
    } catch (_) {
      if (mounted) {
        toast(context, l.genericError);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = context.tk;
    final owner = ref.watch(isOwnerProvider);
    final store = ref.watch(storeProvider).valueOrNull;
    if (!_init && store != null) {
      _init = true;
      _name.text = store.name;
    }
    final url = _removePhoto ? null : store?.photoUrl;
    Widget photo = _newPhoto != null
        ? Image.memory(_newPhoto!, fit: BoxFit.cover, width: 120, height: 120)
        : (url != null && url.isNotEmpty ? Image.network(url, fit: BoxFit.cover, width: 120, height: 120) : const LogoTile(size: 120, radius: 0, padding: 16));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: owner ? l.storeProfile : l.accountProfile, onBack: () => context.pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              Center(
                child: GestureDetector(
                  onTap: owner ? _choose : null,
                  child: Stack(children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(36), border: Border.all(color: t.line)),
                      clipBehavior: Clip.antiAlias,
                      child: photo,
                    ),
                    if (owner)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle), child: const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 18)),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              if (owner)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(onPressed: _choose, child: Text(l.changePhoto)),
                  if (_newPhoto != null || (url != null && url.isNotEmpty))
                    TextButton(
                      onPressed: () => setState(() {
                        _newPhoto = null;
                        _removePhoto = true;
                      }),
                      child: Text(l.removePhoto),
                    ),
                ])
              else
                Text(l.onlyOwnerStore, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              FieldLabel(l.storeName),
              TextField(controller: _name, readOnly: !owner, maxLength: 30, decoration: InputDecoration(hintText: l.storeName, counterText: '')),
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.storeNameInfo, style: Theme.of(context).textTheme.bodySmall)),
              if (owner && store != null) ...[
                const SizedBox(height: 22),
                FilledButton(onPressed: _busy ? null : () => _save(store.id), child: Text(l.saveChanges)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
