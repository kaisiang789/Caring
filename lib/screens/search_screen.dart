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
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _searchRefreshKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Explore",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.gray, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() => _query = value),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.dark,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                "Search tags, names (e.g., Cooking, First Aid)...",
                            hintStyle: TextStyle(color: AppColors.gray),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.userPreferences.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_list,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Sorted by preferences: ${widget.userPreferences.take(3).join(', ')}...",
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
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
                        QuerySnapshot snapshot = await FirebaseFirestore
                            .instance
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
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      "Ask AI for Best Match",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          StreamBuilder<List<Map<String, dynamic>>>(
            key: _searchRefreshKey,
            stream: FirestoreService.getNanniesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              if (!snapshot.hasData || snapshot.data!.isEmpty)
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      "No nannies found.",
                      style: TextStyle(color: AppColors.gray),
                    ),
                  ),
                );

              List<Map<String, dynamic>> allNannies = snapshot.data!;
              List<Map<String, dynamic>> filtered = allNannies.where((nanny) {
                if (_query.trim().isEmpty) return true;
                List<String> searchTerms = _query
                    .toLowerCase()
                    .split(RegExp(r'[\s,;\uFF0C\uFF1B]+'))
                    .where((term) => term.isNotEmpty)
                    .toList();
                if (searchTerms.isEmpty) return true;

                final nameLower = (nanny['name'] ?? '')
                    .toString()
                    .toLowerCase();
                final locationLower = (nanny['location'] ?? '')
                    .toString()
                    .toLowerCase();
                final tags = (nanny['tags'] as List<dynamic>? ?? [])
                    .map((t) => t.toString().toLowerCase())
                    .toList();

                return searchTerms.every(
                  (term) =>
                      nameLower.contains(term) ||
                      locationLower.contains(term) ||
                      tags.any((tag) => tag.contains(term)),
                );
              }).toList();

              // Highlight matching algorithm: Sort nannies in descending order by number of parent-set Preferences tags they contain
              if (widget.userPreferences.isNotEmpty) {
                filtered.sort((a, b) {
                  final tagsA = a['tags'] as List<dynamic>? ?? [];
                  final tagsB = b['tags'] as List<dynamic>? ?? [];

                  final matchCountA = tagsA
                      .where(
                        (tag) => widget.userPreferences.any(
                          (p) =>
                              p.toLowerCase().trim() ==
                              tag.toString().toLowerCase().trim(),
                        ),
                      )
                      .length;
                  final matchCountB = tagsB
                      .where(
                        (tag) => widget.userPreferences.any(
                          (p) =>
                              p.toLowerCase().trim() ==
                              tag.toString().toLowerCase().trim(),
                        ),
                      )
                      .length;

                  return matchCountB.compareTo(
                    matchCountA,
                  ); // Those with more matched preferences are ranked first
                });
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  return NannyCard(
                    nanny: filtered[index],
                    userPrefs: widget
                        .userPreferences, // Perfectly pass down parent preference library
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
