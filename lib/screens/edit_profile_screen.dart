import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import '../core/theme.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final bool isNannyMode;
  const EditProfileScreen({
    super.key,
    required this.userData,
    required this.isNannyMode,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _bioController;
  late TextEditingController _rateController;

  bool _allowHolidayCharge = true;
  late TextEditingController _holidayRateController;

  final List<String> _presetServiceOptions = [
    "Cooking Meals",
    "Housekeeping",
    "Homework Help",
    "Pet Care",
    "Special Needs Care",
    "Pick-up & Drop-off",
    "Baby Bathing & Grooming",
    "Overnight Care",
    "Bilingual Teaching",
    "Emergency/Short-notice Care",
  ];

  final Map<String, TextEditingController> _priceControllers = {};
  final List<String> _activeServiceNames = [];
  List<String> _selectedTags = [];

  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['name']);
    _phoneController = TextEditingController(
      text: widget.userData['phone'] ?? "",
    );
    _emailController = TextEditingController(
      text: widget.userData['email'] ?? "",
    );
    _addressController = TextEditingController(
      text:
          widget.userData['address'] ??
          widget.userData['location'] ??
          "Skudai, Johor",
    );
    _bioController = TextEditingController(
      text: widget.userData['bio'] ?? widget.userData['about'] ?? "",
    );
    _rateController = TextEditingController(
      text: (widget.userData['hourly_rate'] ?? 25).toString(),
    );

    _allowHolidayCharge = widget.userData['allow_holiday_charge'] ?? true;
    _holidayRateController = TextEditingController(
      text: (widget.userData['holiday_charge_rate'] ?? 15).toString(),
    );

    for (var option in _presetServiceOptions) {
      _priceControllers[option] = TextEditingController(text: "10");
    }

    if (widget.userData['custom_addons_list'] != null) {
      final List<dynamic> savedList =
          widget.userData['custom_addons_list'] as List;
      for (var item in savedList) {
        if (item is Map) {
          String sName = item['name'] ?? '';
          String sPrice = (item['price'] ?? 10).toString();
          if (_presetServiceOptions.contains(sName)) {
            _activeServiceNames.add(sName);
            _priceControllers[sName]?.text = sPrice;
          }
        }
      }
    }

    if (widget.userData['tags'] != null) {
      _selectedTags = List<String>.from(widget.userData['tags']);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        _addressController.text = "Skudai, Johor Bahru";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Web Environment Detected: Location set to Skudai! 🌐",
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
      setState(() => _isGettingLocation = false);
      return;
    }
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Location permissions are denied');
      }
      if (permission == LocationPermission.deniedForever)
        throw Exception('Location permissions are permanently denied.');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address =
            "${place.subLocality ?? place.street}, ${place.locality ?? place.administrativeArea}";
        setState(() {
          _addressController.text = address.replaceAll(RegExp(r'^, '), '');
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("GPS Location Detected!"),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  String _mapServiceToTag(String addonName) {
    String cleanTagName = addonName.split(' (')[0].trim();
    if (cleanTagName == "Cooking Meals") return "Cooking";
    if (cleanTagName == "Housekeeping") return "Housekeeping";
    if (cleanTagName == "Homework Help") return "Homework Help";
    if (cleanTagName == "Pet Care") return "Pet Friendly";
    if (cleanTagName == "Special Needs Care") return "Special Needs";
    if (cleanTagName == "Pick-up & Drop-off") return "Has Car";
    if (cleanTagName == "Baby Bathing & Grooming") return "Baby Bathing";
    if (cleanTagName == "Overnight Care") return "Overnight Care";
    if (cleanTagName == "Bilingual Teaching") return "Bilingual Teaching";
    if (cleanTagName == "Emergency/Short-notice Care") return "Emergency Care";
    return cleanTagName;
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      List<Map<String, dynamic>> finalAddonsToUpload = [];
      List<String> synchronizedTags = List.from(_selectedTags);

      for (var option in _presetServiceOptions) {
        String oldMappedTag = _mapServiceToTag(option);
        synchronizedTags.remove(oldMappedTag);
      }

      for (var name in _activeServiceNames) {
        int priceVal =
            int.tryParse(_priceControllers[name]?.text.trim() ?? '10') ?? 10;
        finalAddonsToUpload.add({"name": name, "price": priceVal});

        String mappedTag = _mapServiceToTag(name);
        if (!synchronizedTags.contains(mappedTag)) {
          synchronizedTags.add(mappedTag);
        }
      }

      Navigator.pop(context, {
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "location": _addressController.text.trim(),
        "address": _addressController.text.trim(),
        "about": _bioController.text.trim(),
        "bio": _bioController.text.trim(),
        "hourly_rate": int.tryParse(_rateController.text) ?? 25,
        "allow_holiday_charge": _allowHolidayCharge,
        "holiday_charge_rate": int.tryParse(_holidayRateController.text) ?? 15,
        "custom_addons_list": finalAddonsToUpload,
        "tags": synchronizedTags,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Account Settings",
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.dark,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _saveProfile,
              child: const Text(
                "Save",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Basic Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),

              _buildModernInput(
                controller: _nameController,
                label: "Full Name",
                icon: Icons.person_outline_rounded,
              ),
              _buildModernInput(
                controller: _phoneController,
                label: "Phone Number",
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone,
              ),
              _buildModernInput(
                controller: _emailController,
                label: "Email Address",
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildModernInput(
                controller: _addressController,
                label: "Location",
                icon: Icons.map_outlined,
                suffixIcon: _isGettingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(14.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.gps_fixed_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        onPressed: _getCurrentLocation,
                        tooltip: "Get Location",
                      ),
              ),

              if (widget.isNannyMode) ...[
                const SizedBox(height: 16),
                const Text(
                  "Rates & Surcharges",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),

                _buildModernInput(
                  controller: _rateController,
                  label: "Base Hourly Rate (RM)",
                  icon: Icons.monetization_on_outlined,
                  keyboardType: TextInputType.number,
                ),

                // Highlight design 1: High-quality modern card Switch, replacing the original crude thin box
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _allowHolidayCharge
                        ? AppColors.primary.withOpacity(0.02)
                        : AppColors.lightGray,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _allowHolidayCharge
                          ? AppColors.primary.withOpacity(0.3)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.star_outline_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              SizedBox(width: 12),
                              Text(
                                "Holiday Extra Surcharge",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.dark,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _allowHolidayCharge,
                            activeColor: AppColors.primary,
                            inactiveTrackColor: Colors.grey[300],
                            onChanged: (val) =>
                                setState(() => _allowHolidayCharge = val),
                          ),
                        ],
                      ),
                      if (_allowHolidayCharge) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _holidayRateController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            labelText: "Holiday Surcharge Rate (RM/hr extra)",
                            labelStyle: TextStyle(
                              fontSize: 13,
                              color: AppColors.gray,
                            ),
                            prefixIcon: Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Text(
                  "Custom Add-on Services",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Tags automatically generated upon selection.",
                  style: TextStyle(fontSize: 12, color: AppColors.gray),
                ),
                const SizedBox(height: 16),

                // Highlight design 2: Completely get rid of the old-fashioned checkbox table, upgrade to 2026 cutting-edge multi-dimensional rounded flat card tiles
                ..._presetServiceOptions.map((serviceName) {
                  bool isChecked = _activeServiceNames.contains(serviceName);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isChecked
                          ? AppColors.primary.withOpacity(0.04)
                          : AppColors.lightGray,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isChecked
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Transform.scale(
                          scale: 0.9,
                          child: Checkbox(
                            value: isChecked,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: (bool? val) {
                              setState(() {
                                if (val == true) {
                                  _activeServiceNames.add(serviceName);
                                } else {
                                  _activeServiceNames.remove(serviceName);
                                }
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: Text(
                            serviceName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isChecked
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        // Highlight design 3: Right-side surcharge tile is elegantly disabled when inactive, and presents an independent soft white rounded box when activated
                        SizedBox(
                          width: 90,
                          height: 38,
                          child: TextFormField(
                            controller: _priceControllers[serviceName],
                            enabled: isChecked,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isChecked
                                  ? AppColors.primary
                                  : AppColors.gray,
                            ),
                            decoration: InputDecoration(
                              prefixText: "RM ",
                              prefixStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: isChecked
                                  ? Colors.white
                                  : Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),
                const Text(
                  "Bio / Experience Profile",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                _buildModernInput(
                  controller: _bioController,
                  label: "Describe your professional child care experience...",
                  icon: Icons.history_edu_outlined,
                  maxLines: 4,
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Encapsulated advanced borderless streamlined input layout widget
  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.dark,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.gray, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.gray, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppColors.lightGray,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "Field cannot be empty";
          return null;
        },
      ),
    );
  }
}
