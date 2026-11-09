import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/providers.dart';
import '../../models/user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)),
);

/// Accounts: Firebase Auth for sign-in, plus a `users/{uid}` profile document
/// for name, country and role.
class AuthRepository {
  AuthRepository(this._auth, this._db);

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) => _db.collection('users').doc(uid);

  fb.User? get currentAccount => _auth.currentUser;

  Stream<fb.User?> accountChanges() => _auth.authStateChanges();

  /// Combines the account with its profile document and admin claim.
  Future<User> profileFor(fb.User account) async {
    try {
      final token = await account.getIdTokenResult();
      final profile = await _profileRef(account.uid).get();
      final data = profile.data() ?? const <String, dynamic>{};
      final isAdmin = token.claims?['admin'] == true;
      return User(
        id: account.uid,
        email: account.email ?? '',
        fullName: data['fullName'] as String? ?? account.displayName ?? account.email ?? '',
        country: data['country'] as String? ?? '',
        role: isAdmin ? 'admin' : data['role'] as String? ?? 'consumer',
        isVerified: account.emailVerified,
        isAdmin: isAdmin,
      );
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<User> login({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return await profileFor(credential.user!);
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Creates the account (which signs it in), its profile, and sends the
  /// email-verification link.
  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    required String country,
    required String role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final account = credential.user!;
      await _profileRef(account.uid).set({
        'fullName': fullName,
        'email': account.email,
        'country': country,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await account.updateDisplayName(fullName);
      // Best effort: the account works unverified, and the Me tab can resend.
      try {
        await account.sendEmailVerification();
      } catch (e) {
        debugPrint('Failed to send verification email: $e');
      }
      return await profileFor(account);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// Re-reads the account (e.g. after the user verified their email) and a
  /// fresh token (e.g. after being made an admin).
  Future<User?> refresh() async {
    final account = _auth.currentUser;
    if (account == null) return null;
    try {
      await account.reload();
      await account.getIdToken(true);
      return await profileFor(_auth.currentUser!);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> logout() => _auth.signOut();
}
