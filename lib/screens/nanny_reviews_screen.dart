import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';

class NannyReviewsScreen extends StatelessWidget {
  const NannyReviewsScreen({super.key});

  // Review image click-to-fullscreen zoom feature
  void _showFullScreenImage(BuildContext context, String base64Str) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              maxScale: 5.0,
              child: Image.memory(base64Decode(base64Str), fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null)
      return const Scaffold(body: Center(child: Text("Please log in again.")));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.dark),
        title: const Text(
          "My Reviews & Ratings",
          style: TextStyle(
            color: AppColors.dark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Failed to load nanny profile."));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          double rating =
              double.tryParse(userData['rating']?.toString() ?? '5.0') ?? 5.0;
          List<dynamic> rawReviews = userData['reviews'] ?? [];
          List<Map<String, dynamic>> reviews = rawReviews
              .map((r) => Map<String, dynamic>.from(r))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. Top total score dashboard card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < rating.floor()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${reviews.length} reviews",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    // Right side visual simulation of rating proportion
                    Expanded(
                      child: Column(
                        children: [5, 4, 3, 2, 1].map((stars) {
                          int count = reviews
                              .where(
                                (r) => (r['rating'] as num).floor() == stars,
                              )
                              .length;
                          double percent = reviews.isEmpty
                              ? 0.0
                              : count / reviews.length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  "$stars",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gray,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.star,
                                  size: 10,
                                  color: AppColors.gray,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      backgroundColor: AppColors.lightGray,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            AppColors.primary,
                                          ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 2. Detailed review list
              const Text(
                "Detailed Feedback",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 12),

              if (reviews.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  alignment: Alignment.center,
                  child: const Text(
                    "You haven't received any reviews yet.",
                    style: TextStyle(
                      color: AppColors.gray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...reviews.map((r) {
                  String? reviewImg = r['imageUrl'] ?? r['reviewImageUrl'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              r['user'] ?? 'Parent User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.dark,
                              ),
                            ),
                            Text(
                              r['date'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gray,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              index < (r['rating'] as num).floor()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 14,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          r['comment'] ?? 'No feedback text provided.',
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        if (reviewImg != null && reviewImg.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () =>
                                _showFullScreenImage(context, reviewImg),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(reviewImg),
                                height: 80,
                                width: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
