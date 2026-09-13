import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/ai_match_dialog.dart';
import '../core/theme.dart';
import '../widgets/nanny_card.dart';
import '../services/firestore_service.dart';

class SearchScreen extends StatefulWidget {
  final List<String> userPreferences;
  const SearchScreen({super.key, this.userPreferences = const []});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';
  Key _searchRefreshKey = UniqueKey();

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _searchRefreshKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const Text(
            "Explore Caregivers",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.dark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),

          // 现代搜索栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.gray,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(fontSize: 15, color: AppColors.dark),
                    decoration: const InputDecoration(
                      hintText: "Search skills, location, name...",
                      hintStyle: TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 比赛高光：AI Match 快速触发条
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primaryAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Smart Matching",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "Tell AI your exact family needs",
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );
                    try {
                      QuerySnapshot snapshot = await FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'Nanny')
                          .get();
                      List<Map<String, dynamic>> fetchedNannies = [];
                      for (var doc in snapshot.docs) {
                        var data = doc.data() as Map<String, dynamic>;
                        data['uid'] = doc.id;
                        fetchedNannies.add(data);
                      }
                      if (mounted) {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) =>
                              AiMatchDialog(nannies: fetchedNannies),
                        );
                      }
                    } catch (e) {
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    "Match Now",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 结果流
          StreamBuilder<List<Map<String, dynamic>>>(
            key: _searchRefreshKey,
            stream: FirestoreService.getNanniesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      "No caregivers found.",
                      style: TextStyle(color: AppColors.gray),
                    ),
                  ),
                );
              }
              List<Map<String, dynamic>> allNannies = snapshot.data!;
              List<Map<String, dynamic>> filtered = allNannies.where((nanny) {
                if (_query.trim().isEmpty) return true;
                List<String> terms = _query
                    .toLowerCase()
                    .split(RegExp(r'\s+'))
                    .where((t) => t.isNotEmpty)
                    .toList();
                final name = (nanny['name'] ?? '').toString().toLowerCase();
                final loc = (nanny['location'] ?? '').toString().toLowerCase();
                final tags = (nanny['tags'] as List<dynamic>? ?? [])
                    .map((t) => t.toString().toLowerCase())
                    .toList();
                return terms.every(
                  (t) =>
                      name.contains(t) ||
                      loc.contains(t) ||
                      tags.any((tag) => tag.contains(t)),
                );
              }).toList();

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  return NannyCard(
                    nanny: filtered[index],
                    userPrefs: widget.userPreferences,
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
