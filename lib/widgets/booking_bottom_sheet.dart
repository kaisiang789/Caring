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
  TimeOfDay? _selectedTime;
  double _duration = 2.0;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;
  final List<Map<String, dynamic>> _selectedAddons = [];

  Set<DateTime> _disabledDateObjects = {};
  bool _isLoadingDisabledDates = false;

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
  void initState() {
    super.initState();
    _fetchDisabledDates();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDateString(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchDisabledDates() async {
    setState(() => _isLoadingDisabledDates = true);
    try {
      final String nannyUid = widget.nanny['uid'] ?? widget.nanny['id'] ?? '';
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('nannyUid', isEqualTo: nannyUid)
          .get();

      Set<DateTime> occupied = {};
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        String st = data['status'] ?? '';
        if (st == 'Pending' ||
            st == 'Confirmed' ||
            st == 'Completed (Pending Verification)') {
          String? dateStr = data['date'];
          if (dateStr != null && dateStr.isNotEmpty) {
            try {
              List<String> parts = dateStr.split('-');
              if (parts.length == 3) {
                int y = int.parse(parts[0]);
                int m = int.parse(parts[1]);
                int d = int.parse(parts[2]);
                occupied.add(DateTime(y, m, d));
              }
            } catch (e) {
              debugPrint("Error parsing date: $dateStr, error: $e");
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _disabledDateObjects = occupied;
          _isLoadingDisabledDates = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching disabled dates: $e");
      if (mounted) setState(() => _isLoadingDisabledDates = false);
    }
  }

  bool _isDateDisabled(DateTime day) {
    return _disabledDateObjects.any(
      (disabled) =>
          disabled.year == day.year &&
          disabled.month == day.month &&
          disabled.day == day.day,
    );
  }

  bool _isHoliday(DateTime? date) {
    if (date == null) return false;
    String monthDay =
        "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _publicHolidays.contains(monthDay);
  }

  void _confirmBooking() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select both Date and Start Time before payment!",
          ),
        ),
      );
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final String selectedDateStr = _formatDateString(_selectedDate!);
    final String nannyUid = widget.nanny['uid'] ?? widget.nanny['id'] ?? '';

    // validate 1: UI frontend local interception
    if (_isDateDisabled(_selectedDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Date $selectedDateStr is already booked!"),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

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

    int calculatedTotal = (effectiveRate * _duration).toInt() + addonsTotal;

    // payment
    final paymentSuccess = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MockPaymentSheet(amount: calculatedTotal),
    );

    if (paymentSuccess != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment was cancelled."),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      QuerySnapshot checkExistingSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('nannyUid', isEqualTo: nannyUid)
          .where('date', isEqualTo: selectedDateStr)
          .get();

      bool hasConflict = checkExistingSnapshot.docs.any((doc) {
        var dData = doc.data() as Map<String, dynamic>;
        String st = dData['status'] ?? '';
        return st == 'Pending' ||
            st == 'Confirmed' ||
            st == 'Completed (Pending Verification)';
      });

      if (hasConflict) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text(
                    "Booking Conflict!",
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                "Sorry! Nanny '${widget.nanny['name']}' was just booked by another parent on $selectedDateStr moments ago. Your payment has been automatically refunded.",
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                  ),
                  onPressed: () {
                    Navigator.pop(context); // close Alert
                    Navigator.pop(context); // close Booking Sheet
                  },
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      // get parent profile
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

      // Verification successful, data successfully stored in the database!
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
        'time': '${_selectedTime!.format(context)} (${_duration.toInt()} hrs)',
        'duration': _duration.toInt(),
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
            content: Text("Payment successful! Booking request sent to nanny."),
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
      final List<dynamic> rawList = widget.nanny['custom_addons_list'] as List;
      for (var item in rawList) {
        if (item is Map) {
          availableAddons.add(Map<String, dynamic>.from(item));
        }
      }
    }

    bool hasSelectedTimeAndDate =
        _selectedDate != null && _selectedTime != null;

    int addonsTotal = 0;
    for (var addon in _selectedAddons) {
      addonsTotal += int.tryParse(addon['price']?.toString() ?? '0') ?? 0;
    }

    int grandTotal = hasSelectedTimeAndDate
        ? ((currentHourlyRate * _duration).toInt() + addonsTotal)
        : 0;

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Book Nanny",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "RM $currentHourlyRate/hr",
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isSelectedDateHoliday && allowHoliday)
                        const Text(
                          "  Holiday Rate Applied",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _isLoadingDisabledDates
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(
                        Icons.calendar_today,
                        color: _selectedDate == null
                            ? AppColors.gray
                            : AppColors.primary,
                      ),
                title: Row(
                  children: [
                    Text(
                      _selectedDate == null
                          ? "Select Date *"
                          : _formatDateString(_selectedDate!),
                      style: TextStyle(
                        fontWeight: _selectedDate == null
                            ? FontWeight.normal
                            : FontWeight.bold,
                        color: _selectedDate == null
                            ? AppColors.gray
                            : AppColors.dark,
                      ),
                    ),
                    if (isSelectedDateHoliday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Public Holiday",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isLoadingDisabledDates
                    ? null
                    : () async {
                        DateTime initial = DateTime.now();
                        while (_isDateDisabled(initial)) {
                          initial = initial.add(const Duration(days: 1));
                        }
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                          selectableDayPredicate: (DateTime day) {
                            return !_isDateDisabled(day);
                          },
                        );
                        if (picked != null)
                          setState(() => _selectedDate = picked);
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.access_time,
                  color: _selectedTime == null
                      ? AppColors.gray
                      : AppColors.primary,
                ),
                title: Text(
                  _selectedTime == null
                      ? "Select Start Time *"
                      : _selectedTime!.format(context),
                  style: TextStyle(
                    fontWeight: _selectedTime == null
                        ? FontWeight.normal
                        : FontWeight.bold,
                    color: _selectedTime == null
                        ? AppColors.gray
                        : AppColors.dark,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => _selectedTime = picked);
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Duration:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "${_duration.toInt()} Hours",
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _duration,
                min: 1,
                max: 12,
                divisions: 11,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.lightGray,
                onChanged: (val) => setState(() => _duration = val),
              ),
              const SizedBox(height: 12),
              const Text(
                "Extra Add-on Services",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              if (availableAddons.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: const Text(
                    "None (This nanny offers standard care only)",
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.gray,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...availableAddons.map((addon) {
                  final String sName = addon['name'] ?? '';
                  final int sPrice =
                      int.tryParse(addon['price']?.toString() ?? '10') ?? 10;
                  bool isChecked = _selectedAddons.any(
                    (a) => a['name'] == sName,
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? AppColors.primary.withOpacity(0.05)
                          : AppColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isChecked
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      activeColor: AppColors.primary,
                      title: Text(
                        sName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark,
                        ),
                      ),
                      subtitle: Text(
                        "+RM $sPrice.00",
                        style: const TextStyle(
                          fontSize: 12,
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
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: "Add specific requests or notes for nanny...",
                  filled: true,
                  fillColor: AppColors.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: hasSelectedTimeAndDate
                      ? AppColors.primary.withOpacity(0.08)
                      : AppColors.lightGray,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasSelectedTimeAndDate
                        ? AppColors.primary.withOpacity(0.3)
                        : Colors.grey[200]!,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Estimated Total:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    Text(
                      hasSelectedTimeAndDate
                          ? "RM $grandTotal.00"
                          : "Select date & time first",
                      style: TextStyle(
                        fontSize: hasSelectedTimeAndDate ? 18 : 13,
                        fontWeight: FontWeight.w900,
                        color: hasSelectedTimeAndDate
                            ? AppColors.primary
                            : AppColors.gray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasSelectedTimeAndDate
                      ? AppColors.dark
                      : Colors.grey[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _confirmBooking,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        hasSelectedTimeAndDate
                            ? "Pay RM $grandTotal.00 & Book"
                            : "Select Date & Time to Continue",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
