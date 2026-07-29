import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../services/firestore_service.dart';
import '../widgets/rating_dialog.dart';
import 'tracking_screen.dart';

class BookingsScreen extends StatefulWidget {
  final bool isNannyMode;
  const BookingsScreen({super.key, required this.isNannyMode});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  void _updateBookingStatus(String bookingId, String newStatus) async {
    try {
      await FirestoreService.updateBooking(bookingId, {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Booking status updated to $newStatus!"),
            backgroundColor: newStatus == 'Confirmed'
                ? AppColors.success
                : AppColors.danger,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating booking: $e");
    }
  }

  // 💡 亮点方法：删除无用的旧订单文档
  void _deleteBooking(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pending booking request cancelled and removed!"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting booking: $e");
    }
  }

  void _submitForVerification(String bookingId) async {
    try {
      await FirestoreService.requestCompleteBooking(bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Completion request sent! Waiting for parent confirmation.",
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error submitting for verification: $e");
    }
  }

  void _openRatingDialog(Map<String, dynamic> booking) async {
    final String bookingId = booking['docId'] ?? '';
    final String nannyUid = booking['nannyUid'] ?? '';

    final ratingResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(booking: booking),
    );

    if (ratingResult != null) {
      double rating = ratingResult['rating'] ?? 5.0;
      String comment = ratingResult['reviewText'] ?? '';
      String? base64Img = ratingResult['base64Image'];

      await FirestoreService.submitReview(
        bookingId,
        nannyUid,
        rating,
        comment,
        base64Img,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Review saved & updated successfully!"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _parentConfirmPayoutAndRate(Map<String, dynamic> booking) async {
    final String bookingId = booking['docId'] ?? '';
    final String nannyUid = booking['nannyUid'] ?? '';

    try {
      await FirestoreService.parentConfirmPayout(bookingId, nannyUid);
    } catch (e) {
      debugPrint("Payout transaction failed: $e");
    }

    if (mounted) {
      _openRatingDialog(booking);
    }
  }

  void _showBookingDetailsSheet(
    Map<String, dynamic> booking,
    String name,
    String image,
    String roleTitle,
    String displayStatus,
    Color statusColor,
  ) {
    List<dynamic> rawAddons = booking['selectedAddons'] ?? [];
    List<Map<String, dynamic>> addons = rawAddons
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: NetworkImage(image),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roleTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.gray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      displayStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              const Text(
                "Booking Specification",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow("Appointment Date", booking['date'] ?? 'TBD'),
              _buildDetailRow("Service Duration", booking['time'] ?? 'TBD'),
              _buildDetailRow(
                "Total Payout",
                "RM ${booking['totalPrice'] ?? booking['total_price'] ?? '0'}.00",
                isPrimary: true,
              ),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(
                      widget.isNannyMode
                          ? booking['parentUid']
                          : booking['nannyUid'],
                    )
                    .get(),
                builder: (context, userSnap) {
                  String loc = "Skudai, Johor Bahru";
                  if (userSnap.hasData && userSnap.data!.exists) {
                    var uData = userSnap.data!.data() as Map<String, dynamic>;
                    loc = uData['location'] ?? uData['address'] ?? loc;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildDetailRow("Service Location", loc),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                "Add-on Extra Services",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              if (addons.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Standard Care Only (No add-ons requested)",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.gray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Column(
                  children: addons.map((addon) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.stars_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                addon['name'] ?? 'Add-on Service',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.dark,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "+RM ${addon['price']}.00",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              const Text(
                "Notes / Special Instructions",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  (booking['notes'] == null ||
                          booking['notes'].toString().isEmpty)
                      ? "No special requirements specified."
                      : booking['notes'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close Window",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: AppColors.gray, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isPrimary ? AppColors.primary : AppColors.dark,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                fontSize: isPrimary ? 15 : 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUid.isEmpty) {
      return const Scaffold(body: Center(child: Text("Please log in first.")));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text(
                widget.isNannyMode ? "Job Requests" : "My Bookings",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirestoreService.getBookingsStream(widget.isNannyMode),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    );
                  }

                  final List<Map<String, dynamic>> rawBookings =
                      snapshot.data ?? [];
                  if (rawBookings.isEmpty) {
                    return const Center(
                      child: Text(
                        "No booking records found.",
                        style: TextStyle(color: AppColors.gray),
                      ),
                    );
                  }

                  // 💡 改进 1：ID 排重机制，防止相同 docId 重复出现
                  final Set<String> seenDocIds = {};
                  final List<Map<String, dynamic>> uniqueBookings = [];
                  for (var b in rawBookings) {
                    String id = b['docId'] ?? '';
                    if (id.isNotEmpty && !seenDocIds.contains(id)) {
                      seenDocIds.add(id);
                      uniqueBookings.add(b);
                    }
                  }

                  int getPriority(String status) {
                    if (status == 'Confirmed') return 1;
                    if (status == 'Completed (Pending Verification)') return 2;
                    if (status == 'Pending') return 3;
                    return 4; // Completed, Cancelled, Declined
                  }

                  List<Map<String, dynamic>> activeList = [];
                  List<Map<String, dynamic>> historyList = [];

                  for (var b in uniqueBookings) {
                    String st = b['status'] ?? 'Pending';
                    if (st == 'Completed' ||
                        st == 'Cancelled' ||
                        st == 'Declined') {
                      historyList.add(b);
                    } else {
                      activeList.add(b);
                    }
                  }

                  activeList.sort((a, b) {
                    int pA = getPriority(a['status'] ?? '');
                    int pB = getPriority(b['status'] ?? '');
                    return pA.compareTo(pB);
                  });

                  historyList.sort((a, b) {
                    Timestamp timeA = a['createdAt'] ?? Timestamp.now();
                    Timestamp timeB = b['createdAt'] ?? Timestamp.now();
                    return timeB.compareTo(timeA);
                  });

                  List<Map<String, dynamic>> sortedDisplayList = [
                    ...activeList,
                    ...historyList,
                  ];

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    itemCount: sortedDisplayList.length,
                    itemBuilder: (context, index) {
                      final booking = sortedDisplayList[index];
                      final String bookingId = booking['docId'] ?? '';
                      final String status = booking['status'] ?? 'Pending';
                      final String dateStr = booking['date'] ?? 'TBD';
                      final String timeStr = booking['time'] ?? 'TBD';

                      final bool isRated = booking['isRated'] ?? false;
                      final double userRating =
                          double.tryParse(
                            booking['rating']?.toString() ?? '5.0',
                          ) ??
                          5.0;
                      final String userReviewText = booking['reviewText'] ?? '';
                      final String? userReviewImg = booking['reviewImageUrl'];

                      bool isPending = status == 'Pending';
                      bool isConfirmed = status == 'Confirmed';
                      bool isWaitingVerify =
                          status == 'Completed (Pending Verification)';
                      bool isCompleted = status == 'Completed';

                      bool showHistoryDivider =
                          index == activeList.length && historyList.isNotEmpty;

                      Color statusColor = Colors.orange;
                      String displayStatusText = status;

                      if (isConfirmed || isCompleted)
                        statusColor = AppColors.success;
                      if (status == 'Declined' || status == 'Cancelled')
                        statusColor = AppColors.danger;
                      if (isWaitingVerify) {
                        statusColor = const Color(0xFFD97706);
                        displayStatusText = "Pending Payout";
                      }

                      String currentResolvedName = 'User';
                      String currentResolvedImage =
                          'https://api.dicebear.com/7.x/avataaars/png?seed=user';
                      String roleTitle = widget.isNannyMode
                          ? "Client Parent"
                          : "Professional Caregiver";

                      Widget cardHeader = widget.isNannyMode
                          ? FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(booking['parentUid'] ?? '')
                                  .get(),
                              builder: (context, parentSnap) {
                                currentResolvedName =
                                    booking['parentName'] ??
                                    booking['clientName'] ??
                                    'Client Parent';
                                currentResolvedImage =
                                    'https://api.dicebear.com/7.x/avataaars/png?seed=$currentResolvedName';
                                if (parentSnap.hasData &&
                                    parentSnap.data!.exists) {
                                  var pData =
                                      parentSnap.data!.data()
                                          as Map<String, dynamic>;
                                  currentResolvedName =
                                      pData['name'] ?? currentResolvedName;
                                  currentResolvedImage =
                                      pData['image'] ??
                                      pData['avatar'] ??
                                      currentResolvedImage;
                                }
                                return _buildHeaderTile(
                                  currentResolvedName,
                                  currentResolvedImage,
                                  roleTitle,
                                  displayStatusText,
                                  statusColor,
                                );
                              },
                            )
                          : Builder(
                              builder: (context) {
                                currentResolvedName =
                                    booking['nannyName'] ??
                                    booking['name'] ??
                                    'Nanny Caregiver';
                                currentResolvedImage =
                                    booking['image'] ??
                                    booking['nannyImage'] ??
                                    'https://api.dicebear.com/7.x/avataaars/png?seed=Nanny';
                                return _buildHeaderTile(
                                  currentResolvedName,
                                  currentResolvedImage,
                                  roleTitle,
                                  displayStatusText,
                                  statusColor,
                                );
                              },
                            );

                      Widget cardContainer = GestureDetector(
                        onTap: () => _showBookingDetailsSheet(
                          booking,
                          currentResolvedName,
                          currentResolvedImage,
                          roleTitle,
                          displayStatusText,
                          statusColor,
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cardHeader,
                              _buildDivider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Appointment Date:",
                                    style: TextStyle(
                                      color: AppColors.gray,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      color: AppColors.dark,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Service Duration:",
                                    style: TextStyle(
                                      color: AppColors.gray,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      color: AppColors.dark,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.isNannyMode) ...[
                                if (isPending) ...[
                                  _buildDivider(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: AppColors.danger,
                                            ),
                                            foregroundColor: AppColors.danger,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () => _updateBookingStatus(
                                            bookingId,
                                            'Cancelled',
                                          ),
                                          child: const Text(
                                            "Decline",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () => _updateBookingStatus(
                                            bookingId,
                                            'Confirmed',
                                          ),
                                          child: const Text(
                                            "Accept",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (isConfirmed) ...[
                                  _buildDivider(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.send_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            "Submit For Verification",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _submitForVerification(bookingId),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (isWaitingVerify) ...[
                                  _buildDivider(),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightGray,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.hourglass_empty,
                                          size: 16,
                                          color: AppColors.gray,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Waiting for Parent payout confirmation...",
                                          style: TextStyle(
                                            color: AppColors.gray,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (isCompleted) ...[
                                  _buildDivider(),
                                  if (isRated) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.lightGray,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "Parent's Feedback:",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: AppColors.gray,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Row(
                                                    children: List.generate(
                                                      5,
                                                      (i) => Icon(
                                                        i < userRating.floor()
                                                            ? Icons.star
                                                            : Icons.star_border,
                                                        size: 14,
                                                        color: AppColors.accent,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "${userRating.toStringAsFixed(1)} Stars",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: AppColors.dark,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          if (userReviewText.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              userReviewText,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.dark,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                          if (userReviewImg != null &&
                                              userReviewImg.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                base64Decode(userReviewImg),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "Parent has not left a review yet.",
                                          style: TextStyle(
                                            color: AppColors.gray,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ] else ...[
                                if (isConfirmed) ...[
                                  _buildDivider(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.dark,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 11,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.location_on_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            "Live Tracking",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    TrackingScreen(
                                                      booking: booking,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (isWaitingVerify) ...[
                                  _buildDivider(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.success,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.verified_user_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            "Confirm Payout & Rate Caregiver",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _parentConfirmPayoutAndRate(
                                                booking,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (isPending) ...[
                                  // 💡 改进 2：在 Pending 卡片下提供一键删除/撤销按钮，允许清理数据库旧测试订单！
                                  _buildDivider(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: AppColors.danger,
                                            ),
                                            foregroundColor: AppColors.danger,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            "Cancel Request",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          onPressed: () =>
                                              _deleteBooking(bookingId),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else if (isCompleted) ...[
                                  _buildDivider(),
                                  if (isRated) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.lightGray,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: List.generate(
                                                  5,
                                                  (i) => Icon(
                                                    i < userRating.floor()
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    size: 16,
                                                    color: AppColors.accent,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                "${userRating.toStringAsFixed(1)} Stars",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: AppColors.dark,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (userReviewText.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              userReviewText,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.dark,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                          if (userReviewImg != null &&
                                              userReviewImg.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.memory(
                                                base64Decode(userReviewImg),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppColors.primary,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.edit_note_rounded,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          "Edit Review",
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _openRatingDialog(booking),
                                      ),
                                    ),
                                  ] else ...[
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 11,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.star_half_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          "Rate & Review Caregiver",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _openRatingDialog(booking),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ],
                          ),
                        ),
                      );

                      if (showHistoryDivider) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHistorySectionDivider(),
                            cardContainer,
                          ],
                        );
                      }

                      return cardContainer;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
      child: Row(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: AppColors.gray,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            "History Records",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.gray,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTile(
    String name,
    String image,
    String subTitle,
    String status,
    Color statusColor,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[100],
          backgroundImage: NetworkImage(image),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subTitle,
                style: const TextStyle(fontSize: 12, color: AppColors.gray),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, thickness: 1, color: AppColors.lightGray),
    );
  }
}
