import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_tokens.dart';

/// Whether live camera scanning is available on this platform.
/// (Windows/Linux desktop have no camera plugin — those use a USB scanner via
/// [ScanSearchField] instead.)
bool cameraScanSupported() {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

/// Opens the camera and resolves with the first scanned code (or null if the
/// user cancels).
Future<String?> scanWithCamera(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    builder: (_) => const _CameraScanSheet(),
  );
}

class _CameraScanSheet extends StatefulWidget {
  const _CameraScanSheet();

  @override
  State<_CameraScanSheet> createState() => _CameraScanSheetState();
}

class _CameraScanSheetState extends State<_CameraScanSheet> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      height: size.height * 0.7,
      child: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Framing guide.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _circleBtn(
                  Icons.close,
                  () => Navigator.of(context).pop(),
                ),
                _circleBtn(Icons.flash_on, () => _controller.toggleTorch()),
              ],
            ),
          ),
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Text(
              'Point the camera at a barcode or QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}
