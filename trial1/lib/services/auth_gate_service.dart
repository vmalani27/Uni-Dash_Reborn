import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in_android/google_sign_in_android.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Load client ID from .env
  String? get _webClientId => dotenv.env['oauth2_client_id_web'];

  // ---------------------------------------------------------------------------
  // AUTH STATE STREAM
  // ---------------------------------------------------------------------------
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // EMAIL + PASSWORD LOGIN
  // ---------------------------------------------------------------------------
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // EMAIL + PASSWORD REGISTRATION
  // ---------------------------------------------------------------------------
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // GOOGLE SIGN-IN (Firebase Auth)
  // ---------------------------------------------------------------------------
  // Ensure _auth is defined (e.g., final FirebaseAuth _auth = FirebaseAuth.instance;)
// Ensure _webClientId is defined (e.g., const String? _webClientId = 'YOUR_WEB_CLIENT_ID';)

// Recommended pattern: Initialize once outside of the sign-in function
// final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

// Future<UserCredential?> signInWithGoogle() async {
//   try {
//     final String? serverClientId = _webClientId;
    
//     if (serverClientId == null) {
//       throw Exception("Missing web client ID for Google Sign-In.");
//     }
    
//     // 1. Initialize the GoogleSignIn instance
//     // Use the public API: GoogleSignIn.instance.initialize()
//     // NOTE: For Firebase Auth, the parameter is ALWAYS serverClientId (the Web Client ID), 
//     // even for mobile apps. The 'clientId' parameter is mainly for Android/iOS specific configurations 
//     // when NOT using Firebase, or for older packages.
//     await _googleSignIn.initialize(
//         serverClientId: serverClientId,
//         // scopes: ['email'], // Add scopes if needed
//     );

//     // 2. Trigger the authentication flow
//     // Use the public API: .authenticate() on the instance
//     final GoogleSignInAccount? googleUser = await _googleSignIn.authenticate().catchError((error){
//       print("Google SIgn-in error: $error");
//       return null;
//     }); 

//     if (googleUser == null) {
//       return null; // user cancelled
//     }

//     final googleAuth = await googleUser.authentication;

//       final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);

//     return await _auth.signInWithCredential(credential);

//   } on FirebaseAuthException catch (e) {
//     // Handle specific auth errors
//     print("Firebase Auth Error: ${e.code}");
//     rethrow;
//   } catch (e) {
//     print("Google Sign-in error: $e");
//     rethrow;
//   }
// }

//   // ---------------------------------------------------------------------------
//   // SIGN OUT
//   // ---------------------------------------------------------------------------
// Future<void> signOut() async {
//   try {
//     // 1. Sign out of Google
//     // This removes the current account from the app and requires the user
//     // to choose an account next time they sign in with Google.
//     await _googleSignIn.signOut();
    
//     // NOTE: You can also use await _googleSignIn.disconnect(); 
//     // which is more aggressive and fully revokes the access grant.
    
//   } catch (e) {
//     // Handle specific Google Sign-In errors here, though generally 
//     // we can proceed to sign out of Firebase even if Google fails.
//     print('Google Sign Out Error: $e');
//   }

//   // 2. Sign out of Firebase
//   // This clears the local user token and ends the Firebase session.
//   await _auth.signOut();
// }
  // ---------------------------------------------------------------------------
  // GET CURRENT USER
  // ---------------------------------------------------------------------------
  User? get currentUser => _auth.currentUser;

  // ---------------------------------------------------------------------------
  // ERROR HANDLING
  // ---------------------------------------------------------------------------
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}
