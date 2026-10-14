import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/user.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthState {
  const AuthState._(this.status, this.user);

  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.signedOut() : this._(AuthStatus.signedOut, null);
  const AuthState.signedIn(User user) : this._(AuthStatus.signedIn, user);

  final AuthStatus status;
  final User? user;

  bool get isSignedIn => status == AuthStatus.signedIn;
  bool get needsProfileSetup => isSignedIn && !(user?.onboardingComplete ?? false);
}

/// Owns the session. Boots from stored tokens (falling back to the cached
/// profile when offline) and signs out when the server rejects the session.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    ref.listen(sessionExpiredProvider, (_, _) => _onSessionExpired());
    Future.microtask(_restore);
    return const AuthState.unknown();
  }

  /// Applies a new state unless the provider was disposed during an await.
  void _set(AuthState next) {
    if (ref.mounted) state = next;
  }

  Future<void> _restore() async {
    if (!await _repo.hasSession()) {
      _set(const AuthState.signedOut());
      return;
    }
    try {
      _set(AuthState.signedIn(await _repo.fetchMe()));
    } on ApiException catch (e) {
      final cached = _repo.cachedUser();
      if (!e.isUnauthorized && cached != null) {
        // Offline (or server hiccup): keep the user in with their cached profile.
        _set(AuthState.signedIn(cached));
      } else {
        await _repo.clearLocal();
        _set(const AuthState.signedOut());
      }
    }
  }

  Future<void> login(String email, String password) async {
    _set(AuthState.signedIn(await _repo.login(email: email, password: password)));
  }

  Future<void> register(String email, String password, String username) async {
    _set(AuthState.signedIn(await _repo.register(email: email, password: password, username: username)));
  }

  Future<void> updateProfile(ProfileUpdate update) async {
    _set(AuthState.signedIn(await _repo.updateProfile(update)));
  }

  /// Re-reads the profile (e.g. after a bodyweight entry changed it server-side).
  Future<void> refreshUser() async {
    try {
      _set(AuthState.signedIn(await _repo.fetchMe()));
    } on ApiException {
      // Keep the current profile; the next successful call will refresh it.
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    _set(const AuthState.signedOut());
  }

  Future<void> _onSessionExpired() async {
    if (state.status == AuthStatus.signedOut) return;
    await _repo.clearLocal();
    _set(const AuthState.signedOut());
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience: the signed-in user (null when signed out).
final currentUserProvider = Provider<User?>((ref) => ref.watch(authControllerProvider).user);
