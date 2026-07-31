import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/scanning/camera_scan.dart';
import '../../../core/scanning/scan_search_field.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/pill_chips.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/format.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/inventory_actions.dart';
import '../../inventory/inventory_providers.dart';
import '../pos_providers.dart';
import 'cart_panel.dart';

/// The POS screen: a searchable product picker on the left, the live cart on
/// the right (wide) or behind a bottom bar (narrow).
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;
    final scheme = Theme.of(context).colorScheme;

    final picker = _ProductPicker(
      query: _query,
      onSearch: (v) => setState(() => _query = v.trim().toLowerCase()),
    );

    if (wide) {
      return Row(
        children: [
          Expanded(child: picker),
          Container(
            width: 380,
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(left: BorderSide(color: scheme.outline)),
            ),
            child: const CartPanel(),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: picker),
        Align(alignment: Alignment.bottomCenter, child: _CartBar()),
      ],
    );
  }
}

class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker({required this.query, required this.onSearch});
  final String query;
  final ValueChanged<String> onSearch;

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  int _categoryIndex = 0;

  /// Resolves a scanned/typed code to a product and adds it to the cart.
  Future<void> _addByCode(
      BuildContext context, WidgetRef ref, String code) async {
    final product =
        await ref.read(inventoryActionsProvider).findByBarcode(code);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (product == null) {
      messenger.showSnackBar(
          SnackBar(content: Text('No product found for “$code”')));
    } else if (product.isOutOfStock) {
      messenger.showSnackBar(
          SnackBar(content: Text('${product.name} is out of stock')));
    } else {
      ref.read(cartProvider.notifier).add(product);
      messenger.showSnackBar(SnackBar(
        content: Text('Added ${product.name}'),
        duration: const Duration(milliseconds: 900),
      ));
    }
  }

  Future<void> _cameraScan(BuildContext context, WidgetRef ref) async {
    final code = await scanWithCamera(context);
    if (code != null && context.mounted) {
      await _addByCode(context, ref, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    final all = (ref.watch(productsProvider).value ?? const [])
        .where((p) => p.active)
        .toList();

    // Category chips from the distinct product categories.
    final categories = <String>{
      for (final p in all)
        if (p.categoryName.trim().isNotEmpty) p.categoryName.trim()
    }.toList()
      ..sort();
    final chipLabels = ['Show All', ...categories];
    if (_categoryIndex >= chipLabels.length) _categoryIndex = 0;
    final selectedCategory =
        _categoryIndex == 0 ? null : chipLabels[_categoryIndex];

    final products = all
        .where((p) =>
            selectedCategory == null || p.categoryName == selectedCategory)
        .where((p) =>
            query.isEmpty ||
            p.name.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query) ||
            p.barcode.contains(query))
        .toList();
    final currency = ref.watch(currentCompanyProvider).currency;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.md),
          child: ScanSearchField(
            onChanged: widget.onSearch,
            onSubmit: (code) => _addByCode(context, ref, code),
            onScanCamera: cameraScanSupported()
                ? () => _cameraScan(context, ref)
                : null,
          ),
        ),
        if (chipLabels.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.md),
            child: PillChips(
              labels: chipLabels,
              selectedIndex: _categoryIndex,
              onSelected: (i) => setState(() => _categoryIndex = i),
            ),
          ),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('No products found.'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: AppSpace.md,
                    crossAxisSpacing: AppSpace.md,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, i) => _ProductTile(
                    product: products[i],
                    currency: currency,
                    onTap: () =>
                        ref.read(cartProvider.notifier).add(products[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.currency,
    required this.onTap,
  });

  final Product product;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final out = product.isOutOfStock;

    return Opacity(
      opacity: out ? 0.5 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.sm),
        onTap: out ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 70,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    product.name.isNotEmpty
                        ? product.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary),
                  ),
                ),
                if (!out)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add,
                          size: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(Fmt.money(product.sellingPrice, currency: currency),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: scheme.primary)),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: out
                  ? const StatusPill(label: 'Out', color: AppColors.danger)
                  : StatusPill(
                      label: '${Fmt.qty(product.stock)} ${product.unit}',
                      color: product.isLowStock
                          ? AppColors.warning
                          : AppColors.success,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Narrow-layout bottom bar summarizing the cart; opens it as a sheet.
class _CartBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final currency = ref.watch(currentCompanyProvider).currency;
    if (cart.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Material(
          color: scheme.primary,
          borderRadius: AppRadius.card,
          child: InkWell(
            borderRadius: AppRadius.card,
            onTap: () => _openCart(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${cart.count}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  const Text('View cart',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(Fmt.money(cart.total, currency: currency),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, controller) => const CartPanel(),
      ),
    );
  }
}
