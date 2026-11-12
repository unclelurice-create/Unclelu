import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/models.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../../orders/presentation/orders_screen.dart';
import '../data/settings_repository.dart';

final usersProvider = FutureProvider<List<Profile>>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(settingsRepositoryProvider).users();
});

/// Password acak 8 karakter (tanpa karakter yang mirip)
String randomPassword([Random? r]) {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final rnd = r ?? Random.secure();
  return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
}

String friendlyUserError(BuildContext c, Object e) {
  final code = errorCode(e);
  final l = c.l;
  if (code.contains('EMAIL_TERDAFTAR')) return l.emailTaken;
  if (code.contains('PASSWORD_PENDEK')) return l.passwordMin;
  if (code.contains('MINIMAL_SATU_OWNER')) return l.needOneOwner;
  if (code.contains('TIDAK_BISA_HAPUS_DIRI')) return l.cantDeleteSelf;
  return l.genericError;
}

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = context.tk;
    final me = ref.watch(currentUserIdProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: l.manageUsers, onBack: () => context.pop()),
          Expanded(
            child: AsyncView(
              value: ref.watch(usersProvider),
              data: (users) => ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(l.usersInfo, style: Theme.of(context).textTheme.bodySmall)),
                  TextButton(onPressed: () => showAppSheet(context, (_) => const _NewStaffSheet()), child: Text(l.newStaffBtn)),
                ]),
                const SizedBox(height: 10),
                for (final u in users)
                  ListRow(
                    onTap: () => showAppSheet(context, (_) => _EditUserSheet(user: u, isMe: u.id == me, owners: users.where((x) => x.isOwner).length)),
                    leading: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.accentTint, borderRadius: BorderRadius.circular(14)),
                      child: Text((u.fullName.isEmpty ? u.email : u.fullName).characters.first.toUpperCase(), style: TextStyle(color: t.accent, fontWeight: FontWeight.w800)),
                    ),
                    title: '${u.fullName.isEmpty ? u.email : u.fullName}${u.id == me ? ' ${l.you}' : ''}',
                    subtitle: u.email,
                    trailing: u.isOwner ? StatusBadge(l.roleOwner, bg: t.okTint, fg: t.ok) : StatusBadge(l.roleStaff, bg: t.blueTint, fg: t.blue),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NewStaffSheet extends ConsumerStatefulWidget {
  const _NewStaffSheet();
  @override
  ConsumerState<_NewStaffSheet> createState() => _NewStaffSheetState();
}

class _NewStaffSheetState extends ConsumerState<_NewStaffSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.addStaff, style: Theme.of(context).textTheme.titleMedium),
      FieldLabel(l.name),
      TextField(controller: _name, decoration: InputDecoration(hintText: l.staffName)),
      FieldLabel(l.email),
      TextField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: InputDecoration(hintText: l.staffEmail)),
      FieldLabel(l.staffPassword),
      Row(children: [
        // Password ditampilkan agar mudah disampaikan ke staf
        Expanded(child: TextField(controller: _pw, autocorrect: false, enableSuggestions: false, decoration: InputDecoration(hintText: l.minChars))),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: () => setState(() => _pw.text = randomPassword()), child: Text(l.random)),
      ]),
      Padding(padding: const EdgeInsets.only(top: 10), child: Text(l.staffLoginInfo, style: Theme.of(context).textTheme.bodySmall)),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                final n = _name.text.trim(), e = _email.text.trim();
                if (n.isEmpty || !RegExp(r'^\S+@\S+$').hasMatch(e)) return toast(context, l.invalidNameEmail);
                if (_pw.text.length < AppConfig.minPasswordLength) return toast(context, l.passwordMin);
                setState(() => _busy = true);
                try {
                  await ref.read(settingsRepositoryProvider).inviteStaff(n, e, _pw.text);
                  bumpRefresh(ref);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  toast(context, l.added(n));
                } catch (err) {
                  if (!context.mounted) return;
                  toast(context, friendlyUserError(context, err));
                  setState(() => _busy = false);
                }
              },
        child: Text(l.addStaff),
      ),
    ]);
  }
}

class _EditUserSheet extends ConsumerStatefulWidget {
  final Profile user;
  final bool isMe;
  final int owners;
  const _EditUserSheet({required this.user, required this.isMe, required this.owners});
  @override
  ConsumerState<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends ConsumerState<_EditUserSheet> {
  late Role _role = widget.user.role;
  final _pw = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    final l = context.l;
    final u = widget.user;
    if (widget.isMe && _role != u.role) return toast(context, l.cantChangeOwnRole);
    if (u.isOwner && _role == Role.staff && widget.owners <= 1) return toast(context, l.needOneOwner);
    final pw = _pw.text;
    if (pw.isNotEmpty && pw.length < AppConfig.minPasswordLength) return toast(context, l.passwordMin);
    setState(() => _busy = true);
    final repo = ref.read(settingsRepositoryProvider);
    try {
      if (_role != u.role) await repo.setRole(u.id, _role);
      if (pw.isNotEmpty && u.role == Role.staff) await repo.setStaffPassword(u.id, pw);
      bumpRefresh(ref);
      if (!mounted) return;
      Navigator.pop(context);
      final name = u.fullName.isEmpty ? u.email : u.fullName;
      toast(context, pw.isNotEmpty ? l.updated(name) : l.roleUpdated(name));
    } catch (e) {
      if (mounted) {
        toast(context, friendlyUserError(context, e));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final l = context.l;
    final u = widget.user;
    if (widget.isMe) return toast(context, l.cantDeleteSelf);
    if (u.isOwner && widget.owners <= 1) return toast(context, l.needOneOwner);
    final name = u.fullName.isEmpty ? u.email : u.fullName;
    if (!await confirmDelete(context, l.deleteQ(name), l.deleteUserInfo)) return;
    try {
      await ref.read(settingsRepositoryProvider).deleteUser(u.id);
      bumpRefresh(ref);
      if (!mounted) return;
      Navigator.pop(context);
      toast(context, l.deleted(name));
    } catch (e) {
      if (mounted) toast(context, friendlyUserError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final u = widget.user;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(u.fullName.isEmpty ? u.email : u.fullName, style: Theme.of(context).textTheme.titleMedium),
      Text(u.email, style: Theme.of(context).textTheme.bodySmall),
      RadioOption(label: l.roleOwner, sub: l.ownerAccess, on: _role == Role.owner, onTap: () => setState(() => _role = Role.owner)),
      RadioOption(label: l.roleStaff, sub: l.staffAccess, on: _role == Role.staff, onTap: () => setState(() => _role = Role.staff)),
      if (u.role == Role.staff) ...[
        FieldLabel(l.setStaffPassword),
        Row(children: [
          Expanded(child: TextField(controller: _pw, autocorrect: false, enableSuggestions: false, decoration: InputDecoration(hintText: l.leaveEmpty))),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => setState(() => _pw.text = randomPassword()), child: Text(l.random)),
        ]),
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.staffLoginShort, style: Theme.of(context).textTheme.bodySmall)),
      ],
      const SizedBox(height: 16),
      FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
      const SizedBox(height: 8),
      GhostButton(label: l.deleteUser, onPressed: _delete),
    ]);
  }
}
