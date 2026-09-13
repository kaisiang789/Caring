import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../services/firestore_service.dart';
import '../widgets/kyc_dialog.dart';
import 'nanny_reviews_screen.dart';

class NannyHomeScreen extends StatefulWidget {
  const NannyHomeScreen({super.key});

  @override
  State<NannyHomeScreen> createState() => _NannyHomeScreenState();
}

class _NannyHomeScreenState extends State<NannyHomeScreen> {
  Key _nannyStreamKey = UniqueKey();

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _nannyStreamKey = UniqueKey());
  }

  // 严格拦截方法：没通过 KYC 绝不允许写入 online
  void _onToggleSwitch(bool isKycVerified, bool newValue) async {
    if (!isKycVerified) {
      // 弹出强制 KYC 弹窗
      KycDialogHelper.showKycPromptDialog(
        context,
        onVerifyNow: () async {
          bool? verified = await KycDialogHelper.showSimulatedKycSheet(context);
          if (verified == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("KYC Verified! You can now accept jobs online."),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        onLater: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Action blocked: Complete KYC verification to go Online.",
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        },
      );
      return;
    }

    // 只有已认证保姆才允许写入数据库
    await FirestoreService.updateNannyStatus(newValue);
  }

  void _showEarningsBreakdownSheet(String nannyUid, int totalEarnings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('nannyUid', isEqualTo: nannyUid)
                .where('status', isEqualTo: 'Completed')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              List<Map<String, dynamic>> completedJobs = [];
              int calculatedTotalEarnings = 0;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  int grandTotal =
                      int.tryParse(
                        data['totalPrice']?.toString() ??
                            data['total_price']?.toString() ??
                            '0',
                      ) ??
                      0;
                  calculatedTotalEarnings += grandTotal;
                  completedJobs.add({
                    'date': data['date'] ?? 'Unknown Date',
                    'parentName':
                        data['parentName'] ??
                        data['clientName'] ??
                        'Client Parent',
                    'totalPrice': grandTotal,
                    'time': data['time'] ?? '',
                  });
                }
              }
              int displayTotal = calculatedTotalEarnings > 0
                  ? calculatedTotalEarnings
                  : totalEarnings;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Earnings Summary",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.gray),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Net Revenue",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "RM $displayTotal.00",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Payout History",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (completedJobs.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        alignment: Alignment.center,
                        child: const Text(
                          "No completed orders yet.",
                          style: TextStyle(color: AppColors.gray, fontSize: 13),
                        ),
                      )
                    else
                      ...completedJobs.map(
                        (job) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.lightGray,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job['date'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.dark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Client: ${job['parentName']}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "+RM ${job['totalPrice']}.00",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Please log in again."));

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: Colors.white,
      onRefresh: _handleRefresh,
      child: StreamBuilder<DocumentSnapshot>(
        key: _nannyStreamKey,
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          var userData =
              userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

          // 核心校验：必须明确为 true，如果是 null 或 false 统统视为未认证
          final bool isKycVerified = userData['isKycVerified'] == true;
          bool rawIsOnline = userData['isOnline'] ?? false;

          // 强制纠偏：如果用户没通过 KYC 却在数据库里记录着 isOnline=true，立刻在后台修正为 false
          if (!isKycVerified && rawIsOnline) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FirestoreService.updateNannyStatus(false);
            });
            rawIsOnline = false;
          }

          // 最终页面呈现的在线状态：必须同时满足 KYC 认证成功 + 在线开
          final bool effectiveOnline = isKycVerified && rawIsOnline;
          final int totalEarnings =
              int.tryParse(userData['total_earnings']?.toString() ?? '0') ?? 0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部在线切换条
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${userData['name'] ?? 'Caregiver'} 👩‍⚕️",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: effectiveOnline
                                    ? AppColors.success
                                    : AppColors.muted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              effectiveOnline
                                  ? "Accepting Jobs (Online)"
                                  : (!isKycVerified
                                        ? "Offline (KYC Required)"
                                        : "Paused (Offline)"),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: effectiveOnline
                                    ? AppColors.success
                                    : (isKycVerified
                                          ? AppColors.gray
                                          : const Color(0xFFD97706)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: effectiveOnline,
                      activeColor: AppColors.success,
                      // 点击直接走拦截判断
                      onChanged: (val) => _onToggleSwitch(isKycVerified, val),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 未认证 KYC 醒目提示横幅
                if (!isKycVerified) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFD97706),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Identity Verification Pending",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              Text(
                                "Complete KYC to enable Online status & get jobs.",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            bool? done =
                                await KycDialogHelper.showSimulatedKycSheet(
                                  context,
                                );
                            if (done == true && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "KYC Verified! You can now switch Online.",
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Verify",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // SDG 8 理念胶囊卡
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.handshake_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Aligned with SDG 8: Fair wages and transparent care economy.",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 统计卡片
                GestureDetector(
                  onTap: () => _showEarningsBreakdownSheet(uid, totalEarnings),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.dark,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Earnings",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NannyReviewsScreen(),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      color: AppColors.accent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${userData['rating'] ?? '5.0'}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white70,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "RM $totalEarnings.00",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white54,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Tap to view complete payout analytics",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  "Active Job Demands",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 14),

                if (!effectiveOnline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          !isKycVerified
                              ? Icons.lock_outline_rounded
                              : Icons.bedtime_outlined,
                          color: AppColors.muted,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          !isKycVerified
                              ? "Identity Verification (KYC) required before going online."
                              : "You are offline. Turn switch ON to get requests.",
                          style: const TextStyle(
                            color: AppColors.gray,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirestoreService.getBookingsStream(true),
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
                      final List<Map<String, dynamic>> activeJobs =
                          (snapshot.data ?? [])
                              .where(
                                (job) =>
                                    job['status'] == 'Pending' ||
                                    job['status'] == 'Confirmed' ||
                                    job['status'] ==
                                        'Completed (Pending Verification)',
                              )
                              .toList();

                      if (activeJobs.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 44,
                                color: AppColors.muted,
                              ),
                              SizedBox(height: 8),
                              Text(
                                "No active job requests right now.",
                                style: TextStyle(
                                  color: AppColors.gray,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: activeJobs
                            .map((job) => _buildNannyJobCard(job))
                            .toList(),
                      );
                    },
                  ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNannyJobCard(Map<String, dynamic> job) {
    String status = job['status'] ?? 'Pending';
    bool isPending = status == 'Pending';
    bool isConfirmed = status == 'Confirmed';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                job['date'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.dark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isPending
                        ? const Color(0xFFB45309)
                        : const Color(0xFF0369A1),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            job['time'] ?? '',
            style: const TextStyle(color: AppColors.gray, fontSize: 13),
          ),
          if ((job['notes'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                job['notes'],
                style: const TextStyle(fontSize: 12, color: AppColors.body),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (isPending) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async => await FirestoreService.updateBooking(
                      job['docId'],
                      {'status': 'Cancelled'},
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      foregroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "Decline",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async => await FirestoreService.updateBooking(
                      job['docId'],
                      {'status': 'Confirmed'},
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "Accept",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else if (isConfirmed) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await FirestoreService.requestCompleteBooking(
                        job['docId'],
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Submitted! Awaiting parent verification.",
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Complete Service & Request Payout",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Center(
                    child: Text(
                      "Pending parent payout confirmation...",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.gray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
