import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/nanny_card.dart';
import '../services/firestore_service.dart';

class ParentHomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToSearch;
  const ParentHomeScreen({super.key, required this.onNavigateToSearch});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  // Key for forcing StreamBuilder refresh
  Key _streamKey = UniqueKey();

  Future<void> _handleRefresh() async {
    // Simulate network delay for smoother refresh animation
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        // Changing Key causes StreamBuilder to completely resubscribe to Firestore, achieving data refresh
        _streamKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: _handleRefresh, // Trigger this function when pulling down
      child: SingleChildScrollView(
        // Key: Ensure pull-to-refresh gesture can be triggered even if content doesn't fill the screen
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Hello, Parent!  ",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    Text(
                      "Find the perfect care.",
                      style: TextStyle(fontSize: 14, color: AppColors.gray),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: const Icon(
                    Icons.notifications_none,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6B21A8),
                    Color(0xFF8B5CF6),
                    Color(0xFF0D9488),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                boxShadow: AppColors.cardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Trusted Care\nFor Your Family",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: widget.onNavigateToSearch,
                      icon: const Icon(
                        Icons.search,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: const Text(
                        "Find a Nanny",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              "Recommended Nannies",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 15),

            StreamBuilder<List<Map<String, dynamic>>>(
              key: _streamKey, // Bind dynamic Key
              stream: FirestoreService.getNanniesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      "No nannies available yet.",
                      style: TextStyle(color: AppColors.gray),
                    ),
                  );
                }
                final nannies = snapshot.data!;
                return Column(
                  children: nannies
                      .map((nanny) => NannyCard(nanny: nanny))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
