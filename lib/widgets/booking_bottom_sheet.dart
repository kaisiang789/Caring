import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';
import 'mock_payment_sheet.dart';

class BookingBottomSheet extends StatefulWidget {
  final Map<String, dynamic> nanny;
  const BookingBottomSheet({super.key, required this.nanny});

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  DateTime? _selectedDate;
  int? _startHour; // 24小时制整点，例如 15 代表 3:00 PM
  int? _endHour; // 例如 18 代表 6:00 PM
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  final List<Map<String, dynamic>> _selectedAddons = [];

  bool _isLoadingSlots = false;
  // 锁定时段区间列表: 每项包含 [startHour, endHourWithBuffer]
  List<List<int>> _lockedIntervals = [];

  final List<String> _publicHolidays = [
    "01-01",
    "02-01",
    "02-17",
    "02-18",
    "03-21",
    "03-22",
    "03-23",
    "05-01",
    "05-27",
    "05-31",
    "06-01",
    "06-17",
    "07-21",
    "08-25",
    "08-31",
    "09-16",
    "11-08",
    "12-25",
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDateString(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  bool _isHoliday(DateTime? date) {
    if (date == null) return false;
    String monthDay =
        "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _publicHolidays.contains(monthDay);
  }

  // 获取保姆在选中日期的被占时段
  Future<void> _fetchOccupiedSlotsForDate(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _startHour = null;
      _endHour = null;
      _lockedIntervals = [];
    });

    try {
      final String nannyUid = widget.nanny['uid'] ?? widget.nanny['id'] ?? '';
      final String dateStr = _formatDateString(date);

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('nannyUid', isEqualTo: nannyUid)
          .where('date', isEqualTo: dateStr)
          .get();

      List<List<int>> occupied = [];

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String st = (data['status'] ?? '').toString().trim();

        if (st == 'Pending' ||
            st == 'Confirmed' ||
            st == 'Completed (Pending Verification)') {
          int startH = data['startHour'] ?? -1;
          int dur = int.tryParse(data['duration']?.toString() ?? '2') ?? 2;

          if (startH == -1 && data['time'] != null) {
            startH = _parseHourFromString(data['time'].toString());
          }

          if (startH != -1) {
            // 保姆服务时间 + 1小时休息缓冲
            int endHWithBuffer = startH + dur + 1;
            occupied.add([startH, endHWithBuffer]);
          }
        }
      }

      if (mounted) {
        setState(() {
          _lockedIntervals = occupied;
          _isLoadingSlots = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching nanny schedule: $e");
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

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

  // 某个时间点是否处于锁定区间中
  bool _isHourLocked(int hour) {
    for (var interval in _lockedIntervals) {
      if (hour >= interval[0] && hour < interval[1]) {
        return true;
      }
    }
    return false;
  }

  // 判断选择的 [startHour, endHour] 是否与已有占用区间发生碰撞
  bool _isRangeConflicting(int start, int end) {
    for (var interval in _lockedIntervals) {
      int lockedStart = interval[0];
      int lockedEndWithBuffer = interval[1];
      if (start < lockedEndWithBuffer && end > lockedStart) {
        return true;
      }
    }
    return false;
  }

  String _formatHourDisplay(int hour) {
    int displayH = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    String period = hour >= 12 ? "PM" : "AM";
    return "$displayH:00 $period";
  }

  // 处理时间点击：第1次点击选开始，第2次点击选结束
  void _onTimeTapped(int hour) {
    if (_startHour == null) {
      setState(() {
        _startHour = hour;
        _endHour = null;
      });
    } else if (_endHour == null) {
      if (hour <= _startHour!) {
        // 如果点击的时间比开始时间早或一样，重设开始时间
        setState(() {
          _startHour = hour;
          _endHour = null;
        });
      } else {
        // 检查这个区间是否包含了被锁定的时间
        if (_isRangeConflicting(_startHour!, hour)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Selected time range overlaps with another booking or 1h rest break!",
              ),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
        setState(() {
          _endHour = hour;
        });
      }
    } else {
      // 两个都选过了，重新选起始时间
      setState(() {
        _startHour = hour;
        _endHour = null;
      });
    }
  }

  void _confirmBooking() async {
    if (_selectedDate == null || _startHour == null || _endHour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select Date, Start Time and End Time!"),
        ),
      );
      return;
    }

    int duration = _endHour! - _startHour!;
    if (duration <= 0) return;

    if (_isRangeConflicting(_startHour!, _endHour!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Selected time conflicts with an existing booking (including 1-hr rest)!",
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final String selectedDateStr = _formatDateString(_selectedDate!);
    final String nannyUid = widget.nanny['uid'] ?? widget.nanny['id'] ?? '';

    int baseRate =
        int.tryParse(widget.nanny['hourly_rate']?.toString() ?? '25') ?? 25;
    bool allowHoliday = widget.nanny['allow_holiday_charge'] ?? true;
    int holidayExtra = allowHoliday && _isHoliday(_selectedDate)
        ? (int.tryParse(
                widget.nanny['holiday_charge_rate']?.toString() ?? '15',
              ) ??
              15)
        : 0;
    int effectiveRate = baseRate + holidayExtra;
    int addonsTotal = 0;
    for (var addon in _selectedAddons) {
      addonsTotal += int.tryParse(addon['price']?.toString() ?? '0') ?? 0;
    }
    int calculatedTotal = (effectiveRate * duration) + addonsTotal;

    final paymentSuccess = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MockPaymentSheet(amount: calculatedTotal),
    );

    if (paymentSuccess != true) return;

    setState(() => _isSubmitting = true);
    try {
      DocumentSnapshot parentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      String parentRealName = "Client Parent";
      String parentRealImage =
          "https://api.dicebear.com/7.x/avataaars/png?seed=Parent";
      if (parentDoc.exists && parentDoc.data() != null) {
        var parentData = parentDoc.data() as Map<String, dynamic>;
        parentRealName = parentData['name'] ?? "Parent User";
        parentRealImage =
            parentData['image'] ??
            parentData['avatar'] ??
            "https://api.dicebear.com/7.x/avataaars/png?seed=$parentRealName";
      }

      String timeString =
          "${_formatHourDisplay(_startHour!)} - ${_formatHourDisplay(_endHour!)} ($duration hrs)";

      await FirebaseFirestore.instance.collection('bookings').add({
        'parentUid': currentUid,
        'parentName': parentRealName,
        'parentImage': parentRealImage,
        'nannyUid': nannyUid,
        'nannyName': widget.nanny['name'] ?? 'Nanny',
        'nannyImage':
            widget.nanny['image'] ??
            'https://api.dicebear.com/7.x/avataaars/png?seed=Nanny',
        'name': widget.nanny['name'],
        'image': widget.nanny['image'],
        'date': selectedDateStr,
        'time': timeString,
        'startHour': _startHour,
        'endHour': _endHour,
        'duration': duration,
        'totalPrice': calculatedTotal,
        'isHoliday': _isHoliday(_selectedDate),
        'selectedAddons': _selectedAddons,
        'notes': _notesController.text.trim(),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Booking request sent! Waiting for nanny confirmation.",
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Booking Failed: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int baseRate =
        int.tryParse(widget.nanny['hourly_rate']?.toString() ?? '25') ?? 25;
    bool allowHoliday = widget.nanny['allow_holiday_charge'] ?? true;
    bool isSelectedDateHoliday = _isHoliday(_selectedDate);
    int holidaySurcharge = (allowHoliday && isSelectedDateHoliday)
        ? (int.tryParse(
                widget.nanny['holiday_charge_rate']?.toString() ?? '15',
              ) ??
              15)
        : 0;
    int currentHourlyRate = baseRate + holidaySurcharge;

    List<Map<String, dynamic>> availableAddons = [];
    if (widget.nanny['custom_addons_list'] != null) {
      for (var item in (widget.nanny['custom_addons_list'] as List)) {
        if (item is Map) availableAddons.add(Map<String, dynamic>.from(item));
      }
    }

    int duration = (_startHour != null && _endHour != null)
        ? (_endHour! - _startHour!)
        : 0;
    bool hasCompletedRange =
        _selectedDate != null &&
        _startHour != null &&
        _endHour != null &&
        duration > 0;

    int addonsTotal = 0;
    for (var a in _selectedAddons) {
      addonsTotal += int.tryParse(a['price']?.toString() ?? '0') ?? 0;
    }
    int grandTotal = hasCompletedRange
        ? ((currentHourlyRate * duration) + addonsTotal)
        : 0;

    // 支持早 8:00 到 晚 21:00 可选
    final List<int> dailyHours = List.generate(14, (index) => 8 + index);

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
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
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Book Caregiver",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.dark,
                    ),
                  ),
                  Text(
                    "RM $currentHourlyRate/hr",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. 日期选择
              Container(
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  title: Text(
                    _selectedDate == null
                        ? "Select Service Date *"
                        : _formatDateString(_selectedDate!),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedDate == null
                          ? AppColors.gray
                          : AppColors.dark,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: _selectedDate != null
                      ? Text(
                          _lockedIntervals.isEmpty
                              ? "All hours currently available"
                              : "${_lockedIntervals.length} slot(s) reserved/busy (with 1h rest)",
                          style: TextStyle(
                            fontSize: 11,
                            color: _lockedIntervals.isEmpty
                                ? AppColors.success
                                : AppColors.gray,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.gray,
                  ),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                      await _fetchOccupiedSlotsForDate(picked);
                    }
                  },
                ),
              ),
              const SizedBox(height: 18),

              // 2. 时间范围提示栏（从几点到几点）
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: hasCompletedRange
                      ? AppColors.primaryLight.withOpacity(0.5)
                      : AppColors.lightGray,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasCompletedRange
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Selected Time Interval",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.gray,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _startHour == null
                              ? "Tap start time below"
                              : (_endHour == null
                                    ? "From ${_formatHourDisplay(_startHour!)} (Pick End Time)"
                                    : "${_formatHourDisplay(_startHour!)}  ➔  ${_formatHourDisplay(_endHour!)}"),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: hasCompletedRange
                                ? AppColors.primary
                                : AppColors.dark,
                          ),
                        ),
                      ],
                    ),
                    if (duration > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "$duration hrs",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. 时间点选药丸流
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Pick Hours (Start & End):",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.dark,
                    ),
                  ),
                  if (_lockedIntervals.isNotEmpty)
                    const Text(
                      "Includes 1h caregiver rest",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (_selectedDate == null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    "Pick a date first to view available hours.",
                    style: TextStyle(color: AppColors.gray, fontSize: 12),
                  ),
                )
              else if (_isLoadingSlots)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dailyHours.map((hour) {
                    bool isLocked = _isHourLocked(hour);
                    bool isStart = _startHour == hour;
                    bool isEnd = _endHour == hour;
                    bool isInRange =
                        _startHour != null &&
                        _endHour != null &&
                        hour > _startHour! &&
                        hour < _endHour!;

                    Color pillBg = Colors.white;
                    Color textColor = AppColors.dark;
                    Border borderStyle = Border.all(color: AppColors.border);

                    if (isLocked) {
                      pillBg = const Color(0xFFF1F5F9);
                      textColor = const Color(0xFFCBD5E1);
                      borderStyle = Border.all(color: Colors.transparent);
                    } else if (isStart || isEnd) {
                      pillBg = AppColors.primary;
                      textColor = Colors.white;
                      borderStyle = Border.all(color: AppColors.primary);
                    } else if (isInRange) {
                      pillBg = AppColors.primaryLight;
                      textColor = AppColors.primary;
                      borderStyle = Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      );
                    }

                    return GestureDetector(
                      onTap: isLocked
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  duration: Duration(milliseconds: 1200),
                                  content: Text(
                                    "This slot is occupied by another booking or nanny's 1-hour rest.",
                                  ),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          : () => _onTimeTapped(hour),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: pillBg,
                          borderRadius: BorderRadius.circular(12),
                          border: borderStyle,
                        ),
                        child: Text(
                          _formatHourDisplay(hour),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: (isStart || isEnd)
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: textColor,
                            decoration: isLocked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 18),

              // 4. 加价附加服务
              if (availableAddons.isNotEmpty) ...[
                const Text(
                  "Add-on Services",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 8),
                ...availableAddons.map((addon) {
                  final String sName = addon['name'] ?? '';
                  final int sPrice =
                      int.tryParse(addon['price']?.toString() ?? '10') ?? 10;
                  bool isChecked = _selectedAddons.any(
                    (a) => a['name'] == sName,
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? AppColors.primaryLight
                          : AppColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      activeColor: AppColors.primary,
                      title: Text(
                        sName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        "+RM $sPrice.00",
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: isChecked,
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedAddons.add(addon);
                          } else {
                            _selectedAddons.removeWhere(
                              (a) => a['name'] == sName,
                            );
                          }
                        });
                      },
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Add specific instructions for nanny...",
                  filled: true,
                  fillColor: AppColors.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Estimated Total:",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                  Text(
                    hasCompletedRange
                        ? "RM $grandTotal.00"
                        : "Pick start & end time",
                    style: TextStyle(
                      fontSize: hasCompletedRange ? 20 : 13,
                      fontWeight: FontWeight.w900,
                      color: hasCompletedRange
                          ? AppColors.primary
                          : AppColors.gray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasCompletedRange
                      ? AppColors.primary
                      : AppColors.muted,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSubmitting || !hasCompletedRange
                    ? null
                    : _confirmBooking,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        hasCompletedRange
                            ? "Pay RM $grandTotal.00 & Book (${_formatHourDisplay(_startHour!)} - ${_formatHourDisplay(_endHour!)})"
                            : "Select Date, Start & End Time",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
