import 'dart:async';
import 'dart:ui' as ui; // For handling low-level image conversion
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
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controllerCompleter = Completer();

  // Simulated nanny coordinates near Southern University College, Johor Bahru
  final LatLng _nannyLocation = const LatLng(1.5346, 103.6808);

  Set<Marker> _markers = {};
  bool _isLoadingMarker = true; // Indicates if marker image is loading

  @override
  void initState() {
    super.initState();
    // Start loading custom avatar marker on initialization
    _loadCustomMarker();
  }

  // Core function: Download network image, crop to circle, add white border, convert to Marker icon
  Future<void> _loadCustomMarker() async {
    try {
      final String imageUrl =
          widget.booking['image'] ??
          'https://api.dicebear.com/7.x/avataaars/png?seed=default';

      // 1. Download image stream
      final ImageStream stream = NetworkImage(
        imageUrl,
      ).resolve(ImageConfiguration.empty);
      final Completer<ui.Image> completer = Completer<ui.Image>();

      ImageStreamListener? listener;
      listener = ImageStreamListener(
        (ImageInfo frame, bool sync) {
          final ui.Image image = frame.image;
          completer.complete(image);
          stream.removeListener(listener!);
        },
        onError: (Object exc, StackTrace? stackTrace) {
          completer.completeError(exc);
          stream.removeListener(listener!);
        },
      );
      stream.addListener(listener);

      final ui.Image rawImage = await completer.future;

      // 2. Use Canvas to draw circular avatar (with white border)
      const double size = 150.0; // Final marker size
      const double borderSize = 10.0; // Border width
      const double radius = size / 2;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint paint = Paint()..isAntiAlias = true;

      // Draw rounded rectangle shadow (optional, adds depth)
      canvas.drawCircle(
        const Offset(radius, radius + 5),
        radius,
        Paint()
          ..color = Colors.black26.withValues(alpha: 0.15)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
      );

      // Draw large white circle (as border)
      paint.color = Colors.white;
      canvas.drawCircle(const Offset(radius, radius), radius, paint);

      // Clip out a smaller circle (for placing avatar)
      Path clipPath = Path()
        ..addOval(
          Rect.fromLTWH(
            borderSize,
            borderSize,
            size - borderSize * 2,
            size - borderSize * 2,
          ),
        );
      canvas.clipPath(clipPath);

      // Draw the downloaded original avatar image and stretch to fill
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(
          borderSize,
          borderSize,
          size - borderSize * 2,
          size - borderSize * 2,
        ),
        image: rawImage,
        fit: BoxFit.cover,
      );

      // Convert Canvas drawing content to image data
      final ui.Picture picture = recorder.endRecording();
      final ui.Image finalizedImage = await picture.toImage(
        size.toInt(),
        (size + 10).toInt(),
      );
      final ByteData? byteData = await finalizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List markerIconBytes = byteData!.buffer.asUint8List();

      // 3. Set the converted circular avatar data as Marker icon
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('nanny'),
            position: _nannyLocation,
            // Key: Use custom circular avatar icon
            icon: BitmapDescriptor.fromBytes(markerIconBytes),
            anchor: const Offset(
              0.5,
              0.5,
            ), // Center align image with coordinate point
            infoWindow: InfoWindow(
              title: widget.booking['name'],
              snippet: 'Approaching...',
            ),
          ),
        };
        _isLoadingMarker = false; // Loading complete
      });
    } catch (e) {
      debugPrint("Nanny Marker loading failed: $e");
      // If loading fails, fallback to default pin to prevent crash
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('nanny'),
            position: _nannyLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(title: widget.booking['name']),
          ),
        };
        _isLoadingMarker = false;
      });
    }
  }

  void _recenterMap() async {
    final GoogleMapController controller = await _controllerCompleter.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_nannyLocation, 16.0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 1. Bottom layer: Google Map
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
                  myLocationEnabled: true,

                  // Add this line! Force disable Google's built-in location button to prevent interference
                  myLocationButtonEnabled: false,

                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (GoogleMapController controller) {
                    _controllerCompleter.complete(controller);
                    _mapController = controller;
                  },
                ),

          // 2. Top layer: Navigation bar (back button) - unchanged
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: const Icon(Icons.arrow_back, color: AppColors.dark),
                  ),
                ),
                const SizedBox(width: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: const Text(
                    "Live Tracking",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Right side: Location control button - unchanged
          Positioned(
            bottom:
                200, // Slightly lower because the panel below is now shorter
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              elevation: 4,
              onPressed: _recenterMap,
              child: const Icon(Icons.my_location, color: AppColors.primary),
            ),
          ),

          // 4. Bottom: Nanny info panel (Optimized: removed vehicle info, only person)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min, // Let panel wrap content, make it shorter
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    "Nanny is nearby",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Approx. 3 mins away",
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Nanny card - simplified
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: NetworkImage(
                            widget.booking['image'] ?? '',
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.booking['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: AppColors.dark,
                                ),
                              ),
                              // Vehicle info (Toyota Vios etc.) has been removed, keep it clean
                              const Text(
                                "Verified Nanny",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 45,
                          height: 45,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.phone,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            onPressed: () => debugPrint("Calling Nanny..."),
                          ),
                        ),
                      ],
                    ),
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
