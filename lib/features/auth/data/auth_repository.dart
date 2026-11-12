import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';

class AuthRepository {
  final SupabaseClient _db;
  AuthRepository(this._db);

  Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email.trim(), password: password);

  /// Daftar akun = toko baru. Trigger handle_new_user membuat stores + profil owner.
  Future<void> signUp({required String storeName, required String email, required String phone, required String password}) async {
    await _db.auth.signUp(email: email.trim(), password: password, data: {'store_name': storeName.trim(), 'phone': phone.trim()});
    // Daftar akun mengarah ke layar Login, jadi sesi baru (jika langsung aktif) ditutup.
    if (_db.auth.currentSession != null) await _db.auth.signOut();
  }

  Future<void> resetPassword(String email) => _db.auth.resetPasswordForEmail(email.trim());

  Future<void> signOut() => _db.auth.signOut();
}

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(supabaseProvider)));
