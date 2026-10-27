import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Auth. Screens/controllers should go through
/// this rather than touching `supabase.auth` directly, so the auth backend
/// stays swappable and callers get typed exceptions.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
    } on AuthException catch (e) {
      throw AuthRepositoryException(e.message);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthRepositoryException(e.message);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw AuthRepositoryException(e.message);
    }
  }
}

/// Surfaces Supabase auth errors as a message safe to show in the UI.
class AuthRepositoryException implements Exception {
  AuthRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}
