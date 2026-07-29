import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Key _msgRefreshKey = UniqueKey();

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _msgRefreshKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text(
              "Messages",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            key: _msgRefreshKey,
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: currentUid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text(
                      "No messages yet.",
                      style: TextStyle(color: AppColors.gray),
                    ),
                  ),
                );
              }
              var chatRooms = snapshot.data!.docs;
              chatRooms.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                Timestamp timeA = dataA['lastUpdated'] ?? Timestamp.now();
                Timestamp timeB = dataB['lastUpdated'] ?? Timestamp.now();
                return timeB.compareTo(timeA);
              });

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: chatRooms.length,
                itemBuilder: (context, index) {
                  var roomData =
                      chatRooms[index].data() as Map<String, dynamic>;
                  List participants = roomData['participants'] ?? [];
                  String partnerUid = participants.firstWhere(
                    (id) => id != currentUid,
                    orElse: () => "",
                  );
                  if (partnerUid.isEmpty) return const SizedBox.shrink();

                  Map<String, dynamic> partnerData = roomData[partnerUid] ?? {};
                  String partnerName = partnerData['name'] ?? 'User';
                  String lastMessage = roomData['lastMessage'] ?? '';
                  bool hasUnread = roomData['unread_$currentUid'] ?? false;

                  // Highlight fix: Use FutureBuilder to fetch the other party's latest real avatar from users collection in real time, completely solving the avatar mismatch problem!
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(partnerUid)
                        .get(),
                    builder: (context, userSnap) {
                      String realImage =
                          partnerData['image'] ??
                          'https://api.dicebear.com/7.x/avataaars/png?seed=$partnerName';

                      if (userSnap.hasData && userSnap.data!.exists) {
                        var uData =
                            userSnap.data!.data() as Map<String, dynamic>?;
                        if (uData != null) {
                          partnerName = uData['name'] ?? partnerName;
                          realImage =
                              uData['image'] ?? uData['avatar'] ?? realImage;
                        }
                      }

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                partner: {
                                  'uid': partnerUid,
                                  'name': partnerName,
                                  'image': realImage,
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: NetworkImage(realImage),
                                backgroundColor: Colors.grey[200],
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      partnerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.dark,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: hasUnread
                                            ? AppColors.dark
                                            : AppColors.gray,
                                        fontWeight: hasUnread
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasUnread)
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
