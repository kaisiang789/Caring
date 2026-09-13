import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get userStream => _auth.authStateChanges();
  String? get currentUid => _auth.currentUser?.uid;

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    int? hourlyRate,
    String? location,
    String? about,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      Map<String, dynamic> userData = {
        'uid': result.user!.uid,
        'name': name,
        'phone': phone,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'image': "https://api.dicebear.com/7.x/avataaars/png?seed=$name",
      };

      if (role == 'Nanny') {
        userData['hourly_rate'] = hourlyRate ?? 25;
        userData['location'] = location ?? "Skudai, Johor Bahru";
        userData['about'] = about ?? "Hi, I am a professional nanny.";
        userData['rating'] = 5.0;
        // 关键改动：未完成 KYC 前强制为 false
        userData['isOnline'] = false;
        userData['isKycVerified'] = false;
        userData['tags'] = ["Newborn", "First Aid"];
      }

      await _db.collection('users').doc(result.user!.uid).set(userData);
      return result;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async => await _auth.signOut();
}
