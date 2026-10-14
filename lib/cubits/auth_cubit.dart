import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _auth;
  final FirestoreService _db;
  StreamSubscription<User?>? _sub;

  AuthCubit(this._auth, this._db) : super(AuthInitial()) {
    // Fires on app start (session persistence) and on every login/logout.
    _sub = _auth.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      emit(Unauthenticated());
      return;
    }
    try {
      await _db.createUserIfMissing(user);
    } catch (_) {}
    emit(Authenticated(user));
  }

  Future<void> signUp(String email, String password) async {
    emit(AuthLoading());
    try {
      await _auth.signUp(email, password);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_message(e)));
    } catch (_) {
      emit(const AuthError('Something went wrong. Please try again.'));
    }
  }

  Future<void> signIn(String email, String password) async {
    emit(AuthLoading());
    try {
      await _auth.signIn(email, password);
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_message(e)));
    } catch (_) {
      emit(const AuthError('Something went wrong. Please try again.'));
    }
  }

  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      await _auth.signInWithGoogle();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        emit(Unauthenticated()); // user closed the popup
      } else {
        emit(AuthError('Google sign-in failed: ${e.description ?? e.code.name}'));
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_message(e)));
    } catch (e) {
      emit(AuthError('Google sign-in failed: $e'));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak (use at least 6 characters).';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}