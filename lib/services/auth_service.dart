import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A friendly error we can show directly to the user.
class AccountException implements Exception {
  final String message;
  const AccountException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleReady = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// True when the account signs in with email + password
  /// (Google accounts have no app password to change).
  bool get canChangePassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
          false;

  Future<void> signUp(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  Future<void> signInWithGoogle() async {
    await _ensureGoogleReady();
    final googleUser = await GoogleSignIn.instance.authenticate();
    final idToken = googleUser.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _ensureGoogleReady();
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  // ---------------------------------------------------------------
  // Account settings
  // ---------------------------------------------------------------

  /// Firebase wants a recent login before sensitive changes.
  Future<void> _reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AccountException('You are not signed in.');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> changePassword(String current, String next) async {
    try {
      await _reauthenticate(current);
      await _auth.currentUser!.updatePassword(next);
    } on FirebaseAuthException catch (e) {
      throw AccountException(_message(e));
    }
  }

  /// Sends a verification link to the new address. The email only
  /// changes after the link is clicked.
  Future<void> requestEmailChange(String current, String newEmail) async {
    try {
      await _reauthenticate(current);
      await _auth.currentUser!.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw AccountException(_message(e));
    }
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Your current password is incorrect.';
      case 'weak-password':
        return 'The new password is too weak (use at least 6 characters).';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'email-already-in-use':
        return 'That email is already used by another account.';
      case 'requires-recent-login':
        return 'Please sign out, sign in again, and then retry.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}