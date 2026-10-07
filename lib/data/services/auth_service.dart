import 'package:firebase_auth/firebase_auth.dart';

/// Wraps FirebaseAuth so the rest of the app never imports it directly.
class AuthService {
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User> signIn({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return cred.user!;
  }

  Future<User> createUser({required String email, required String password}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return cred.user!;
  }

  /// Used to roll back a half-finished sign-up.
  Future<void> deleteCurrentUser() async => _auth.currentUser?.delete();

  Future<void> signOut() => _auth.signOut();
}
