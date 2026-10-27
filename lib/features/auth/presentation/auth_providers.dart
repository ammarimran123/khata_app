import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_bootstrap.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(supabase);
});

/// Streams every auth state change (sign in, sign out, token refresh) so the
/// router can redirect and screens can react without polling.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.onAuthStateChange;
});

/// The current user, derived from the live auth stream (falls back to the
/// synchronous snapshot before the first stream event arrives).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  if (authState != null) return authState.session?.user;
  return ref.watch(authRepositoryProvider).currentUser;
});
