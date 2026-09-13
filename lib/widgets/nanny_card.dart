import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/profile_screen.dart';

class NannyCard extends StatelessWidget {
  final Map<String, dynamic> nanny;
  final List<String> userPrefs;

  const NannyCard({super.key, required this.nanny, this.userPrefs = const []});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> allTags = nanny['tags'] ?? [];
    final String safeName = nanny['name'] ?? 'Unknown Nanny';
    final String safeLocation = nanny['location'] ?? 'Location not set';
    final String safeRating = nanny['rating']?.toString() ?? '5.0';
    final String safeRate = nanny['hourly_rate']?.toString() ?? '25';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0).withOpacity(0.6),
          width: 0.8,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(nanny: nanny),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 头像 + 状态微光环
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryLight,
                              width: 2,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(
                                nanny['image'] ??
                                    'https://api.dicebear.com/7.x/avataaars/png?seed=$safeName',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                safeName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dark,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: AppColors.accent,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      safeRating,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB45309),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: AppColors.gray,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  safeLocation,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 标签栏（匹配高亮呈现精致胶囊状态）
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allTags.map((tag) {
                      final String tagStr = tag.toString().trim();
                      final bool isMatch = userPrefs.any(
                        (p) => p.toLowerCase().trim() == tagStr.toLowerCase(),
                      );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isMatch
                              ? const Color(0xFFECFDF5)
                              : AppColors.lightGray,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isMatch
                                ? const Color(0xFFA7F3D0)
                                : Colors.transparent,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          tagStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: isMatch
                                ? const Color(0xFF047857)
                                : AppColors.body,
                            fontWeight: isMatch
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(
                  height: 1,
                  thickness: 0.8,
                  color: Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 12),
                // 底部价格与按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "RM $safeRate",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const TextSpan(
                            text: " / hr",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.gray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            "View Details",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
