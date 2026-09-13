import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/theme.dart';

class KycDialogHelper {
  // 1. 引导提示弹窗（Verify Now / Later）
  static void showKycPromptDialog(
    BuildContext context, {
    required VoidCallback onVerifyNow,
    VoidCallback? onLater,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDE68A), width: 2),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFFD97706),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Caregiver KYC Required",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "To ensure platform child safety and activate Online status for receiving bookings, complete your quick Identity Verification (KYC).",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.gray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (onLater != null) onLater();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 1.2,
                      ),
                      foregroundColor: AppColors.gray,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Later",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onVerifyNow();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Verify Now",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. 模拟真实 KYC 流程弹窗
  static Future<bool?> showSimulatedKycSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SimulatedKycSheetContent(),
    );
  }
}

class _SimulatedKycSheetContent extends StatefulWidget {
  const _SimulatedKycSheetContent();

  @override
  State<_SimulatedKycSheetContent> createState() =>
      _SimulatedKycSheetContentState();
}

class _SimulatedKycSheetContentState extends State<_SimulatedKycSheetContent>
    with SingleTickerProviderStateMixin {
  final _idController = TextEditingController(text: "020815-01-5234");

  // 阶段状态: 0: 填写证件阶段, 1: 扫描人脸阶段, 2: 认证成功阶段
  int _currentStep = 0;
  String _scanStatusText = "Positioning face in center...";
  double _scanProgress = 0.0;

  late AnimationController _scanAnimController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    // 激光扫描条上下往复动效
    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _scanAnimController.dispose();
    super.dispose();
  }

  // 从证件阶段进入人脸扫描阶段
  void _startFaceScanning() async {
    setState(() {
      _currentStep = 1;
      _scanStatusText = "Detecting facial biometrics...";
      _scanProgress = 0.2;
    });

    _scanAnimController.repeat(reverse: true);

    // 模拟活体检测多阶段推进
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _scanStatusText = "Analyzing facial mesh & liveness...";
      _scanProgress = 0.55;
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _scanStatusText = "Verifying with National MyKad database...";
      _scanProgress = 0.88;
    });

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // 审核通过，写入云端
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isKycVerified': true,
        'isOnline': true, // KYC 认证完成自动设为在线
        'kycVerifiedAt': FieldValue.serverTimestamp(),
      });
    }

    _scanAnimController.stop();

    setState(() {
      _currentStep = 2; // 成功界面
      _scanProgress = 1.0;
      _scanStatusText = "Identity Verification Completed!";
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentStep == 0
            ? _buildDocumentFormStep()
            : _buildFaceScanStep(),
      ),
    );
  }

  // 阶段 1：证件信息确认
  Widget _buildDocumentFormStep() {
    return SingleChildScrollView(
      key: const ValueKey("DocumentFormStep"),
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
              const Row(
                children: [
                  Icon(
                    Icons.shield_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Identity (e-KYC) Step 1/2",
                    style: TextStyle(
                      fontSize: 18,
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
            "Verify your MyKad identity before proceeding to live facial scan.",
            style: TextStyle(fontSize: 12, color: AppColors.gray),
          ),
          const SizedBox(height: 20),

          const Text(
            "MyKad / ID Number",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _idController,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.dark,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.lightGray,
              prefixIcon: const Icon(
                Icons.badge_outlined,
                color: AppColors.gray,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            "Document Proofs (Simulated)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.credit_card_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      SizedBox(height: 6),
                      Text(
                        "MyKad Front",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.dark,
                        ),
                      ),
                      Text(
                        "Verified ✓",
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.flip_to_back_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      SizedBox(height: 6),
                      Text(
                        "MyKad Back",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.dark,
                        ),
                      ),
                      Text(
                        "Verified ✓",
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _startFaceScanning,
            icon: const Icon(
              Icons.face_retouching_natural_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              "Continue to Face Scan",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // 阶段 2：人脸识别与扫描微动效
  Widget _buildFaceScanStep() {
    bool isSuccess = _currentStep == 2;

    return Column(
      key: const ValueKey("FaceScanStep"),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
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
        Text(
          isSuccess ? "Verification Passed!" : "Biometric Liveness Scan",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isSuccess
              ? "Your identity is verified. You can now go Online."
              : "Please stay still and look straight into the frame.",
          style: const TextStyle(fontSize: 12, color: AppColors.gray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // 人脸扫描框架本体
        Center(
          child: SizedBox(
            width: 200,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. 发光外轮廓取景框
                Container(
                  width: 190,
                  height: 240,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: isSuccess
                          ? AppColors.success
                          : AppColors.primary.withOpacity(0.6),
                      width: 2.5,
                    ),
                  ),
                ),

                // 2. 模拟人脸轮廓图
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.face_rounded,
                  size: 110,
                  color: isSuccess
                      ? AppColors.success
                      : AppColors.primary.withOpacity(0.35),
                ),

                // 3. 上下往复运动的绿色激光扫描线
                if (!isSuccess)
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 20 + (_scanLineAnimation.value * 200),
                        child: Container(
                          width: 160,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF14B8A6),
                                AppColors.primary,
                                Color(0xFF14B8A6),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF14B8A6).withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // 4. 四角定位准星线装饰
                ..._buildCornerMarkers(isSuccess),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 状态文字与动态进度条
        Text(
          _scanStatusText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSuccess ? AppColors.success : AppColors.dark,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _scanProgress,
              minHeight: 6,
              backgroundColor: AppColors.lightGray,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSuccess ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _buildCornerMarkers(bool isSuccess) {
    Color markerColor = isSuccess ? AppColors.success : AppColors.primary;
    return [
      Positioned(
        top: 10,
        left: 10,
        child: _cornerWidget(markerColor, top: true, left: true),
      ),
      Positioned(
        top: 10,
        right: 10,
        child: _cornerWidget(markerColor, top: true, left: false),
      ),
      Positioned(
        bottom: 10,
        left: 10,
        child: _cornerWidget(markerColor, top: false, left: true),
      ),
      Positioned(
        bottom: 10,
        right: 10,
        child: _cornerWidget(markerColor, top: false, left: false),
      ),
    ];
  }

  Widget _cornerWidget(Color color, {required bool top, required bool left}) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: top ? BorderSide(color: color, width: 3) : BorderSide.none,
          bottom: !top ? BorderSide(color: color, width: 3) : BorderSide.none,
          left: left ? BorderSide(color: color, width: 3) : BorderSide.none,
          right: !left ? BorderSide(color: color, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}
