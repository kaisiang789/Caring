import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';

class CareTimelineDialog extends StatefulWidget {
  final String bookingId;
  const CareTimelineDialog({super.key, required this.bookingId});

  @override
  State<CareTimelineDialog> createState() => _CareTimelineDialogState();
}

class _CareTimelineDialogState extends State<CareTimelineDialog> {
  final TextEditingController _noteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _base64Image;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;

  String _selectedActivity = "🍼 Fed Milk/Meal";
  final List<String> _quickActivities = [
    "🍼 Fed Milk/Meal",
    "😴 Nap Time",
    "🎨 Interactive Play",
    "🚼 Diaper Changed",
    "🛡️ All is Calm & Safe",
    "🍎 Snack & Water",
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (file != null) {
        final Uint8List bytes = await file.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _base64Image = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _submitCareUpdate() async {
    setState(() => _isSubmitting = true);
    try {
      final now = DateTime.now();
      String timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      Map<String, dynamic> updateItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'activity': _selectedActivity,
        'notes': _noteController.text.trim(),
        'time': timeStr,
        'image': _base64Image,
        'timestamp': Timestamp.now(),
      };

      // 追加到该订单的看护时间轴流中
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
            'careUpdates': FieldValue.arrayUnion([updateItem]),
            'lastCareUpdateAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Care status & photo synced to parent's feed!"),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync failed: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
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
                        Icons.camera_enhance_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Care Milestone Check-in",
                        style: TextStyle(
                          fontSize: 17,
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
              const SizedBox(height: 6),
              const Text(
                "Quick update to keep parents informed of the child's well-being.",
                style: TextStyle(fontSize: 12, color: AppColors.gray),
              ),
              const SizedBox(height: 16),

              const Text(
                "Care Activity",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickActivities.map((act) {
                  bool isSelected = _selectedActivity == act;
                  return ChoiceChip(
                    label: Text(
                      act,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.dark,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.lightGray,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide.none,
                    onSelected: (val) {
                      if (val) setState(() => _selectedActivity = act);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              const Text(
                "Snapshot / Photo Proof (Optional)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 130,
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _imageBytes != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _imageBytes = null;
                                  _base64Image = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_camera_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Take Quick Photo Proof",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.dark,
                              ),
                            ),
                            Text(
                              "Back of baby, toys, meal plate or safe play area",
                              style: TextStyle(
                                color: AppColors.gray,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _noteController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      "Add remarks (e.g. Baby drank 120ml milk, currently sleeping peacefully)...",
                  filled: true,
                  fillColor: AppColors.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitCareUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Post Update to Parent",
                        style: TextStyle(
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
