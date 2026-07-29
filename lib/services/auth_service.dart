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
        userData['isOnline'] =
            true; // Default online after registration, appears on parent homepage
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

  Future<void> createTestNannies() async {
    List<Map<String, dynamic>> testNannies = [
      {
        "email": "sarah@nanny.com",
        "pass": "123456",
        "name": "Sarah Lim",
        "phone": "012-1111111",
        "location": "Taman Universiti, Skudai",
        "rating": 5.0,
        "hourly_rate": 25,
        "isOnline": true,
        "tags": ["Non-smoking", "Cooking"],
        "image": "https://api.dicebear.com/7.x/avataaars/png?seed=Sarah",
        "about": "Experienced and caring professional with 5 years in Skudai.",
      },
      {
        "email": "emily@nanny.com",
        "pass": "123456",
        "name": "Emily Chen",
        "phone": "012-2222222",
        "location": "Mutiara Rini, JB",
        "rating": 4.9,
        "hourly_rate": 30,
        "isOnline": true,
        "tags": ["Pet Friendly", "Housekeeping", "Art"],
        "image": "https://api.dicebear.com/7.x/avataaars/png?seed=Emily",
        "about":
            "Creative nanny who loves arts, crafts, and helping with homework.",
      },
      {
        "email": "rebecca@nanny.com",
        "pass": "123456",
        "name": "Rebecca Tan",
        "phone": "012-3333333",
        "location": "Taman Skudai Ria",
        "rating": 5.0,
        "hourly_rate": 35,
        "isOnline": true,
        "tags": ["Has Car", "Special Needs"],
        "image": "https://api.dicebear.com/7.x/avataaars/png?seed=Rebecca",
        "about": "Special education background, reliable transport, energetic.",
      },
    ];

    for (var nanny in testNannies) {
      try {
        UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: nanny['email'],
          password: nanny['pass'],
        );
        await _db.collection('users').doc(result.user!.uid).set({
          'uid': result.user!.uid,
          'email': nanny['email'],
          'name': nanny['name'],
          'phone': nanny['phone'],
          'role': 'Nanny',
          'location': nanny['location'],
          'rating': nanny['rating'],
          'hourly_rate': nanny['hourly_rate'],
          'isOnline': nanny['isOnline'],
          'tags': nanny['tags'],
          'image': nanny['image'],
          'about': nanny['about'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print(e);
      }
    }
    await _auth.signOut();
  }
}
