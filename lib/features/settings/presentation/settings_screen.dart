import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/common.dart';
import '../../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = context.tk;
    final profile = ref.watch(profileProvider).valueOrNull;
    final store = ref.watch(storeProvider).valueOrNull;
    final owner = profile?.isOwner ?? false;
    final ui = ref.watch(uiPrefsProvider);
    final accents = [l.accentRed, l.accentOrange, l.accentMagenta, l.accentGreen, l.accentBlue];

    Widget row(IconData icon, String label, String path, {bool first = false}) => InkWell(
          onTap: () => context.push(path),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: first ? null : BoxDecoration(border: Border(top: BorderSide(color: t.line))),
            child: Row(children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              Icon(Icons.chevron_right_rounded, color: t.ink2),
            ]),
          ),
        );

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      TopBar(title: l.settings),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AppCard(
            child: Row(children: [
              const StoreAvatar(size: 56, radius: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(store?.name ?? '', style: Theme.of(context).textTheme.titleMedium),
                  Text(profile?.email ?? '', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  StatusBadge(owner ? l.roleOwner : l.roleStaff, bg: t.okTint, fg: t.ok),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Column(children: [
              row(Icons.person_outline_rounded, owner ? l.storeProfile : l.accountProfile, '/settings/profile', first: true),
              if (owner) ...[
                row(Icons.receipt_long_outlined, l.manageMenu, '/settings/menus'),
                if (store?.isWebsiteStore ?? false) row(Icons.event_busy_outlined, l.openClosedDays, '/settings/days'),
                if (store?.isWebsiteStore ?? false) row(Icons.language_rounded, l.webOrders, '/orders/web'),
                row(Icons.bar_chart_rounded, l.ingredientCost, '/settings/hpp'),
                row(Icons.date_range_outlined, l.manageBatches, '/settings/batches'),
                row(Icons.group_outlined, l.manageUsers, '/settings/users'),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l.darkMode, style: const TextStyle(fontWeight: FontWeight.w600))),
                Switch(value: ui.dark, activeTrackColor: t.accent, onChanged: (v) => ref.read(uiPrefsProvider.notifier).setDark(v)),
              ]),
              const SizedBox(height: 8),
              Text(l.accentColor, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(spacing: 14, children: [
                for (var i = 0; i < accentColors.length; i++)
                  Semantics(
                    button: true,
                    selected: ui.accent == i,
                    label: accents[i],
                    child: GestureDetector(
                      onTap: () => ref.read(uiPrefsProvider.notifier).setAccent(i),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accentColors[i],
                          shape: BoxShape.circle,
                          boxShadow: ui.accent == i ? [BoxShadow(color: t.card, spreadRadius: 3), BoxShadow(color: accentColors[i], spreadRadius: 5)] : null,
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text(l.language, style: const TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(
                  width: 150,
                  child: SegTabs(labels: const ['Id', 'En'], index: ui.lang == 'en' ? 1 : 0, onChanged: (i) {
                    if ((i == 1) != (ui.lang == 'en')) ref.read(uiPrefsProvider.notifier).toggleLang();
                  }),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          GhostButton(
            label: l.signOut,
            icon: Icons.logout_rounded,
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              ref.invalidate(profileProvider);
              if (context.mounted) context.go('/login');
            },
          ),
        ]),
      ),
    ]);
  }
}
