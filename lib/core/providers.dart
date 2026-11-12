import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'format.dart';
import 'models.dart';

/// Diisi di main() lewat overrideWithValue.
final sharedPrefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

// ------------------------------------------------------------ preferensi tampilan
class UiPrefs {
  final bool dark;
  final int accent;
  final String lang;
  const UiPrefs({this.dark = false, this.accent = 0, this.lang = 'id'});
  UiPrefs copyWith({bool? dark, int? accent, String? lang}) => UiPrefs(dark: dark ?? this.dark, accent: accent ?? this.accent, lang: lang ?? this.lang);
}

class UiPrefsNotifier extends Notifier<UiPrefs> {
  late SharedPreferences _p;
  @override
  UiPrefs build() {
    _p = ref.watch(sharedPrefsProvider);
    // Mode gelap mati secara default; tidak mengikuti sistem.
    return UiPrefs(dark: _p.getBool('dark') ?? false, accent: _p.getInt('accent') ?? 0, lang: _p.getString('lang') ?? 'id');
  }

  void setDark(bool v) {
    _p.setBool('dark', v);
    state = state.copyWith(dark: v);
  }

  void setAccent(int i) {
    _p.setInt('accent', i);
    state = state.copyWith(accent: i);
  }

  void toggleLang() {
    final l = state.lang == 'id' ? 'en' : 'id';
    _p.setString('lang', l);
    state = state.copyWith(lang: l);
  }
}

final uiPrefsProvider = NotifierProvider<UiPrefsNotifier, UiPrefs>(UiPrefsNotifier.new);

// ------------------------------------------------------------ sesi & profil
/// Aliran perubahan status login (dipakai router untuk refresh).
final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(supabaseProvider).auth.onAuthStateChange);

final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser?.id;
});

final profileProvider = FutureProvider<Profile?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  final row = await ref.watch(supabaseProvider).from('profiles').select().eq('id', uid).maybeSingle();
  return row == null ? null : Profile.fromJson(row);
});

final isOwnerProvider = Provider<bool>((ref) => ref.watch(profileProvider).valueOrNull?.isOwner ?? false);

final storeProvider = FutureProvider<Store?>((ref) async {
  final p = await ref.watch(profileProvider.future);
  if (p == null) return null;
  final row = await ref.watch(supabaseProvider).from('stores').select().eq('id', p.storeId).maybeSingle();
  return row == null ? null : Store.fromJson(row);
});

// ------------------------------------------------------------ periode & batch filter
/// Periode default = bulan berjalan (dari kalender perangkat).
(DateTime, DateTime) currentMonth([DateTime? now]) {
  final n = now ?? DateTime.now();
  return (DateTime(n.year, n.month, 1), DateTime(n.year, n.month + 1, 0));
}

class PeriodNotifier extends Notifier<(DateTime, DateTime)> {
  @override
  (DateTime, DateTime) build() => currentMonth();
  void set(DateTime s, DateTime e) => state = (Fmt.dateOnly(s), Fmt.dateOnly(e));
}

final periodProvider = NotifierProvider<PeriodNotifier, (DateTime, DateTime)>(PeriodNotifier.new);

/// null = Semua batch
final batchFilterProvider = StateProvider<String?>((_) => null);

/// Hari ini (dihitung ulang tiap dibaca, mengikuti jam perangkat)
DateTime today() => Fmt.dateOnly(DateTime.now());

/// Penyegar data global: naikkan angka ini setelah menyimpan data.
final refreshTickProvider = StateProvider<int>((_) => 0);

void bumpRefresh(WidgetRef ref) => ref.read(refreshTickProvider.notifier).state++;

/// Pesan error Postgres/Edge -> kunci pesan ramah
String errorCode(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return e.reasonPhrase ?? 'ERROR';
  }
  if (e is AuthException) return e.message;
  return e.toString();
}

/// Snackbar sederhana
void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2200)));
}

/// Timer kecil untuk polling (dipakai layar yang perlu segar)
Timer periodic(Duration d, void Function() f) => Timer.periodic(d, (_) => f());
