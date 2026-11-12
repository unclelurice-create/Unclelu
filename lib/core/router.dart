import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_screens.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/orders/presentation/order_form_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/orders/presentation/web_orders_screen.dart';
import '../features/purchases/presentation/purchases_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/batches_screen.dart';
import '../features/settings/presentation/days_screen.dart';
import '../features/settings/presentation/hpp_screens.dart';
import '../features/settings/presentation/menus_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/store_profile_screen.dart';
import '../features/settings/presentation/users_screen.dart';
import 'providers.dart';
import 'widgets/shell.dart';

/// Rute yang tidak boleh dibuka Staff
const ownerOnly = ['/reports', '/settings/menus', '/settings/batches', '/settings/users', '/settings/hpp', '/settings/days', '/orders/web'];
const _public = ['/intro', '/login', '/register', '/forgot'];

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(profileProvider, (_, __) => notifyListeners());
  }
}

/// Transisi geser hanya saat layar dibuka
Page<void> _slide(GoRouterState s, Widget child) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionsBuilder: (c, a, _, w) => MediaQuery.of(c).disableAnimations
          ? w
          : SlideTransition(
              position: Tween(begin: const Offset(.08, 0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic)).animate(a),
              child: FadeTransition(opacity: a, child: w),
            ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggedIn = ref.read(supabaseProvider).auth.currentSession != null;
      final isPublic = _public.contains(loc);
      if (!loggedIn) return isPublic ? null : '/intro';
      if (isPublic) return '/dashboard';
      final profile = ref.read(profileProvider).valueOrNull;
      if (profile != null && !profile.isOwner && ownerOnly.any((p) => loc.startsWith(p))) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/intro', pageBuilder: (c, s) => _slide(s, const IntroScreen())),
      GoRoute(path: '/login', pageBuilder: (c, s) => _slide(s, const LoginScreen())),
      GoRoute(path: '/register', pageBuilder: (c, s) => _slide(s, const RegisterScreen())),
      GoRoute(path: '/forgot', pageBuilder: (c, s) => _slide(s, const ForgotScreen())),
      ShellRoute(
        builder: (c, s, child) => AppShell(location: s.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/dashboard', pageBuilder: (c, s) => const NoTransitionPage(child: DashboardScreen())),
          GoRoute(path: '/orders', pageBuilder: (c, s) => const NoTransitionPage(child: OrdersScreen())),
          GoRoute(path: '/purchases', pageBuilder: (c, s) => const NoTransitionPage(child: PurchasesScreen())),
          GoRoute(path: '/reports', pageBuilder: (c, s) => const NoTransitionPage(child: ReportsScreen())),
          GoRoute(path: '/account', pageBuilder: (c, s) => const NoTransitionPage(child: SettingsScreen())),
        ],
      ),
      GoRoute(path: '/orders/new', pageBuilder: (c, s) => _slide(s, OrderFormScreen(seed: s.extra as OrderFormSeed?))),
      GoRoute(path: '/orders/edit/:id', pageBuilder: (c, s) => _slide(s, OrderFormScreen(editId: s.pathParameters['id']))),
      GoRoute(path: '/orders/web', pageBuilder: (c, s) => _slide(s, const WebOrdersScreen())),
      GoRoute(path: '/settings/profile', pageBuilder: (c, s) => _slide(s, const StoreProfileScreen())),
      GoRoute(path: '/settings/menus', pageBuilder: (c, s) => _slide(s, const MenusScreen())),
      GoRoute(path: '/settings/batches', pageBuilder: (c, s) => _slide(s, const BatchesScreen())),
      GoRoute(path: '/settings/users', pageBuilder: (c, s) => _slide(s, const UsersScreen())),
      GoRoute(path: '/settings/hpp', pageBuilder: (c, s) => _slide(s, const HppListScreen())),
      GoRoute(path: '/settings/hpp/:id', pageBuilder: (c, s) => _slide(s, HppDetailScreen(menuId: s.pathParameters['id']!))),
      GoRoute(path: '/settings/days', pageBuilder: (c, s) => _slide(s, const DaysScreen())),
    ],
  );
});
