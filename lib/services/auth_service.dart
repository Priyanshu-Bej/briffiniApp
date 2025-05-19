import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../main.dart'; // Import for isFirebaseInitialized
import 'auth_persistence_service.dart';

class AuthService {
  // Flags to indicate operational mode
  bool _isFirebaseAvailable = isFirebaseInitialized;
  bool _isFirestoreAvailable = isFirebaseInitialized;

  // Getter for Firebase availability status
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  // Firebase instances with error handling
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  AuthService() {
    if (!isFirebaseInitialized) {
      _isFirebaseAvailable = false;
      _isFirestoreAvailable = false;
      print("Skipping Firebase Auth initialization - Firebase not initialized");
      return;
    }

    try {
      _auth = FirebaseAuth.instance;
      _restoreUserSession(); // Try to restore user session
    } catch (e) {
      print("Failed to initialize Firebase Auth: $e");
      _isFirebaseAvailable = false;
    }

    try {
      _firestore = FirebaseFirestore.instance;
    } catch (e) {
      print("Failed to initialize Firestore: $e");
      _isFirestoreAvailable = false;
    }
  }

  // Restore user session from persistent storage
  Future<void> _restoreUserSession() async {
    if (!_isFirebaseAvailable) return;

    // Check if we have a stored token
    bool isLoggedIn = await AuthPersistenceService.isLoggedIn();
    print("Restore session check - User logged in: $isLoggedIn");

    if (isLoggedIn) {
      // If the user has a stored token but Firebase shows logged out,
      // we rely on Firebase Auth's own persistence mechanism
      // The token in our persistence service is just a marker that login occurred
      print(
        "User was previously logged in, session should be restored by Firebase",
      );
    }
  }

  // Get current user
  User? get currentUser => _isFirebaseAvailable ? _auth?.currentUser : null;

  // Auth state changes stream
  Stream<User?> get authStateChanges =>
      _isFirebaseAvailable ? _auth!.authStateChanges() : Stream.value(null);

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (!_isFirebaseAvailable) {
      throw Exception("Firebase Auth is not available");
    }

    try {
      UserCredential? result = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store authentication data if login successful
      if (result?.user != null) {
        String? token = await result!.user!.getIdToken();
        if (token != null) {
          await AuthPersistenceService.saveAuthToken(token);

          // Get and store user data
          UserModel? userModel = await getUserData();
          if (userModel != null) {
            await AuthPersistenceService.saveUserData(userModel);
          }
        }
      }

      return result;
    } catch (e) {
      if (e.toString().contains(
        "'List<Object?>' is not a subtype of type 'PigeonUserDetails?'",
      )) {
        // This is a Firebase Auth plugin version compatibility issue
        print("Firebase Auth plugin version compatibility issue detected");
        // Return demo user data and don't throw the error
        return null;
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (!_isFirebaseAvailable) {
      throw Exception("Firebase Auth is not available");
    }

    try {
      // Clear persistent storage first
      await AuthPersistenceService.clearAll();
      // Then sign out from Firebase
      await _auth!.signOut();
    } catch (e) {
      if (e.toString().contains("PigeonUserDetails")) {
        // Similar Firebase Auth plugin issue with sign out
        print("Firebase Auth plugin version issue during sign out");
        return;
      }
      rethrow;
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData() async {
    if (!_isFirebaseAvailable || !_isFirestoreAvailable) {
      return _getDemoUserData();
    }

    try {
      User? user = currentUser;
      if (user == null) return null;

      DocumentSnapshot userDoc =
          await _firestore!.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        return UserModel.fromJson(
          userDoc.data() as Map<String, dynamic>,
          user.uid,
        );
      }
      return null;
    } catch (e) {
      print("Error getting user data: $e");
      return _getDemoUserData();
    }
  }

  // For testing: Return a demo user when Firebase is not available
  UserModel _getDemoUserData() {
    return UserModel(
      uid: 'demo-user-id',
      displayName: 'Demo User',
      email: 'demo@example.com',
      role: 'student',
      assignedCourseIds: ['demo-course-1', 'demo-course-2'],
    );
  }

  // Force token refresh (to update custom claims)
  Future<void> forceTokenRefresh() async {
    if (!_isFirebaseAvailable) {
      return; // No-op in demo mode
    }

    try {
      await currentUser?.getIdToken(true);
    } catch (e) {
      rethrow;
    }
  }

  // Change password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (!_isFirebaseAvailable) {
      throw Exception("Firebase Auth is not available");
    }

    User? user = currentUser;
    if (user == null) {
      throw Exception("No user is currently signed in");
    }

    try {
      // Re-authenticate the user first
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update the password in Firebase Authentication
      await user.updatePassword(newPassword);

      // Also update the password in Firestore (if available)
      if (_isFirestoreAvailable && _firestore != null) {
        await _firestore!.collection('users').doc(user.uid).update({
          'password': newPassword, // Store the password in Firestore
        });
        print("Password updated in Firestore for user: ${user.uid}");
      }
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'wrong-password') {
          throw Exception("Incorrect current password");
        } else if (e.code == 'weak-password') {
          throw Exception(
            "New password is too weak. Please use a stronger password",
          );
        } else {
          throw Exception("Authentication error: ${e.message}");
        }
      } else {
        throw Exception("An error occurred: $e");
      }
    }
  }
}
