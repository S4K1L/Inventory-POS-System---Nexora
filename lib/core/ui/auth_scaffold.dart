import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'brand_logo.dart';

/// Shared shell for auth screens: a rich gradient brand panel on wide layouts,
/// with the form in a clean card beside it. On narrow screens it collapses to
/// just the form with a compact logo.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final formPanel = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!wide) ...[
                const Center(child: BrandLogo(size: 44)),
                const SizedBox(height: AppSpace.xxl),
              ],
              form,
            ],
          ),
        ),
      ),
    );

    if (!wide) return Scaffold(body: formPanel);

    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(flex: 4, child: formPanel),
        ],
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Stack(
        children: [
          // Soft decorative circles.
          Positioned(
            top: -60,
            right: -40,
            child: _blob(220, Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: _blob(260, Colors.white.withValues(alpha: 0.06)),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandLogo(size: 44, onDark: true),
                const Spacer(),
                Text(
                  'Run your whole shop\nfrom one screen.',
                  style: TextStyle(
                    fontSize: 40,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Inventory, fast POS billing, suppliers, and reports — '
                  'modular, and built to scale with your business.',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 32),
                const _Feature(icon: Icons.point_of_sale, text: 'Lightning-fast checkout'),
                const _Feature(icon: Icons.inventory_2_outlined, text: 'Real-time stock tracking'),
                const _Feature(icon: Icons.insights_outlined, text: 'Live sales & profit insights'),
                const Spacer(),
                Text(
                  '© Nexora — Smart Inventory. Fast Sales.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 14),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
