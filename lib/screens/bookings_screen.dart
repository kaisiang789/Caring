import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import '../services/firestore_service.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/care_timeline_dialog.dart';
import 'tracking_screen.dart';

class BookingsScreen extends StatefulWidget {
  final bool isNannyMode;
  const BookingsScreen({super.key, required this.isNannyMode});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  // 0: All, 1: Confirmed/Active, 2: Pending, 3: History
  int _selectedFilterIndex = 0;

  int _parseHourFromString(String timeStr) {
    try {
      RegExp reg = RegExp(r'(\d+):(\d+)\s*(AM|PM)?', caseSensitive: false);
      var match = reg.firstMatch(timeStr);
      if (match != null) {
        int h = int.parse(match.group(1)!);
        String? ampm = match.group(3)?.toUpperCase();
        if (ampm == 'PM' && h < 12) h += 12;
        if (ampm == 'AM' && h == 12) h = 0;
        return h;
      }
    } catch (_) {}
    return -1;
  }

  void _acceptBooking(Map<String, dynamic> targetBooking) async {
    final String acceptedBookingId = targetBooking['docId'] ?? '';
    final String targetDate = targetBooking['date'] ?? '';
    final String nannyUid = targetBooking['nannyUid'] ?? currentUid;
    final String nannyName = targetBooking['nannyName'] ?? 'Your Caregiver';

    int acceptedStart =
        targetBooking['startHour'] ??
        _parseHourFromString(targetBooking['time']?.toString() ?? '');
    int acceptedDur =
        int.tryParse(targetBooking['duration']?.toString() ?? '2') ?? 2;
    int acceptedEndWithBuffer = (acceptedStart != -1)
        ? (acceptedStart + acceptedDur + 1)
        : 24;

    try {
      await FirestoreService.updateBooking(acceptedBookingId, {
        'status': 'Confirmed',
      });

      QuerySnapshot otherPendingSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('nannyUid', isEqualTo: nannyUid)
          .where('date', isEqualTo: targetDate)
          .where('status', isEqualTo: 'Pending')
          .get();

      int cancelledCount = 0;

      for (var doc in otherPendingSnap.docs) {
        if (doc.id == acceptedBookingId) continue;

        var data = doc.data() as Map<String, dynamic>;
        int otherStart =
            data['startHour'] ??
            _parseHourFromString(data['time']?.toString() ?? '');
        int otherDur = int.tryParse(data['duration']?.toString() ?? '2') ?? 2;
        int otherEnd = (otherStart != -1) ? (otherStart + otherDur) : 24;

        bool isOverlapping = false;
        if (acceptedStart != -1 && otherStart != -1) {
          if (otherStart < acceptedEndWithBuffer && otherEnd > acceptedStart) {
            isOverlapping = true;
          }
        } else {
          isOverlapping = true;
        }

        if (isOverlapping) {
          await doc.reference.update({
            'status': 'Cancelled',
            'cancelledReason':
                'Time slot conflict: Caregiver accepted another booking with a 1-hour rest buffer.',
          });

          String parentUid = data['parentUid'] ?? '';
          String parentName = data['parentName'] ?? 'Parent';
          String bookingTime = data['time'] ?? '';

          if (parentUid.isNotEmpty) {
            await FirestoreService.sendMessage(
              parentUid,
              parentName,
              data['parentImage'] ?? '',
              "⚠️ Notice: Your booking on $targetDate ($bookingTime) was automatically cancelled because nanny $nannyName accepted an overlapping booking (including 1-hr rest buffer).",
            );
          }
          cancelledCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cancelledCount > 0
                  ? "Booking Confirmed! $cancelledCount conflicting request(s) were cancelled & notified."
                  : "Booking Confirmed!",
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error accepting booking: $e");
    }
  }

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

  void _deleteBooking(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Booking request cancelled."),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error deleting booking: $e");
    }
  }

