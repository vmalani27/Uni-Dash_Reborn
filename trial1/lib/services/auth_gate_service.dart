import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ------------------------------
  // AUTH STATE STREAM
  // ------------------------------
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ------------------------------
  // EMAIL + PASSWORD LOGIN
  // ------------------------------
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ------------------------------
  // EMAIL + PASSWORD REGISTRATION
  // ------------------------------
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ------------------------------
  // GOOGLE SIGN-IN (Firebase only)
  // ------------------------------
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser =
          await GoogleSignIn().signIn();

      if (googleUser == null) return null; // User canceled

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _auth.signInWithCredential(credential);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ------------------------------
  // SIGN OUT
  // ------------------------------
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // ------------------------------
  // CURRENT USER
  // ------------------------------
  User? get currentUser => _auth.currentUser;

  // ------------------------------
  // ERROR HANDLING
  // ------------------------------
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Password must be stronger.';
      case 'invalid-email':
        return 'Email format is invalid.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}
