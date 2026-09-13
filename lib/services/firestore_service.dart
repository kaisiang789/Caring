import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUid => _auth.currentUser?.uid;

  // ================= 1. Nanny Data =================
  static Stream<List<Map<String, dynamic>>> getNanniesStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'Nanny')
        .snapshots()
        .map((snapshot) {
          List<Map<String, dynamic>> availableNannies = [];
          for (var doc in snapshot.docs) {
            var data = doc.data();
            data['uid'] = doc.id;
            bool isOnline = data['isOnline'] ?? false;
            // 关键改动：必须是本人在线 且 完成了 KYC 认证的老/新保姆才会展示给家长
            bool isKycVerified = data['isKycVerified'] == true;
            if (isOnline && isKycVerified) {
              availableNannies.add(data);
            }
          }
          return availableNannies;
        });
  }

  static Future<void> updateNannyStatus(bool isOnline) async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid).update({
      'isOnline': isOnline,
    });
  }

  // ================= 2. Booking Data =================
  static Future<void> createBooking(Map<String, dynamic> bookingData) async {
    if (currentUid == null) return;
    bookingData['parentUid'] = currentUid;
    bookingData['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('bookings').add(bookingData);
  }

  static Stream<List<Map<String, dynamic>>> getBookingsStream(
    bool isNannyMode,
  ) {
    if (currentUid == null) return Stream.value([]);
    Query query = _db.collection('bookings');
    if (isNannyMode) {
      query = query.where('nannyUid', isEqualTo: currentUid);
    } else {
      query = query.where('parentUid', isEqualTo: currentUid);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            data['docId'] = doc.id;
            return data;
          }).toList(),
        );
  }

  static Future<void> updateBooking(
    String docId,
    Map<String, dynamic> updateData,
  ) async {
    await _db.collection('bookings').doc(docId).update(updateData);
  }

  static Future<void> requestCompleteBooking(String docId) async {
    await _db.collection('bookings').doc(docId).update({
      'status': 'Completed (Pending Verification)',
    });
  }

  static Future<void> parentConfirmPayout(String docId, String nannyUid) async {
    DocumentReference bookingRef = _db.collection('bookings').doc(docId);
    DocumentReference nannyRef = _db.collection('users').doc(nannyUid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot bookingSnap = await transaction.get(bookingRef);
      DocumentSnapshot nannySnap = await transaction.get(nannyRef);

      if (!bookingSnap.exists) return;
      var bookingData = bookingSnap.data() as Map<String, dynamic>;
      String currentStatus = bookingData['status'] ?? '';
      if (currentStatus == 'Completed') return;

      int earnAmount =
          int.tryParse(
            bookingData['total_price']?.toString() ??
                bookingData['totalPrice']?.toString() ??
                '50',
          ) ??
          50;

      int currentEarnings = 0;
      if (nannySnap.exists) {
        var nannyData = nannySnap.data() as Map<String, dynamic>;
        currentEarnings =
            int.tryParse(nannyData['total_earnings']?.toString() ?? '0') ?? 0;
      }

      transaction.update(bookingRef, {'status': 'Completed'});
      transaction.update(nannyRef, {
        'total_earnings': currentEarnings + earnAmount,
      });
    });
  }

  // ================= 3. Chat System =================
  static String getChatRoomId(String targetUid) {
    if (currentUid == null) return "";
    List<String> ids = [currentUid!, targetUid];
    ids.sort();
    return ids.join('_');
  }

  static Future<void> sendMessage(
    String targetUid,
    String targetName,
    String targetImage,
    String text,
  ) async {
    if (currentUid == null) return;
    String chatId = getChatRoomId(targetUid);

    DocumentSnapshot myDoc = await _db
        .collection('users')
        .doc(currentUid)
        .get();

    Map<String, dynamic>? myData = myDoc.data() as Map<String, dynamic>?;
    String myName = myData?['name'] ?? 'User';

    // Highlight fix: Uniformly use Dicebear avatar generation algorithm with real name as seed to ensure complete alignment!
    String myImage =
        myData?['image'] ??
        myData?['avatar'] ??
        'https://api.dicebear.com/7.x/avataaars/png?seed=$myName';

    String safeTargetImage = targetImage.isNotEmpty
        ? targetImage
        : 'https://api.dicebear.com/7.x/avataaars/png?seed=$targetName';

    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _db.collection('chats').doc(chatId).set({
      'chatId': chatId,
      'participants': [currentUid, targetUid],
      'lastMessage': text,
      'lastSenderId': currentUid,
      'lastUpdated': FieldValue.serverTimestamp(),
      'unread_$targetUid': true,
      'unread_$currentUid': false,
      currentUid!: {'name': myName, 'image': myImage},
      targetUid: {'name': targetName, 'image': safeTargetImage},
    }, SetOptions(merge: true));
  }

  static Future<void> markAsRead(String targetUid) async {
    if (currentUid == null) return;
    String chatId = getChatRoomId(targetUid);
    await _db.collection('chats').doc(chatId).set({
      'unread_$currentUid': false,
    }, SetOptions(merge: true));
  }

  static Stream<QuerySnapshot> getChatMessages(String targetUid) {
    String chatId = getChatRoomId(targetUid);
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getChatRooms() {
    if (currentUid == null) return const Stream.empty();
    return _db
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .snapshots();
  }

  // ================= 4. Review System =================
  static Future<void> submitReview(
    String bookingId,
    String nannyUid,
    double rating,
    String reviewText,
    String? existingBase64,
  ) async {
    if (currentUid == null || nannyUid.isEmpty) return;
    String? base64Image = existingBase64;

    DocumentSnapshot parentDoc = await _db
        .collection('users')
        .doc(currentUid)
        .get();

    String parentName =
        (parentDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Parent';

    await _db.collection('bookings').doc(bookingId).update({
      'isRated': true,
      'rating': rating,
      'reviewText': reviewText,
      'reviewImageUrl': base64Image,
    });

    DocumentReference nannyRef = _db.collection('users').doc(nannyUid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(nannyRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> nannyData =
          snapshot.data() as Map<String, dynamic>? ?? {};

      List<dynamic> reviews = List.from(nannyData['reviews'] ?? []);

      DateTime now = DateTime.now();
      String dateStr = "${now.day}/${now.month}/${now.year}";

      int existingIndex = reviews.indexWhere(
        (r) => r['bookingId'] == bookingId,
      );

      Map<String, dynamic> reviewData = {
        'bookingId': bookingId,
        'user': parentName,
        'rating': rating,
        'comment': reviewText,
        'date': dateStr,
        'imageUrl': base64Image,
      };

      if (existingIndex != -1) {
        reviews[existingIndex] = reviewData;
      } else {
        reviews.insert(0, reviewData);
      }

      double totalRating = 0;
      for (var r in reviews) {
        totalRating += (r['rating'] as num).toDouble();
      }

      double avgRating = reviews.isEmpty ? 5.0 : totalRating / reviews.length;

      transaction.update(nannyRef, {
        'reviews': reviews,
        'rating': double.parse(avgRating.toStringAsFixed(1)),
      });
    });
  }
}
