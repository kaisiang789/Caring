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
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _msgRefreshKey = UniqueKey());
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const Text(
            "Messages",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.dark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

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
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  alignment: Alignment.center,
                  child: const Text(
                    "No message conversations yet.",
                    style: TextStyle(color: AppColors.gray, fontSize: 13),
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.lightGray,
                                backgroundImage: NetworkImage(realImage),
                              ),
                              if (hasUnread)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.danger,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            partnerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.dark,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread
                                  ? AppColors.dark
                                  : AppColors.gray,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () => Navigator.push(
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
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
