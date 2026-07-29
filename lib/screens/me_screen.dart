import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import 'edit_profile_screen.dart';
import '../services/auth_service.dart';
import 'help_support_screen.dart';

class MeScreen extends StatefulWidget {
  final bool isNannyMode;
  final VoidCallback onToggleRole;
  final List<String> userPreferences;
  final Function(List<String>) onUpdatePreferences;

  const MeScreen({
    super.key,
    required this.isNannyMode,
    required this.onToggleRole,
    required this.userPreferences,
    required this.onUpdatePreferences,
  });

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  void _navigateToEditAccount(Map<String, dynamic> currentData) async {
    currentData['avatar'] =
        currentData['image'] ??
        "https://api.dicebear.com/7.x/avataaars/png?seed=${currentData['name']}";
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          isNannyMode: widget.isNannyMode,
          userData: currentData,
        ),
      ),
    );
    if (result != null &&
        result is Map<String, dynamic> &&
        currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update(result);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account updated in cloud!"),
            backgroundColor: AppColors.success,
          ),
        );
    }
  }

  void _showPreferencesDialog() {
    List<String> tempPrefs = List.from(widget.userPreferences);

    // Highlight fix: Use the exact same skill tag library as nanny registration/editing here, as parent preference filter options!
    final List<String> availableTagOptions = [
      "Cooking",
      "Outdoor",
      "Infants",
      "Toddlers",
      "Patient",
      "Premium",
      "Newborn",
      "First-Aid Certified",
      "Chinese", // Additional skills nannies might add themselves
      "Malay",
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Set Preferences",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView(
                children: availableTagOptions.map((option) {
                  return CheckboxListTile(
                    title: Text(
                      option,
                      style: const TextStyle(color: AppColors.dark),
                    ),
                    activeColor: AppColors.primary,
                    value: tempPrefs.contains(option),
                    onChanged: (bool? checked) {
                      setModalState(() {
                        if (checked == true) {
                          tempPrefs.add(option);
                        } else {
                          tempPrefs.remove(option);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: AppColors.gray),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  widget.onUpdatePreferences(tempPrefs);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Preferences Saved!"),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text(
                  "Save",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 28,
            ),
            SizedBox(width: 10),
            Text(
              "Log Out",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text("Log Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Center(child: Text("Not logged in"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const Center(child: Text("User data not found"));

        Map<String, dynamic> userData =
            snapshot.data!.data() as Map<String, dynamic>;
        String currentName = userData['name'] ?? "Unknown";
        String currentRole = widget.isNannyMode ? "Nanny" : "Parent";
        String avatarUrl =
            userData['image'] ??
            "https://api.dicebear.com/7.x/avataaars/png?seed=$currentName";

        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.white,
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 30),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 4),
                          boxShadow: AppColors.cardShadow,
                          image: DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        currentName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        currentRole,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Menu list panel
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.manage_accounts_outlined,
                          color: AppColors.primary,
                          title: "Account Settings",
                          onTap: () => _navigateToEditAccount(userData),
                        ),
                        _buildDivider(),
                        if (!widget.isNannyMode) ...[
                          _buildMenuItem(
                            icon: Icons.tune,
                            color: AppColors.primary,
                            title: "Set Preferences",
                            trailingText:
                                "${widget.userPreferences.length} Selected",
                            onTap: _showPreferencesDialog,
                          ),
                          _buildDivider(),
                        ],
                        _buildMenuItem(
                          icon: Icons.support_agent,
                          color: AppColors.dark,
                          title: "Help & Support",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpSupportScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(),
                        _buildMenuItem(
                          icon: Icons.logout,
                          color: AppColors.danger,
                          title: "Log Out",
                          hideChevron: true,
                          onTap: _showLogoutDialog,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color color,
    required String title,
    String? trailingText,
    bool hideChevron = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color == AppColors.danger
                      ? AppColors.danger
                      : AppColors.dark,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: const TextStyle(
                  color: AppColors.gray,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            if (trailingText != null) const SizedBox(width: 8),
            if (!hideChevron)
              const Icon(Icons.chevron_right, color: AppColors.gray, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => const Divider(
    height: 1,
    thickness: 1,
    color: AppColors.lightGray,
    indent: 55,
    endIndent: 20,
  );
}
