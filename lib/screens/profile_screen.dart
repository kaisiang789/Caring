import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:project/screens/chat_screen.dart';
import '../core/theme.dart';
import '../widgets/booking_bottom_sheet.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> nanny;
  const ProfileScreen({super.key, required this.nanny});

  // Highlight feature: Click review image to view in fullscreen without quality loss
  void _showFullScreenImage(BuildContext context, String base64Str) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
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
    List<dynamic> rawReviews = nanny['reviews'] ?? [];
    final List<Map<String, dynamic>> reviews = rawReviews.isNotEmpty
        ? rawReviews.map((r) => Map<String, dynamic>.from(r)).toList()
        : [
            {
              "user": "Mrs. Tan",
              "rating": 5.0,
              "comment": "Wonderful nanny! Very patient and caring.",
              "date": "2 days ago",
              "imageUrl": "",
            },
          ];

    int baseRate = nanny['hourly_rate'] ?? 25;
    bool allowHolidayCharge = nanny['allow_holiday_charge'] ?? true;
    int holidaySurcharge =
        int.tryParse(nanny['holiday_charge_rate']?.toString() ?? '15') ?? 15;

    List<Map<String, dynamic>> activeServicesList = [];
    if (nanny['custom_addons_list'] != null) {
      final List<dynamic> rawList = nanny['custom_addons_list'] as List;
      final Set<String> seenNames = {};

      for (var item in rawList) {
        if (item is Map) {
          final mappedItem = Map<String, dynamic>.from(item);
          final String serviceName = mappedItem['name'] ?? '';

          if (serviceName.isNotEmpty && !seenNames.contains(serviceName)) {
            seenNames.add(serviceName);
            activeServicesList.add(mappedItem);
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        height: 150,
                        width: double.infinity,
                        color: AppColors.primary,
                        padding: const EdgeInsets.only(top: 50, left: 16),
                        alignment: Alignment.topLeft,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppColors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 120),
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              nanny['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.dark,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              nanny['location'] ?? '',
                              style: const TextStyle(color: AppColors.gray),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'RM $baseRate',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Text(
                                  '/hr',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: allowHolidayCharge
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                allowHolidayCharge
                                    ? "✨ Holiday rate: RM ${baseRate + holidaySurcharge}/hr (+RM$holidaySurcharge)"
                                    : "🟢 Holiday charge: Waived (No Extra Fees!)",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: allowHolidayCharge
                                      ? const Color(0xFFB91C1C)
                                      : AppColors.gray,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                            const Divider(color: AppColors.lightGray),
                            const SizedBox(height: 15),

                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "About",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                nanny['about'] ?? 'Experienced nanny.',
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),

                            const SizedBox(height: 25),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Premium Add-on Services",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (activeServicesList.isEmpty)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "This nanny offers base care service only.",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.gray,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: activeServicesList.length,
                                itemBuilder: (context, i) {
                                  final s = activeServicesList[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightGray,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: AppColors.primary,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            s['name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          "RM ${s['price']}.00",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 25),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Tags",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    (nanny['tags'] as List<dynamic>? ?? [])
                                        .map(
                                          (tag) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.lightGray,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              tag.toString(),
                                              style: const TextStyle(
                                                color: AppColors.gray,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),

                            const SizedBox(height: 25),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Reviews (${reviews.length})",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Loop through and render parent review cards
                            ...reviews.map((r) {
                              String? reviewImg =
                                  r['imageUrl'] ??
                                  r['reviewImageUrl']; // Compatible with both field structures

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGray,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          r['user'] ?? 'User',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
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
                                    const SizedBox(height: 5),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (index) => Icon(
                                          index < (r['rating'] as num)
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 14,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      r['comment'] ?? '',
                                      style: const TextStyle(
                                        color: AppColors.gray,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),

                                    // Core fix highlight: If this review has a Base64 real image uploaded by parent, decode and render it immediately!
                                    if (reviewImg != null &&
                                        reviewImg.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      GestureDetector(
                                        onTap: () => _showFullScreenImage(
                                          context,
                                          reviewImg,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                        ),
                      ),
                      Positioned(
                        top: 70,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white,
                              width: 5,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(nanny['image'] ?? ''),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.lightGray)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.gray),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.primary,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          partner: {
                            'uid': nanny['uid'],
                            'name': nanny['name'],
                            'image': nanny['image'],
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => BookingBottomSheet(nanny: nanny),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      "Book Now",
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
