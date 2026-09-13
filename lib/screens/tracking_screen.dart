import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme.dart';

class TrackingScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const TrackingScreen({super.key, required this.booking});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  final LatLng _nannyLocation = const LatLng(1.5346, 103.6808); // Skudai 坐标
  Set<Marker> _markers = {};
  bool _isLoadingMarker = true;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  Future<void> _loadCustomMarker() async {
    try {
      final String imageUrl =
          widget.booking['image'] ??
          'https://api.dicebear.com/7.x/avataaars/png?seed=default';
      final ImageStream stream = NetworkImage(
        imageUrl,
      ).resolve(ImageConfiguration.empty);
      final Completer<ui.Image> completer = Completer<ui.Image>();
      ImageStreamListener? listener;
      listener = ImageStreamListener((ImageInfo frame, bool sync) {
        completer.complete(frame.image);
        stream.removeListener(listener!);
      }, onError: (e, stack) => completer.completeError(e));
      stream.addListener(listener);
      final ui.Image rawImage = await completer.future;

      const double size = 140.0;
      const double border = 10.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..isAntiAlias = true;

      // 投影光环
      canvas.drawCircle(
        const Offset(size / 2, size / 2 + 4),
        size / 2,
        Paint()
          ..color = Colors.black26
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
      );
      // 绿翡翠白双色外圈
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2,
        paint..color = Colors.white,
      );
      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 4,
        paint..color = AppColors.primary,
      );

      Path clipPath = Path()
        ..addOval(
          Rect.fromLTWH(border, border, size - border * 2, size - border * 2),
        );
      canvas.clipPath(clipPath);
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(
          border,
          border,
          size - border * 2,
          size - border * 2,
        ),
        image: rawImage,
        fit: BoxFit.cover,
      );

      final finalized = await recorder.endRecording().toImage(
        size.toInt(),
        (size + 10).toInt(),
      );
      final byteData = await finalized.toByteData(
        format: ui.ImageByteFormat.png,
      );

      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('nanny'),
            position: _nannyLocation,
            icon: BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List()),
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(
              title: widget.booking['name'],
              snippet: 'Arriving soon',
            ),
          ),
        };
        _isLoadingMarker = false;
      });
    } catch (e) {
      setState(() => _isLoadingMarker = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _isLoadingMarker
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _nannyLocation,
                    zoom: 16.0,
                  ),
                  markers: _markers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (ctrl) => _controllerCompleter.complete(ctrl),
                ),

          // 顶部导航返回
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.cardShadow,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.dark,
                  size: 18,
                ),
              ),
            ),
          ),

          // 悬浮式 Uber 质感卡片
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.dark.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Caregiver on Route",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.dark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "3 mins away",
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(
                          widget.booking['image'] ?? '',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.booking['name'] ?? 'Caregiver',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.dark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Verified Identity & CPR Certified",
                              style: TextStyle(
                                color: AppColors.gray,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.phone_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
