import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_tokens.dart';

/// One entry in the on-screen scan feed: what was scanned and what happened.
class ScanFeedEntry {
  const ScanFeedEntry({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.success,
  });

  final String code;
  final String title;
  final String subtitle;
  final bool success;
}

/// Resolves a scanned code (e.g. barcode lookup + add-to-cart) and reports
/// what to show in the live feed.
typedef ScanResolver = Future<ScanFeedEntry> Function(String code);

/// A dedicated, full-screen, mobile-first scanning experience: animated
/// bracket reticle + sweeping laser, a live feed of what's been scanned this
/// session, and a manual-entry fallback — purpose-built for rapid multi-item
/// POS scanning rather than a single one-shot capture.
class QrBarcodeScannerScreen extends StatefulWidget {
  const QrBarcodeScannerScreen({
    super.key,
    required this.onCode,
    this.title = 'Scan to Add',
    this.subtitle = 'Align a product barcode or QR code inside the frame',
  });

  final ScanResolver onCode;
  final String title;
  final String subtitle;

  /// Pushes the scanner as a full-screen route. Returns the number of items
  /// successfully resolved.
  static Future<int?> open(
    BuildContext context, {
    required ScanResolver onCode,
    String title = 'Scan to Add',
    String subtitle = 'Align a product barcode or QR code inside the frame',
  }) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            QrBarcodeScannerScreen(onCode: onCode, title: title, subtitle: subtitle),
      ),
    );
  }

  @override
  State<QrBarcodeScannerScreen> createState() =>
      _QrBarcodeScannerScreenState();
}

class _QrBarcodeScannerScreenState extends State<QrBarcodeScannerScreen>
    with TickerProviderStateMixin {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _manualCtrl = TextEditingController();
  final _feed = <ScanFeedEntry>[];

  late final AnimationController _laser =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Color _flashColor = AppColors.success;

  bool _torchOn = false;
  bool _busy = false;
  bool _manualOpen = false;
  String? _pendingCode;
  Timer? _cooldown;

  @override
  void dispose() {
    _cooldown?.cancel();
    _controller.dispose();
    _manualCtrl.dispose();
    _laser.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty || code == _pendingCode) return;
    _resolve(code);
  }

  Future<void> _resolve(String code) async {
    setState(() {
      _busy = true;
      _pendingCode = code;
    });
    HapticFeedback.lightImpact();
    final entry = await widget.onCode(code);
    if (!mounted) return;
    setState(() {
      _feed.insert(0, entry);
      _flashColor = entry.success ? AppColors.success : AppColors.danger;
    });
    _flash.forward(from: 0);
    if (!entry.success) HapticFeedback.vibrate();
    // Debounce so the same label isn't re-triggered while still in frame.
    _cooldown?.cancel();
    _cooldown = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _pendingCode = null);
    });
    setState(() => _busy = false);
  }

  void _submitManual() {
    final v = _manualCtrl.text.trim();
    if (v.isEmpty) return;
    _manualCtrl.clear();
    _resolve(v);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 720;
    final frameSize = wide ? 260.0 : (size.width * 0.62).clamp(200.0, 280.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: widget.title,
              torchOn: _torchOn,
              onClose: () => Navigator.of(context).pop(_successCount),
              onTorch: () {
                setState(() => _torchOn = !_torchOn);
                unawaited(_controller.toggleTorch());
              },
              onFlipCamera: () => unawaited(_controller.switchCamera()),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 480 : size.width),
                  child: ClipRRect(
                    borderRadius: wide
                        ? BorderRadius.circular(AppRadius.xl)
                        : BorderRadius.zero,
                    child: Stack(
                      alignment: Alignment.center,
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(controller: _controller, onDetect: _onDetect),
                        Container(color: Colors.black.withValues(alpha: 0.35)),
                        _Reticle(size: frameSize, laser: _laser, busy: _busy),
                        AnimatedBuilder(
                          animation: _flash,
                          builder: (_, _) => IgnorePointer(
                            child: Container(
                              color: _flashColor.withValues(
                                  alpha: (1 - _flash.value) * 0.28),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 18,
                          left: 24,
                          right: 24,
                          child: Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _ManualEntryBar(
              open: _manualOpen,
              controller: _manualCtrl,
              onToggle: () => setState(() => _manualOpen = !_manualOpen),
              onSubmit: _submitManual,
            ),
            _ScanFeedPanel(feed: _feed, successCount: _successCount),
          ],
        ),
      ),
    );
  }

  int get _successCount => _feed.where((e) => e.success).length;
}

