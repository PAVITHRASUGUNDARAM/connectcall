import 'package:firebase_auth/firebase_auth.dart';

class ErrorMapper {
  ErrorMapper._();

  static String auth(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'network-request-failed':
          return 'No internet connection. Check your network and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        default:
          return error.message ?? 'Authentication failed.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  static String generic(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('network') || text.contains('socket')) {
      return 'No internet connection. Check your network and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
