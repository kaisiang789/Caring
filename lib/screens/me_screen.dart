import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import 'edit_profile_screen.dart';
import '../services/auth_service.dart';
import 'help_support_screen.dart';
import '../widgets/kyc_dialog.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account updated in cloud!"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _showPreferencesDialog() {
    List<String> tempPrefs = List.from(widget.userPreferences);
    final List<String> availableTagOptions = [
      "Cooking",
      "Outdoor",
      "Infants",
      "Toddlers",
      "Patient",
      "Premium",
      "Newborn",
      "First-Aid Certified",
      "Chinese",
      "Malay",
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              "Care Preferences",
              style: TextStyle(
                fontWeight: FontWeight.w900,
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.dark,
                        fontWeight: FontWeight.w500,
                      ),
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
        title: const Text(
          "Log Out",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.danger,
          ),
        ),
        content: const Text(
          "Are you sure you want to sign out of your account?",
        ),
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
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        if (!snapshot.hasData || !snapshot.data!.exists)
          return const Center(child: Text("User data not found"));

        Map<String, dynamic> userData =
            snapshot.data!.data() as Map<String, dynamic>;
        String currentName = userData['name'] ?? "Unknown";
        String currentRole = widget.isNannyMode ? "Caregiver" : "Parent";
        String avatarUrl =
            userData['image'] ??
            "https://api.dicebear.com/7.x/avataaars/png?seed=$currentName";

        // 核心兼容：现有未设置该字段的老保姆，默认都是未认证 (false)
        bool isKycVerified = userData['isKycVerified'] == true;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              // 用户基本信息大卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryLight,
                              width: 3,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (widget.isNannyMode)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isKycVerified
                                    ? AppColors.success
                                    : const Color(0xFFD97706),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                isKycVerified
                                    ? Icons.verified_rounded
                                    : Icons.priority_high_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            currentRole,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (widget.isNannyMode) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isKycVerified
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isKycVerified ? "Verified" : "KYC Required",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isKycVerified
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 功能列表项
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    // 保姆专属的 KYC 认证按钮条
                    if (widget.isNannyMode) ...[
                      _buildRow(
                        Icons.shield_outlined,
                        "Identity Verification (KYC)",
                        () async {
                          if (isKycVerified) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Your identity is already fully verified!",
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } else {
                            bool? done =
                                await KycDialogHelper.showSimulatedKycSheet(
                                  context,
                                );
                            if (done == true && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("KYC Verified Successfully!"),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          }
                        },
                        trailing: isKycVerified ? "Verified ✓" : "Verify Now",
                        trailingColor: isKycVerified
                            ? AppColors.success
                            : const Color(0xFFD97706),
                      ),
                      const Divider(
                        height: 1,
                        indent: 55,
                        color: AppColors.border,
                      ),
                    ],

                    _buildRow(
                      Icons.manage_accounts_outlined,
                      "Account Settings",
                      () => _navigateToEditAccount(userData),
                    ),
                    const Divider(
                      height: 1,
                      indent: 55,
                      color: AppColors.border,
                    ),
                    if (!widget.isNannyMode) ...[
                      _buildRow(
                        Icons.tune_rounded,
                        "Set Preferences",
                        _showPreferencesDialog,
                        trailing: "${widget.userPreferences.length} Active",
                      ),
                      const Divider(
                        height: 1,
                        indent: 55,
                        color: AppColors.border,
                      ),
                    ],
                    _buildRow(
                      Icons.support_agent_rounded,
                      "Help & Support",
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportScreen(),
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      indent: 55,
                      color: AppColors.border,
                    ),
                    _buildRow(
                      Icons.logout_rounded,
                      "Sign Out",
                      _showLogoutDialog,
                      isDanger: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(
    IconData icon,
    String label,
    VoidCallback onTap, {
    String? trailing,
    Color? trailingColor,
    bool isDanger = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isDanger ? AppColors.danger : AppColors.dark,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDanger ? AppColors.danger : AppColors.dark,
        ),
      ),
      trailing: trailing != null
          ? Text(
              trailing,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: trailingColor ?? AppColors.primary,
              ),
            )
          : const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
              size: 20,
            ),
    );
  }
}