  void _submitForVerification(Map<String, dynamic> booking) async {
    final String bookingId = booking['docId'] ?? '';
    final List<dynamic> careUpdates = booking['careUpdates'] ?? [];

    if (careUpdates.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD97706),
                size: 26,
              ),
              SizedBox(width: 8),
              Text(
                "Care Update Required",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: AppColors.dark,
                ),
              ),
            ],
          ),
          content: const Text(
            "To complete this booking, platform safety policy requires caregivers to post at least ONE care update or snapshot proof.",
            style: TextStyle(fontSize: 13, color: AppColors.body, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Later",
                style: TextStyle(color: AppColors.gray),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(
                Icons.camera_alt_outlined,
                size: 16,
                color: Colors.white,
              ),
              label: const Text(
                "Post Update Now",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) =>
                      CareTimelineDialog(bookingId: bookingId),
                );
              },
            ),
          ],
        ),
      );
      return;
    }

    try {
      await FirestoreService.requestCompleteBooking(bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Completion request sent! Waiting for parent payout confirmation.",
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
    if (mounted) _openRatingDialog(booking);
  }

  void _showFullScreenImage(BuildContext context, String base64Str) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              maxScale: 5.0,
              child: Image.memory(base64Decode(base64Str), fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    List<dynamic> careUpdates = booking['careUpdates'] ?? [];

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
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.lightGray,
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
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
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
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      displayStatus,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),

              const Text(
                "Booking Specification",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
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
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Live Care Updates",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${careUpdates.length} Milestones",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (careUpdates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      "No live care updates posted yet for this session.",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.gray,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: careUpdates.reversed.map((update) {
                    String? img = update['image'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                update['activity'] ?? 'Milestone',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: AppColors.dark,
                                ),
                              ),
                              Text(
                                update['time'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.gray,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if ((update['notes'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              update['notes'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.body,
                                height: 1.3,
                              ),
                            ),
                          ],
                          if (img != null && img.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () => _showFullScreenImage(context, img),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  base64Decode(img),
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              const Text(
                "Add-on Extra Services",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
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
                        color: AppColors.primaryLight.withOpacity(0.5),
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
              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close Window",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 15,
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w600,
                fontSize: isPrimary ? 16 : 13,
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
    if (currentUid.isEmpty)
      return const Scaffold(body: Center(child: Text("Please log in first.")));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                widget.isNannyMode ? "Job Center" : "My Bookings",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                  letterSpacing: -0.5,
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

                  // 去重
                  final Set<String> seenDocIds = {};
                  final List<Map<String, dynamic>> uniqueBookings = [];
                  for (var b in rawBookings) {
                    String id = b['docId'] ?? '';
                    if (id.isNotEmpty && !seenDocIds.contains(id)) {
                      seenDocIds.add(id);
                      uniqueBookings.add(b);
                    }
                  }

                  // 1. 进行中 (Confirmed 绝对置顶)
                  List<Map<String, dynamic>> confirmedList = [];
                  // 2. 待结单确认 (Pending Payout)
                  List<Map<String, dynamic>> pendingPayoutList = [];
                  // 3. 待处理申请 (Pending)
                  List<Map<String, dynamic>> pendingList = [];
                  // 4. 历史记录 (Completed / Cancelled / Declined)
                  List<Map<String, dynamic>> historyList = [];

                  for (var b in uniqueBookings) {
                    String st = b['status'] ?? 'Pending';
                    if (st == 'Confirmed') {
                      confirmedList.add(b);
                    } else if (st == 'Completed (Pending Verification)') {
                      pendingPayoutList.add(b);
                    } else if (st == 'Pending') {
                      pendingList.add(b);
                    } else {
                      historyList.add(b);
                    }
                  }

                  // 组内排序
                  confirmedList.sort((a, b) {
                    Timestamp tA = a['createdAt'] ?? Timestamp.now();
                    Timestamp tB = b['createdAt'] ?? Timestamp.now();
                    return tB.compareTo(tA);
                  });

                  pendingPayoutList.sort((a, b) {
                    Timestamp tA = a['createdAt'] ?? Timestamp.now();
                    Timestamp tB = b['createdAt'] ?? Timestamp.now();
                    return tB.compareTo(tA);
                  });

                  pendingList.sort((a, b) {
                    Timestamp tA = a['createdAt'] ?? Timestamp.now();
                    Timestamp tB = b['createdAt'] ?? Timestamp.now();
                    return tB.compareTo(tA);
                  });

                  historyList.sort((a, b) {
                    Timestamp tA = a['createdAt'] ?? Timestamp.now();
                    Timestamp tB = b['createdAt'] ?? Timestamp.now();
                    return tB.compareTo(tA);
                  });

                  // 核心总排位：Confirmed 第一 ➔ Pending Payout 第二 ➔ Pending 第三 ➔ 历史最底
                  List<Map<String, dynamic>> allSortedList = [
                    ...confirmedList,
                    ...pendingPayoutList,
                    ...pendingList,
                    ...historyList,
                  ];

                  // Active 分栏包含已确认和待结款
                  List<Map<String, dynamic>> activeTabList = [
                    ...confirmedList,
                    ...pendingPayoutList,
                  ];

                  // 根据选中的 Tab 决定呈现的数据
                  List<Map<String, dynamic>> currentFilteredList = [];
                  if (_selectedFilterIndex == 0) {
                    currentFilteredList = allSortedList; // Confirmed 稳居最上面
                  } else if (_selectedFilterIndex == 1) {
                    currentFilteredList = activeTabList;
                  } else if (_selectedFilterIndex == 2) {
                    currentFilteredList = pendingList;
                  } else {
                    currentFilteredList = historyList;
                  }

                  return Column(
                    children: [
                      // 顶部药丸分栏条
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            _buildTabItem(0, "All", uniqueBookings.length),
                            const SizedBox(width: 8),
                            _buildTabItem(
                              1,
                              "Active",
                              activeTabList.length,
                              isHighlight: confirmedList.isNotEmpty,
                            ),
                            const SizedBox(width: 8),
                            _buildTabItem(2, "Pending", pendingList.length),
                            const SizedBox(width: 8),
                            _buildTabItem(3, "History", historyList.length),
                          ],
                        ),
                      ),

                      // 进行中服务置顶提示条
                      if (confirmedList.isNotEmpty && _selectedFilterIndex == 0)
                        Container(
                          margin: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.flash_on_rounded,
                                color: Color(0xFF16A34A),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "${confirmedList.length} Active Session(s) Confirmed & In-Progress",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 6),

                      // 订单卡片列表
                      Expanded(
                        child: currentFilteredList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedFilterIndex == 1
                                          ? Icons.event_available_rounded
                                          : Icons.inbox_rounded,
                                      size: 48,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _selectedFilterIndex == 1
                                          ? "No ongoing care sessions right now."
                                          : "No orders found in this category.",
                                      style: const TextStyle(
                                        color: AppColors.gray,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 6,
                                ),
                                itemCount: currentFilteredList.length,
                                itemBuilder: (context, index) {
                                  final booking = currentFilteredList[index];
                                  final String bookingId =
                                      booking['docId'] ?? '';
                                  final String status =
                                      booking['status'] ?? 'Pending';
                                  final String dateStr =
                                      booking['date'] ?? 'TBD';
                                  final String timeStr =
                                      booking['time'] ?? 'TBD';
                                  final bool isRated =
                                      booking['isRated'] ?? false;
                                  final double userRating =
                                      double.tryParse(
                                        booking['rating']?.toString() ?? '5.0',
                                      ) ??
                                      5.0;
                                  final String userReviewText =
                                      booking['reviewText'] ?? '';
                                  final String? userReviewImg =
                                      booking['reviewImageUrl'];
                                  final List<dynamic> careUpdates =
                                      booking['careUpdates'] ?? [];

                                  Timestamp? lastUpdateTs =
                                      booking['lastCareUpdateAt'];
                                  bool isCheckinOverdue = false;
                                  if (lastUpdateTs != null) {
                                    final diffHours = DateTime.now()
                                        .difference(lastUpdateTs.toDate())
                                        .inMinutes;
                                    if (diffHours >= 60)
                                      isCheckinOverdue = true;
                                  }

                                  bool isPending = status == 'Pending';
                                  bool isConfirmed = status == 'Confirmed';
                                  bool isWaitingVerify =
                                      status ==
                                      'Completed (Pending Verification)';
                                  bool isCompleted = status == 'Completed';

                                  Color statusColor = const Color(0xFFD97706);
                                  String displayStatusText = status;
                                  if (isConfirmed || isCompleted)
                                    statusColor = AppColors.success;
                                  if (status == 'Declined' ||
                                      status == 'Cancelled')
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
                                                  pData['name'] ??
                                                  currentResolvedName;
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

                                  return GestureDetector(
                                    onTap: () => _showBookingDetailsSheet(
                                      booking,
                                      currentResolvedName,
                                      currentResolvedImage,
                                      roleTitle,
                                      displayStatusText,
                                      statusColor,
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 7,
                                      ),
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isConfirmed
                                              ? AppColors.success.withOpacity(
                                                  0.6,
                                                )
                                              : (isPending
                                                    ? const Color(0xFFFDE68A)
                                                    : AppColors.border),
                                          width: isConfirmed ? 1.6 : 0.8,
                                        ),
                                        boxShadow: AppColors.cardShadow,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                  fontWeight: FontWeight.w600,
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
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),

                                          // 进行中的看护打卡提示条
                                          if (isConfirmed &&
                                              widget.isNannyMode) ...[
                                            const SizedBox(height: 10),
                                            if (careUpdates.isEmpty)
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFEF2F2,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFFECACA,
                                                    ),
                                                  ),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .info_outline_rounded,
                                                      color: AppColors.danger,
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        "Check-in reminder: Post at least 1 update before completing job.",
                                                        style: TextStyle(
                                                          color:
                                                              AppColors.danger,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else if (isCheckinOverdue)
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFFFBEB,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFFDE68A,
                                                    ),
                                                  ),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time_rounded,
                                                      color: Color(0xFFD97706),
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        "Hourly check-in recommended: 1h+ passed since your last update.",
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFF92400E,
                                                          ),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryLight
                                                      .withOpacity(0.4),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      size: 14,
                                                      color: AppColors.primary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        "Status updated (${careUpdates.last['time']}): ${careUpdates.last['activity']}",
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],

                                          // 保姆端操作区
                                          if (widget.isNannyMode) ...[
                                            if (isPending) ...[
                                              _buildDivider(),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      style: OutlinedButton.styleFrom(
                                                        side: const BorderSide(
                                                          color:
                                                              AppColors.danger,
                                                          width: 1.2,
                                                        ),
                                                        foregroundColor:
                                                            AppColors.danger,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 12,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: () =>
                                                          _updateBookingStatus(
                                                            bookingId,
                                                            'Declined',
                                                          ),
                                                      child: const Text(
                                                        "Decline",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          color:
                                                              AppColors.danger,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: ElevatedButton(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors.primary,
                                                        foregroundColor:
                                                            Colors.white,
                                                        elevation: 0,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 12,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed: () =>
                                                          _acceptBooking(
                                                            booking,
                                                          ),
                                                      child: const Text(
                                                        "Accept",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          color: Colors.white,
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
                                                    child: OutlinedButton.icon(
                                                      style: OutlinedButton.styleFrom(
                                                        side: const BorderSide(
                                                          color:
                                                              AppColors.primary,
                                                          width: 1.2,
                                                        ),
                                                        foregroundColor:
                                                            AppColors.primary,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 11,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                      ),
                                                      icon: const Icon(
                                                        Icons
                                                            .camera_alt_rounded,
                                                        size: 16,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                      label: Text(
                                                        careUpdates.isEmpty
                                                            ? "Check-in First"
                                                            : "Post Update",
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) =>
                                                              CareTimelineDialog(
                                                                bookingId:
                                                                    bookingId,
                                                              ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors.primary,
                                                        foregroundColor:
                                                            Colors.white,
                                                        elevation: 0,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 12,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                      ),
                                                      icon: const Icon(
                                                        Icons.send_rounded,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                      label: const Text(
                                                        "Complete Job",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      onPressed: () =>
                                                          _submitForVerification(
                                                            booking,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else if (isWaitingVerify) ...[
                                              _buildDivider(),
                                              Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.lightGray,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .hourglass_empty_rounded,
                                                      size: 16,
                                                      color: AppColors.gray,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      "Waiting for Parent payout confirmation...",
                                                      style: TextStyle(
                                                        color: AppColors.gray,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.lightGray,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.border,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          const Text(
                                                            "Parent's Feedback:",
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12,
                                                              color: AppColors
                                                                  .gray,
                                                            ),
                                                          ),
                                                          Row(
                                                            children: [
                                                              Row(
                                                                children: List.generate(
                                                                  5,
                                                                  (i) => Icon(
                                                                    i <
                                                                            userRating
                                                                                .floor()
                                                                        ? Icons
                                                                              .star_rounded
                                                                        : Icons
                                                                              .star_border_rounded,
                                                                    size: 14,
                                                                    color: AppColors
                                                                        .accent,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 4,
                                                              ),
                                                              Text(
                                                                "${userRating.toStringAsFixed(1)} Stars",
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12,
                                                                  color:
                                                                      AppColors
                                                                          .dark,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      if (userReviewText
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          userReviewText,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color: AppColors
                                                                    .body,
                                                                height: 1.3,
                                                              ),
                                                        ),
                                                      ],
                                                      if (userReviewImg !=
                                                              null &&
                                                          userReviewImg
                                                              .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          child: Image.memory(
                                                            base64Decode(
                                                              userReviewImg,
                                                            ),
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
                                                        color:
                                                            AppColors.primary,
                                                        width: 1.2,
                                                      ),
                                                      foregroundColor:
                                                          AppColors.primary,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
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
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    onPressed: () =>
                                                        _openRatingDialog(
                                                          booking,
                                                        ),
                                                  ),
                                                ),
                                              ] else ...[
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          AppColors.primary,
                                                      foregroundColor:
                                                          Colors.white,
                                                      elevation: 0,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 13,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    onPressed: () =>
                                                        _openRatingDialog(
                                                          booking,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ]
                                          // 家长端操作区
                                          else ...[
                                            if (isConfirmed) ...[
                                              _buildDivider(),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors.dark,
                                                        foregroundColor:
                                                            Colors.white,
                                                        elevation: 0,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 12,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                      ),
                                                      icon: const Icon(
                                                        Icons
                                                            .location_on_rounded,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                      label: const Text(
                                                        "Live Tracking",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                TrackingScreen(
                                                                  booking:
                                                                      booking,
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
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.success,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 13,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      _parentConfirmPayoutAndRate(
                                                        booking,
                                                      ),
                                                ),
                                              ),
                                            ] else if (isPending) ...[
                                              _buildDivider(),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(
                                                      color: AppColors.danger,
                                                      width: 1.2,
                                                    ),
                                                    foregroundColor:
                                                        AppColors.danger,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 12,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 16,
                                                    color: AppColors.danger,
                                                  ),
                                                  label: const Text(
                                                    "Cancel Request",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: AppColors.danger,
                                                    ),
                                                  ),
                                                  onPressed: () =>
                                                      _deleteBooking(bookingId),
                                                ),
                                              ),
                                            ] else if (isCompleted) ...[
                                              _buildDivider(),
                                              if (isRated) ...[
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.lightGray,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.border,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Row(
                                                            children: List.generate(
                                                              5,
                                                              (i) => Icon(
                                                                i <
                                                                        userRating
                                                                            .floor()
                                                                    ? Icons
                                                                          .star_rounded
                                                                    : Icons
                                                                          .star_border_rounded,
                                                                size: 16,
                                                                color: AppColors
                                                                    .accent,
                                                              ),
                                                            ),
                                                          ),
                                                          Text(
                                                            "${userRating.toStringAsFixed(1)} Stars",
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 12,
                                                                  color:
                                                                      AppColors
                                                                          .dark,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (userReviewText
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          userReviewText,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color: AppColors
                                                                    .body,
                                                                height: 1.3,
                                                              ),
                                                        ),
                                                      ],
                                                      if (userReviewImg !=
                                                              null &&
                                                          userReviewImg
                                                              .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          child: Image.memory(
                                                            base64Decode(
                                                              userReviewImg,
                                                            ),
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
                                                        color:
                                                            AppColors.primary,
                                                        width: 1.2,
                                                      ),
                                                      foregroundColor:
                                                          AppColors.primary,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
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
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    onPressed: () =>
                                                        _openRatingDialog(
                                                          booking,
                                                        ),
                                                  ),
                                                ),
                                              ] else ...[
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          AppColors.primary,
                                                      foregroundColor:
                                                          Colors.white,
                                                      elevation: 0,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 13,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
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
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    onPressed: () =>
                                                        _openRatingDialog(
                                                          booking,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(
    int index,
    String label,
    int count, {
    bool isHighlight = false,
  }) {
    bool isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isHighlight ? const Color(0xFF16A34A) : AppColors.border),
              width: 1,
            ),
            boxShadow: isSelected ? AppColors.cardShadow : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.dark,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white24
                        : (isHighlight
                              ? const Color(0xFFDCFCE7)
                              : AppColors.lightGray),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "$count",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isHighlight
                                ? const Color(0xFF15803D)
                                : AppColors.gray),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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
          radius: 22,
          backgroundColor: AppColors.lightGray,
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
                  fontWeight: FontWeight.w800,
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
            color: statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, thickness: 0.8, color: AppColors.border),
    );
  }
}
