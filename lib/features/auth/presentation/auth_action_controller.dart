import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// Drives the login/signup/sign-out button state (loading/error) without
/// screens needing their own try/catch + setState boilerplate.
class AuthActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await AsyncValue.guard(
      () => repo.signIn(email: email, password: password),
    );
    state = result;
    return !result.hasError;
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final result = await AsyncValue.guard(
      () => repo.signUp(email: email, password: password, fullName: fullName),
    );
    state = result;
    return !result.hasError;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(repo.signOut);
  }
}

final authActionControllerProvider =
    AsyncNotifierProvider<AuthActionController, void>(
      AuthActionController.new,
    );
