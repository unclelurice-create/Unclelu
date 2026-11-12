import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');
  await initializeDateFormatting('en');
  final prefs = await SharedPreferences.getInstance();
  if (!AppConfig.hasSupabase) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  // "Ingat saya" tidak dicentang -> sesi tidak dipakai lagi saat aplikasi dibuka ulang
  if (prefs.getBool('remember') == false && Supabase.instance.client.auth.currentSession != null) {
    await Supabase.instance.client.auth.signOut();
  }
  runApp(ProviderScope(overrides: [sharedPrefsProvider.overrideWithValue(prefs)], child: const SatuPintuApp()));
}

class SatuPintuApp extends ConsumerWidget {
  const SatuPintuApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(uiPrefsProvider);
    ref.watch(authStateProvider);
    final loggedIn = ref.watch(supabaseProvider).auth.currentSession != null;
    final accent = accentColors[ui.accent.clamp(0, accentColors.length - 1)];
    // Layar sebelum login selalu terang; mode gelap hanya di dalam aplikasi.
    final dark = ui.dark && loggedIn;
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(accent, dark: dark),
      themeMode: ThemeMode.light,
      locale: Locale(ui.lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Kredensial Supabase belum diisi.\nJalankan dengan --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...', textAlign: TextAlign.center),
            ),
          ),
        ),
      );
}
