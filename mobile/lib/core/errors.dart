import 'package:firebase_auth/firebase_auth.dart';

/// A failure with a message that's safe to show the user as-is.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

const _offline = "Couldn't reach Hakikisha. Check your connection and try again.";
const _generic = 'Something went wrong. Please try again.';

/// Turns Firebase errors into plain-language messages.
AppException toAppException(Object error) {
  if (error is AppException) return error;
  if (error is FirebaseAuthException) {
    return AppException(_authMessage(error.code), code: error.code);
  }
  if (error is FirebaseException) {
    final message = switch (error.code) {
      'unavailable' || 'deadline-exceeded' => _offline,
      'permission-denied' || 'unauthorized' || 'unauthenticated' => "You don't have permission to do that.",
      'not-found' || 'object-not-found' => "We couldn't find that.",
      _ => _generic,
    };
    return AppException(message, code: error.code);
  }
  return const AppException(_generic);
}

String _authMessage(String code) => switch (code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Invalid email or password.',
      'invalid-email' => 'Please enter a valid email address.',
      'email-already-in-use' => 'That email is already registered.',
      'weak-password' => "Your password doesn't meet the requirements.",
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Please wait a moment and try again.',
      'network-request-failed' => _offline,
      _ => _generic,
    };
