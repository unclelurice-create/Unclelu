import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme.dart';
import 'common.dart';

/// Bottom navigation: Owner 5 tab, Staff 4 tab (tanpa Laporan)
class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(isOwnerProvider);
    final l = context.l;
    final tabs = <(String, IconData, String)>[
      ('/dashboard', Icons.home_outlined, l.navDashboard),
      ('/orders', Icons.receipt_long_outlined, l.navOrders),
      ('/purchases', Icons.shopping_cart_outlined, l.navPurchases),
      if (owner) ('/reports', Icons.bar_chart_rounded, l.navReports),
      ('/account', Icons.person_outline_rounded, l.navAccount),
    ];
    final t = context.tk;
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Row(children: [
              for (final tab in tabs)
                Expanded(
                  child: InkWell(
                    onTap: () => context.go(tab.$1),
                    child: _NavItem(icon: tab.$2, label: tab.$3, on: location == tab.$1),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  const _NavItem({required this.icon, required this.label, required this.on});
  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = on ? t.accent : const Color(0xFFA39591);
    return Semantics(
      selected: on,
      button: true,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 22, height: 3, decoration: BoxDecoration(color: on ? t.accent : Colors.transparent, borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 6),
        Icon(icon, color: c, size: 22),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c)),
      ]),
    );
  }
}