/// Bracket-corner reticle with a sweeping laser line — deliberately distinct
/// from a plain bordered box so the scan target reads instantly.
class _Reticle extends StatelessWidget {
  const _Reticle({required this.size, required this.laser, required this.busy});

  final double size;
  final Animation<double> laser;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = busy ? AppColors.brandLight : Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(size: Size(size, size), painter: _BracketPainter(color)),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AnimatedBuilder(
              animation: laser,
              builder: (_, _) => Align(
                alignment: Alignment(0, -1 + laser.value * 2),
                child: Container(
                  height: 2.5,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(colors: [
                      AppColors.brand.withValues(alpha: 0),
                      AppColors.brand,
                      AppColors.brand.withValues(alpha: 0),
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.8),
                          blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 26.0;
    const r = 18.0;

    void corner(Offset origin, double dx, double dy) {
      final path = Path()
        ..moveTo(origin.dx, origin.dy + dy * len)
        ..lineTo(origin.dx, origin.dy + dy * r)
        ..quadraticBezierTo(
            origin.dx, origin.dy, origin.dx + dx * r, origin.dy)
        ..lineTo(origin.dx + dx * len, origin.dy);
      canvas.drawPath(path, paint);
    }

    corner(const Offset(0, 0), 1, 1);
    corner(Offset(size.width, 0), -1, 1);
    corner(Offset(0, size.height), 1, -1);
    corner(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.torchOn,
    required this.onClose,
    required this.onTorch,
    required this.onFlipCamera,
  });

  final String title;
  final bool torchOn;
  final VoidCallback onClose;
  final VoidCallback onTorch;
  final VoidCallback onFlipCamera;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, 0),
      child: Row(
        children: [
          _circleBtn(Icons.close, onClose),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          _circleBtn(Icons.cameraswitch_outlined, onFlipCamera),
          const SizedBox(width: 8),
          _circleBtn(torchOn ? Icons.flash_on : Icons.flash_off, onTorch,
              active: torchOn),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool active = false}) {
    return Material(
      color: active ? AppColors.brand : Colors.white.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
    );
  }
}

class _ManualEntryBar extends StatelessWidget {
  const _ManualEntryBar({
    required this.open,
    required this.controller,
    required this.onToggle,
    required this.onSubmit,
  });

  final bool open;
  final TextEditingController controller;
  final VoidCallback onToggle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
      child: open
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => onSubmit(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Type barcode or SKU…',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        onPressed: onSubmit,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_hide_outlined, color: Colors.white54),
                  onPressed: onToggle,
                ),
              ],
            )
          : Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: onToggle,
                icon: const Icon(Icons.keyboard_alt_outlined,
                    color: Colors.white70, size: 18),
                label: const Text('Enter code manually',
                    style: TextStyle(color: Colors.white70)),
              ),
            ),
    );
  }
}

/// Live, scrollable feed of what's been scanned this session — lets the
/// cashier fire through a stack of items without leaving the camera.
class _ScanFeedPanel extends StatelessWidget {
  const _ScanFeedPanel({required this.feed, required this.successCount});

  final List<ScanFeedEntry> feed;
  final int successCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF15161C),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.md, 0),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner, size: 16, color: Colors.white54),
                const SizedBox(width: 8),
                Text('Scanned this session',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                const Spacer(),
                StatusPillDark(count: successCount),
              ],
            ),
          ),
          Flexible(
            child: feed.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Text('No scans yet — items you scan will appear here.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12.5)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
                    itemCount: feed.length,
                    itemBuilder: (_, i) {
                      final e = feed[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              e.success ? Icons.check_circle : Icons.error_outline,
                              size: 18,
                              color: e.success ? AppColors.success : AppColors.danger,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                                  Text(e.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(successCount),
                child: Text(successCount == 0
                    ? 'Close'
                    : 'Done · $successCount added'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dark-theme count pill for the scanner's feed header.
class StatusPillDark extends StatelessWidget {
  const StatusPillDark({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text('$count added',
          style: const TextStyle(
              color: AppColors.success, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}
