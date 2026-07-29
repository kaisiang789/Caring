import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../services/firestore_service.dart';
import 'nanny_reviews_screen.dart';

class NannyHomeScreen extends StatefulWidget {
  const NannyHomeScreen({super.key});

  @override
  State<NannyHomeScreen> createState() => _NannyHomeScreenState();
}

class _NannyHomeScreenState extends State<NannyHomeScreen> {
  Key _nannyStreamKey = UniqueKey();

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _nannyStreamKey = UniqueKey();
      });
    }
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
                  height: 250,
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

                  int addonTotal = 0;
                  List<Map<String, dynamic>> addonItems = [];
                  if (data['selectedAddons'] != null) {
                    List<dynamic> rawAddons = data['selectedAddons'] as List;
                    for (var addon in rawAddons) {
                      if (addon is Map) {
                        int price =
                            int.tryParse(addon['price']?.toString() ?? '0') ??
                            0;
                        addonTotal += price;
                        addonItems.add({
                          'name': addon['name'] ?? 'Add-on Service',
                          'price': price,
                        });
                      }
                    }
                  }

                  int grandTotal =
                      int.tryParse(
                        data['totalPrice']?.toString() ??
                            data['total_price']?.toString() ??
                            '0',
                      ) ??
                      0;
                  int baseServicePrice = grandTotal - addonTotal;
                  if (baseServicePrice < 0) baseServicePrice = 0;

                  calculatedTotalEarnings += grandTotal;

                  completedJobs.add({
                    'date': data['date'] ?? 'Unknown Date',
                    'parentName':
                        data['parentName'] ??
                        data['clientName'] ??
                        'Client Parent',
                    'totalPrice': grandTotal,
                    'basePrice': baseServicePrice,
                    'addonTotal': addonTotal,
                    'addons': addonItems,
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
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Earnings Breakdown",
                              style: TextStyle(
                                fontSize: 20,
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
                    const Divider(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Total Net Earnings",
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
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      "Payout History by Date:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.dark,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (completedJobs.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        alignment: Alignment.center,
                        child: const Text(
                          "No completed earnings records found.",
                          style: TextStyle(
                            color: AppColors.gray,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: completedJobs.length,
                        itemBuilder: (context, index) {
                          final job = completedJobs[index];
                          final List<Map<String, dynamic>> addons =
                              List<Map<String, dynamic>>.from(job['addons']);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.lightGray,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          job['date'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.dark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "+RM ${job['totalPrice']}.00",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Client: ${job['parentName']} (${job['time']})",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gray,
                                  ),
                                ),
                                const Divider(
                                  height: 20,
                                  color: Color(0xFFE2E8F0),
                                ),

                                // 💡 基础服务费 (加防溢出)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.child_care,
                                            size: 14,
                                            color: AppColors.gray,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            "Base Care Service",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "RM ${job['basePrice']}.00",
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.dark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 💡 修复重点：Add-on 服务超长文本加 Expanded 防溢出！
                                if (addons.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  ...addons.map((addon) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.add_circle_outline,
                                                  size: 14,
                                                  color: AppColors.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    "Add-on: ${addon['name']}",
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors.dark,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "+RM ${addon['price']}.00",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Close Breakdown",
                        style: TextStyle(fontWeight: FontWeight.bold),
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
          bool isOnline = userData['isOnline'] ?? false;
          int totalEarnings =
              int.tryParse(userData['total_earnings']?.toString() ?? '0') ?? 0;

          return SingleChildScrollView(
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
                      children: [
                        Text(
                          "${userData['name'] ?? 'Caregiver'}, Welcome back!",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dark,
                          ),
                        ),
                        Row(
                          children: [
                            const Text(
                              "You are currently ",
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.gray,
                              ),
                            ),
                            Text(
                              isOnline ? "Online" : "Offline",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isOnline
                                    ? AppColors.success
                                    : AppColors.gray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: isOnline,
                      activeColor: AppColors.success,
                      onChanged: (val) async {
                        await FirestoreService.updateNannyStatus(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF97316),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.handshake,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Empowering Caregivers",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9A3412),
                              ),
                            ),
                            Text(
                              "Supporting SDG 8: Decent Work & Economic Growth by ensuring fair wages.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC2410C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                GestureDetector(
                  onTap: () => _showEarningsBreakdownSheet(uid, totalEarnings),
                  child: Container(
                    padding: const EdgeInsets.all(24),
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
                            Text(
                              "Total Earnings (Click for details)",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              "RM $totalEarnings.00",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "  Secure Parent Verification",
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NannyReviewsScreen(),
                                  ),
                                );
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: AppColors.accent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${userData['rating'] ?? '5.0'} Rating",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Colors.white70,
                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  "Active Job Opportunities",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 15),
                if (!isOnline)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "You are offline. Go online to receive job offers.",
                        style: TextStyle(
                          color: AppColors.gray,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Error: ${snapshot.error}",
                            style: const TextStyle(color: AppColors.danger),
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
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.lightGray),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: AppColors.gray,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "No active job requests at the moment.",
                                style: TextStyle(
                                  color: AppColors.gray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: activeJobs
                            .map((job) => _buildJobCard(job, uid))
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

  Widget _buildJobCard(Map<String, dynamic> job, String nannyUid) {
    String status = job['status'] ?? 'Pending';
    bool isPending = status == 'Pending';
    bool isConfirmed = status == 'Confirmed';
    bool isWaitingVerify = status == 'Completed (Pending Verification)';
    Color cardHeaderColor = AppColors.dark;
    if (isConfirmed) cardHeaderColor = AppColors.primary;
    if (isWaitingVerify) cardHeaderColor = const Color(0xFFD97706);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPending
                          ? "New Booking Request"
                          : (isConfirmed
                                ? "Ongoing Service Job"
                                : "Awaiting Parent Payout"),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cardHeaderColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['date'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFEF08A)
                      : (isConfirmed
                            ? const Color(0xFFE0F2FE)
                            : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isWaitingVerify ? "Pending Payout" : status,
                  style: TextStyle(
                    color: isPending
                        ? const Color(0xFF854D0E)
                        : (isConfirmed
                              ? const Color(0xFF0369A1)
                              : const Color(0xFFB45309)),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: AppColors.gray),
              const SizedBox(width: 6),
              Text(
                job['time'] ?? '',
                style: const TextStyle(fontSize: 13, color: AppColors.dark),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              job['notes'] ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              if (isPending) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async => await FirestoreService.updateBooking(
                      job['docId'],
                      {'status': 'Cancelled'},
                    ),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    label: const Text(
                      "Decline",
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async => await FirestoreService.updateBooking(
                      job['docId'],
                      {'status': 'Confirmed'},
                    ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      "Accept",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Completion request sent! Waiting for parent confirmation.",
                            ),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      "Submit For Verification",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          size: 16,
                          color: AppColors.gray,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Waiting for Parent to click 'Confirm Payout'...",
                          style: TextStyle(
                            color: AppColors.gray,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
