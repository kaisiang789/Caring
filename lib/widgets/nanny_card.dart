import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/profile_screen.dart';

class NannyCard extends StatelessWidget {
  final Map<String, dynamic> nanny;
  final List<String> userPrefs; // This is the preferences set set by parents

  const NannyCard({super.key, required this.nanny, this.userPrefs = const []});

  @override
  Widget build(BuildContext context) {
    // Core fix: Read all nanny tags in full without take(3) truncation, let newly associated/checked tags appear perfectly!
    final List<dynamic> allTags = nanny['tags'] ?? [];
    final String safeName = nanny['name'] ?? 'Unknown Nanny';
    final String safeLocation = nanny['location'] ?? 'Location not set';
    final String safeRating = nanny['rating']?.toString() ?? '5.0';
    final String safeRate = nanny['hourly_rate']?.toString() ?? '25';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen(nanny: nanny)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 70,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
                image: DecorationImage(
                  image: NetworkImage(
                    nanny['image'] ??
                        'https://api.dicebear.com/7.x/avataaars/png?seed=$safeName',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
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
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            safeRating,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 12,
                        color: AppColors.gray,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          safeLocation,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.gray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Highlight fix area: Render nanny's tags in flat layout, as long as they are in parent's requirements, instantly turn bright green highlight!
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allTags.map((tag) {
                      final String tagStr = tag.toString().trim();
                      // Strong validation of case and whitespace removal
                      final bool isMatch = userPrefs.any(
                        (p) => p.toLowerCase().trim() == tagStr.toLowerCase(),
                      );

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isMatch
                              ? const Color(0xFFDCFCE7)
                              : const Color(
                                  0xFFF1F5F9,
                                ), // Match success bright green
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isMatch
                                ? const Color(0xFFBBF7D0)
                                : Colors.transparent,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          tagStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: isMatch ? AppColors.success : AppColors.gray,
                            fontWeight: isMatch
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              text: 'RM $safeRate',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              children: const [
                                TextSpan(
                                  text: '/hr',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gray,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            "Holiday Surcharge Eligible",
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        "View Profile",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
