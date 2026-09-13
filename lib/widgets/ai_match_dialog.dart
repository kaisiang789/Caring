import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../services/ai_service.dart';
import '../screens/profile_screen.dart';

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

  final List<String> _quickPrompts = [
    "Cooking & Newborn baby",
    "Special Needs certified",
    "Near Skudai Johor",
    "Budget < RM30/hr",
  ];

  void _performAiMatch() async {
    String userInput = _requirementsController.text.trim();
    if (userInput.isEmpty) return;

    setState(() {
      _isSearching = true;
      _matchedNanny = null;
      _aiReason = "";
    });

    try {
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

      Map<String, String> matchResult = await AiService().getMatchByChat(
        allNannies,
        userInput,
      );
      String targetUid = matchResult['uid'] ?? '';
      String reason =
          matchResult['reason'] ?? 'Best match according to requirements.';

      if (mounted) {
        setState(() {
          _matchedNanny = allNannies.firstWhere(
            (n) => n['uid'] == targetUid,
            orElse: () => allNannies.first,
          );
          _aiReason = reason;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(22.0),
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
                        Icons.psychology_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "AI Smart Care Matcher",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
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
              const SizedBox(height: 8),
              const Text(
                "Describe your family requirements and let Llama 3 evaluate the ideal nanny benchmarks.",
                style: TextStyle(fontSize: 12, color: AppColors.gray),
              ),
              const SizedBox(height: 14),

              // 快捷预设需求 Chips
              Wrap(
                spacing: 6,
                children: _quickPrompts
                    .map(
                      (prompt) => ActionChip(
                        label: Text(
                          prompt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.dark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: AppColors.lightGray,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide.none,
                        onPressed: () => _requirementsController.text = prompt,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _requirementsController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14, color: AppColors.dark),
                  decoration: const InputDecoration(
                    hintText:
                        "E.g. I need a caregiver who can prepare organic meals and handle newborns...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isSearching ? null : _performAiMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Find Best Match",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              if (_matchedNanny != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.dark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "RM ${_matchedNanny!['hourly_rate']}/hr • ${_matchedNanny!['location']}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _aiReason,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.body,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProfileScreen(nanny: _matchedNanny!),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "View Profile & Book",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
