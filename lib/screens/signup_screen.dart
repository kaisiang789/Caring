import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import '../core/theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedRole = 'Parent';
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _obscurePassword = true;

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

  final List<String> _selectedAddons = [];

  Future<void> _detectSignupLocation() async {
    setState(() => _isGettingLocation = true);
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        _locationController.text = "Skudai, Johor Bahru";
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
          _locationController.text = address.replaceAll(RegExp(r'^, '), '');
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("GPS Location Detected!"),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() {
          _locationController.text = "Johor Bahru, Johor";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationController.text = "Skudai, Johor";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Location fallback used: Skudai"),
            backgroundColor: AppColors.primary,
          ),
        );
      }
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

  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      final String uid = userCredential.user!.uid;

      Map<String, dynamic> userData = {
        'uid': uid,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'image':
            'https://api.dicebear.com/7.x/avataaars/png?seed=${_nameController.text.trim()}',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedRole == 'Nanny') {
        List<Map<String, dynamic>> customAddonsList = [];
        List<String> automaticTags = [];

        for (var name in _selectedAddons) {
          customAddonsList.add({"name": name, "price": 10});
          String targetTag = _mapServiceToTag(name);
          if (!automaticTags.contains(targetTag)) {
            automaticTags.add(targetTag);
          }
        }

        userData.addAll({
          'hourly_rate': double.tryParse(_rateController.text.trim()) ?? 25.0,
          'location': _locationController.text.trim(),
          'rating': 5.0,
          'isOnline': true,
          'custom_addons_list': customAddonsList,
          'tags': automaticTags,
          'allow_holiday_charge': true,
          'holiday_charge_rate': 15.0,
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Welcome onboard! Account created successfully."),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Signup Error: $e"),
            backgroundColor: AppColors.danger,
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.dark,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top modern flat streamlined Header
                const Text(
                  "Join NannyApp",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Create an account to experience smart care matchmaking.",
                  style: TextStyle(fontSize: 14, color: AppColors.gray),
                ),
                const SizedBox(height: 32),

                // Highlight 1: Say goodbye to traditional old-fashioned selection boxes, upgrade to high-quality realistic 3D tile cards (Role Dynamic Tile Cards)
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleCard(
                        "Parent",
                        Icons.family_restroom_rounded,
                        _selectedRole == 'Parent',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRoleCard(
                        "Nanny",
                        Icons.medical_information_rounded,
                        _selectedRole == 'Nanny',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Highlight 2: Abandon old-fashioned bordered large form boxes, use high-transparency quality borderless soft-seat input boxes
                _buildModernTextField(
                  controller: _nameController,
                  label: "Full Name",
                  icon: Icons.person_outline_rounded,
                ),
                _buildModernTextField(
                  controller: _phoneController,
                  label: "Phone Number",
                  icon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                ),
                _buildModernTextField(
                  controller: _emailController,
                  label: "Email Address",
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildModernTextField(
                  controller: _passwordController,
                  label: "Password",
                  icon: Icons.lock_open_rounded,
                  obscureText: _obscurePassword,
                  isPassword: true,
                ),

                // If Nanny side, high-realism streamlined card seamlessly expands
                if (_selectedRole == 'Nanny') ...[
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      "Nanny Professional Profile",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                  _buildModernTextField(
                    controller: _rateController,
                    label: "Expected Hourly Rate (RM/hr)",
                    icon: Icons.monetization_on_outlined,
                    keyboardType: TextInputType.number,
                  ),

                  // Highlight 3: Location input box contains high-class radar scan one-tap positioning button
                  _buildModernTextField(
                    controller: _locationController,
                    label: "Service Location / Area",
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
                              size: 20,
                            ),
                            onPressed: _detectSignupLocation,
                            tooltip: "Auto Detect Location",
                          ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "Select Services You Can Provide",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Highlight 4: Value-added service checkbox panel completely refactored, abandon traditional ugly long tables, change to high-realism rounded quality cards
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _presetServiceOptions.length,
                    itemBuilder: (context, idx) {
                      final service = _presetServiceOptions[idx];
                      bool isChecked = _selectedAddons.contains(service);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? AppColors.primary.withOpacity(0.05)
                              : AppColors.lightGray,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isChecked
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            service,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isChecked
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: AppColors.dark,
                            ),
                          ),
                          activeColor: AppColors.primary,
                          checkboxShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          value: isChecked,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedAddons.add(service);
                              } else {
                                _selectedAddons.remove(service);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // Highlight 5: Streamlined floating gradient effect Sign Up large button
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Encapsulated quality role card tile widget
  Widget _buildRoleCard(String role, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : AppColors.lightGray,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? AppColors.primary : AppColors.gray,
            ),
            const SizedBox(height: 8),
            Text(
              role,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Encapsulated modern high-quality borderless input widget
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.dark,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.gray, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.gray, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.gray,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : suffixIcon,
          filled: true,
          fillColor: AppColors.lightGray,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
        ),
        validator: (val) {
          if (val == null || val.isEmpty) return "Field required";
          if (label.contains("Email") && !val.contains('@'))
            return "Invalid Email address";
          if (label.contains("Password") && val.length < 6)
            return "Password too short";
          return null;
        },
      ),
    );
  }
}
