import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import 'auth_repository.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

/// The signed-in user, or null when browsing anonymously. Scanning and
/// verification work without an account; reporting and admin tools need one.
/// Follows Firebase's own sign-in state, so it also notices sign-outs that
/// happen outside the app (e.g. an account being disabled).
class AuthController extends AsyncNotifier<User?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  // While registering, the account exists before its profile document does;
  // the sign-in event that arrives in between is ignored, and register()
  // publishes the complete user itself.
  bool _registering = false;

  @override
  Future<User?> build() async {
    final repo = ref.watch(authRepositoryProvider);
    // Not skipping the stream's first event: on a cold start Firebase restores
    // the saved session asynchronously, so `currentAccount` below can still
    // be null when the restored account arrives here.
    final subscription = repo.accountChanges().listen((account) async {
      if (_registering) return;
      state = await AsyncValue.guard(() async => account == null ? null : await repo.profileFor(account));
    });
    ref.onDispose(subscription.cancel);

    final account = repo.currentAccount;
    return account == null ? null : repo.profileFor(account);
  }

  Future<void> login({required String email, required String password}) async {
    state = AsyncData(await _repo.login(email: email, password: password));
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String country,
    required String role,
  }) async {
    _registering = true;
    try {
      state = AsyncData(await _repo.register(
        fullName: fullName,
        email: email,
        password: password,
        country: country,
        role: role,
      ));
    } finally {
      _registering = false;
    }
  }

  /// Picks up changes made outside the app: a verified email, or admin access.
  Future<void> refresh() async {
    state = AsyncData(await _repo.refresh());
  }

  Future<void> resendVerificationEmail() => _repo.resendVerificationEmail();

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}
