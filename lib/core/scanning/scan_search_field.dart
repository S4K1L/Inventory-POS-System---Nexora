import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A "scan or search" input — the integration point for USB/Bluetooth barcode
/// scanners, which behave as keyboards that type the code and press Enter.
///
/// - [onChanged] fires on every keystroke → live search / grid filter.
/// - [onSubmit] fires on Enter (i.e. when a scanner finishes, or the user hits
///   return) → barcode lookup.
/// - After a submit the field clears and re-grabs focus, so a worker can scan
///   item after item without touching the screen.
class ScanSearchField extends StatefulWidget {
  const ScanSearchField({
    super.key,
    required this.onChanged,
    required this.onSubmit,
    this.hintText = 'Scan barcode or search product…',
    this.autofocus = true,
    this.onScanCamera,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final String hintText;
  final bool autofocus;

  /// If provided, shows a camera button (for phones/tablets without a gun).
  final VoidCallback? onScanCamera;

  @override
  State<ScanSearchField> createState() => _ScanSearchFieldState();
}

class _ScanSearchFieldState extends State<ScanSearchField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _handleSubmit(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    widget.onSubmit(value);
    _controller.clear();
    widget.onChanged(''); // reset the live filter after a scan
    // Keep focus so the next scan lands here immediately.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      // Scanners emit a newline; make sure it triggers submit.
      onChanged: widget.onChanged,
      onSubmitted: _handleSubmit,
      inputFormatters: [
        // Strip stray newline/tab a scanner might inject mid-string.
        FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
      ],
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.qr_code_scanner),
        suffixIcon: widget.onScanCamera == null
            ? null
            : IconButton(
                tooltip: 'Scan with camera',
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: widget.onScanCamera,
              ),
      ),
    );
  }
}
