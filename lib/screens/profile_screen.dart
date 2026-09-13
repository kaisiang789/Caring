import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/booking_bottom_sheet.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> nanny;
  const ProfileScreen({super.key, required this.nanny});

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

    final safeName = nanny['name'] ?? 'Nanny';
    final avatarUrl =
        nanny['image'] ??
        'https://api.dicebear.com/7.x/avataaars/png?seed=$safeName';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // 顶部大背景 + 完整层叠头像区
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        height: 180,
                        width: double.infinity,
                        padding: const EdgeInsets.only(top: 48, left: 16),
                        alignment: Alignment.topLeft,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      // 悬浮居中的头像（半入绿色底、半入白色底）
                      Positioned(
                        bottom: -46,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: AppColors.cardShadow,
                            image: DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 白色卡片内容主体
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          safeName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.gray,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              nanny['location'] ?? 'Location not specified',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.gray,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              "RM $baseRate",
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            const Text(
                              " / hr",
                              style: TextStyle(
                                color: AppColors.gray,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: allowHolidayCharge
                                ? const Color(0xFFFEF2F2)
                                : AppColors.lightGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: allowHolidayCharge
                                  ? const Color(0xFFFECACA)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            allowHolidayCharge
                                ? "Holiday rate: RM ${baseRate + holidaySurcharge}/hr (+RM$holidaySurcharge)"
                                : "Holiday charge: Waived (Standard Rate Only)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: allowHolidayCharge
                                  ? const Color(0xFFDC2626)
                                  : AppColors.gray,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 20),

                        _buildSectionTitle("About Caregiver"),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            nanny['about'] ??
                                nanny['bio'] ??
                                'Experienced and caring childcare specialist.',
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: AppColors.body,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionTitle("Specialized Services & Add-ons"),
                        const SizedBox(height: 10),
                        if (activeServicesList.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Standard care service only.",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.gray,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          ...activeServicesList.map(
                            (s) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.lightGray,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    s['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.dark,
                                    ),
                                  ),
                                  Text(
                                    "+RM ${s['price']}.00",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),

                        _buildSectionTitle("Tags & Skills"),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (nanny['tags'] as List<dynamic>? ?? [])
                                .map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      tag.toString(),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildSectionTitle("Reviews (${reviews.length})"),
                        const SizedBox(height: 12),
                        ...reviews.map((r) {
                          String? reviewImg =
                              r['imageUrl'] ?? r['reviewImageUrl'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                              boxShadow: AppColors.cardShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      r['user'] ?? 'Parent User',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.dark,
                                      ),
                                    ),
                                    Text(
                                      r['date'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < (r['rating'] as num)
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 16,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  r['comment'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.body,
                                    height: 1.4,
                                  ),
                                ),
                                if (reviewImg != null &&
                                    reviewImg.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () => _showFullScreenImage(
                                      context,
                                      reviewImg,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.memory(
                                        base64Decode(reviewImg),
                                        height: 70,
                                        width: 70,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部悬浮操作栏
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border.withOpacity(0.8)),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.dark.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
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
                const SizedBox(width: 14),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Book Now",
                      style: TextStyle(
                        color: Colors.white,
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

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.dark,
        ),
      ),
    );
  }
}
