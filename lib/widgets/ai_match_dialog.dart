import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../services/ai_service.dart';
import '../screens/profile_screen.dart'; // Import nanny profile details page

class AiMatchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> nannies;
  const AiMatchDialog({super.key, required this.nannies});

  @override
  State<AiMatchDialog> createState() => _AiMatchDialogState();
}

class _AiMatchDialogState extends State<AiMatchDialog> {
  final TextEditingController _requirementsController = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _matchedNanny;
  String _aiReason = "";

  void _performAiMatch() async {
    String userInput = _requirementsController.text.trim();
    if (userInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please type your child care needs first!"),
        ),
      );
      return;
    }
    setState(() {
      _isSearching = true;
      _matchedNanny = null;
      _aiReason = "";
    });
    try {
      // Real-time fetch latest Nanny data from cloud
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Nanny')
          .get();
      List<Map<String, dynamic>> allNannies = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        allNannies.add(data);
      }

      if (allNannies.isEmpty) {
        setState(() {
          _aiReason =
              "There are currently no registered nannies in the database.";
          _isSearching = false;
        });
        return;
      }

      // Call feature engine matching
      Map<String, String> matchResult = await AiService().getMatchByChat(
        allNannies,
        userInput,
      );
      String targetUid = matchResult['uid'] ?? '';
      String reason =
          matchResult['reason'] ?? 'Highly recommended for your family.';

      if (targetUid.isNotEmpty) {
        _matchedNanny = allNannies.firstWhere(
          (nanny) => nanny['uid'] == targetUid,
          orElse: () => allNannies.first,
        );
      } else {
        _matchedNanny = allNannies.first;
      }
      setState(() {
        _aiReason = reason;
      });
    } catch (e) {
      setState(() {
        _aiReason = "An unexpected database parsing error occurred: $e";
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _requirementsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "AI Smart Matcher",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.gray),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Tell AI your specific needs (e.g. 'cook some food', 'outdoor sports', 'near jb', 'low budget') to find the best nanny.",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.gray,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        controller: _requirementsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: "Type requirements here...",
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: AppColors.gray,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSearching ? null : _performAiMatch,
                      child: _isSearching
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Find Best Match Now",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    if (_isSearching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Text(
                            "AI is evaluating nanny benchmarks...",
                            style: TextStyle(
                              color: AppColors.gray,
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else if (_matchedNanny != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        "Top Recommended Nanny:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: NetworkImage(
                                _matchedNanny!['image'] ??
                                    'https://api.dicebear.com/7.x/avataaars/png?seed=Nanny',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _matchedNanny!['name'] ?? 'Nanny',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.dark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 12,
                                        color: AppColors.gray,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        _matchedNanny!['location'] ?? 'Johor',
                                        style: const TextStyle(
                                          color: AppColors.gray,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.star,
                                        size: 12,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${_matchedNanny!['rating'] ?? 5.0}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "RM ${_matchedNanny!['hourly_rate']?.toString() ?? '25'}/hr",
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.dark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.account_box_outlined, size: 18),
                        label: const Text(
                          "View Nanny Profile Details",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () {
                          // Highlight fix: Removed Navigator.pop(context); keep AI dialog staying in bottom route!

                          // Seamlessly push details page on top
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProfileScreen(nanny: _matchedNanny!),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        "AI Match Analytics:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          _aiReason,
                          style: const TextStyle(
                            color: AppColors.dark,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ] else if (_aiReason.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          _aiReason,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
