import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/scanning/camera_scan.dart';
import '../../../core/scanning/qr_barcode_scanner_screen.dart';
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

/// The POS screen: a top action bar, a searchable product picker on the left,
/// and the live cart on the right (wide) or behind a bottom bar (narrow).
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

    final body = wide
        ? Row(
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
          )
        : Stack(
            children: [
              Positioned.fill(child: picker),
              Align(alignment: Alignment.bottomCenter, child: _CartBar()),
            ],
          );

    return Column(
      children: [
        const _PosActionBar(),
        Expanded(child: body),
      ],
    );
  }
}

/// Top row of quick actions above the picker/cart split: start a fresh sale,
/// jump to customer QR menu orders, resume a parked draft, or open a table.
class _PosActionBar extends ConsumerWidget {
  const _PosActionBar();

  Future<void> _newSale(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Start a new sale?'),
          content: const Text('The current order will be cleared.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start new'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    ref.read(cartProvider.notifier).clear();
  }

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final currency = ref.read(currentCompanyProvider).currency;
    await QrBarcodeScannerScreen.open(
      context,
      title: 'Scan Product',
      subtitle: 'Align a product barcode or QR code inside the frame',
      onCode: (code) async {
        final product = await ref
            .read(inventoryActionsProvider)
            .findByBarcode(code);
        if (product == null) {
          return ScanFeedEntry(
            code: code,
            title: code,
            subtitle: 'No matching product',
            success: false,
          );
        }
        if (product.isOutOfStock) {
          return ScanFeedEntry(
            code: code,
            title: product.name,
            subtitle: 'Out of stock',
            success: false,
          );
        }
        ref.read(cartProvider.notifier).add(product);
        return ScanFeedEntry(
          code: code,
          title: product.name,
          subtitle:
              'Added · ${Fmt.money(product.sellingPrice, currency: currency)}',
          success: true,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final drafts = ref.watch(draftOrdersProvider);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xl,
        vertical: AppSpace.md,
      ),
      child: SizedBox(
        height: 46,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => _newSale(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New'),
              ),
              const SizedBox(width: 10),
              _ActionPillButton(
                icon: Icons.qr_code_2_outlined,
                label: 'QR Menu Orders',
                onTap: () => _QrMenuOrdersSheet.show(context),
              ),
              const SizedBox(width: 10),
              _ActionPillButton(
                icon: Icons.receipt_long_outlined,
                label: 'Draft List',
                badge: drafts.isEmpty ? null : drafts.length,
                onTap: () => _DraftListSheet.show(context),
              ),
              const SizedBox(width: 10),
              _ActionPillButton(
                icon: Icons.table_bar_outlined,
                label: 'Table Order',
                onTap: () => _TableOrderSheet.show(context),
              ),
              if (cameraScanSupported()) ...[
                const SizedBox(width: 10),
                _ActionPillButton(
                  icon: Icons.qr_code_scanner,
                  label: 'Scan',
                  filled: true,
                  onTap: () => _scan(context, ref),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: filled ? scheme.primary : scheme.surface,
          borderRadius: AppRadius.field,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.field,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: AppRadius.field,
                border: Border.all(
                  color: filled ? scheme.primary : scheme.outline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: filled ? Colors.white : scheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: filled ? Colors.white : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Placeholder feed for orders placed through the customer-facing QR menu —
/// honest empty state since there is no such order source wired up yet.
class _QrMenuOrdersSheet extends StatelessWidget {
  const _QrMenuOrdersSheet();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _QrMenuOrdersSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'QR Menu Orders',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Orders placed by customers scanning your table/menu QR code will\nshow up here as they come in.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpace.lg),
          ],
        ),
      ),
    );
  }
}

/// Lists parked ("Draft") sales so the cashier can resume one.
class _DraftListSheet extends ConsumerWidget {
  const _DraftListSheet();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DraftListSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftOrdersProvider);
    final currency = ref.watch(currentCompanyProvider).currency;
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: drafts.isEmpty ? 0.35 : 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.lg,
              AppSpace.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Draft List',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: drafts.isEmpty
                ? Center(
                    child: Text(
                      'No parked orders.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg,
                    ),
                    itemCount: drafts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final draft = drafts[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: scheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            '${draft.count}',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          draft.tableLabel.isEmpty
                              ? draft.diningOption
                              : '${draft.diningOption} · ${draft.tableLabel}',
                        ),
                        subtitle: Text(
                          Fmt.money(draft.total, currency: currency),
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () {
                            ref.read(draftOrdersProvider.notifier).removeAt(i);
                            ref.read(cartProvider.notifier).restore(draft);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Resume'),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ),
    );
  }
}

/// Quick table/dining picker — tapping a table opens (or tags) it as the
/// current order's seating.
class _TableOrderSheet extends ConsumerWidget {
  const _TableOrderSheet();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TableOrderSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cart = ref.watch(cartProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          Row(
            children: [
              Icon(Icons.table_bar_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Table Order',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in kDiningOptions)
                ChoiceChip(
                  label: Text(option),
                  selected: cart.diningOption == option,
                  onSelected: (_) =>
                      ref.read(cartProvider.notifier).setDiningOption(option),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Select a table', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 90,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: kTables.length,
            itemBuilder: (_, i) {
              final table = kTables[i];
              final selected = cart.tableLabel == table;
              return Material(
                color: selected
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: AppRadius.field,
                child: InkWell(
                  borderRadius: AppRadius.field,
                  onTap: () {
                    ref.read(cartProvider.notifier)
                      ..setTable(table)
                      ..setDiningOption('Dine In');
                    Navigator.of(context).pop();
                  },
                  child: Center(
                    child: Text(
                      table,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
  String? _brand;

  /// Resolves a scanned/typed code to a product and adds it to the cart.
  Future<void> _addByCode(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    final product = await ref
        .read(inventoryActionsProvider)
        .findByBarcode(code);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (product == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('No product found for “$code”')),
      );
    } else if (product.isOutOfStock) {
      messenger.showSnackBar(
        SnackBar(content: Text('${product.name} is out of stock')),
      );
    } else {
      ref.read(cartProvider.notifier).add(product);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Added ${product.name}'),
          duration: const Duration(milliseconds: 900),
        ),
      );
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
    final cart = ref.watch(cartProvider);

    // Category chips from the distinct product categories.
    final categories = <String>{
      for (final p in all)
        if (p.categoryName.trim().isNotEmpty) p.categoryName.trim(),
    }.toList()..sort();
    final chipLabels = ['Show All', ...categories];
    if (_categoryIndex >= chipLabels.length) _categoryIndex = 0;
    final selectedCategory = _categoryIndex == 0
        ? null
        : chipLabels[_categoryIndex];

    final brands = <String>{
      for (final p in all)
        if (p.brand.trim().isNotEmpty) p.brand.trim(),
    }.toList()..sort();
    if (_brand != null && !brands.contains(_brand)) _brand = null;

    final products = all
        .where(
          (p) => selectedCategory == null || p.categoryName == selectedCategory,
        )
        .where((p) => _brand == null || p.brand == _brand)
        .where(
          (p) =>
              query.isEmpty ||
              p.name.toLowerCase().contains(query) ||
              p.sku.toLowerCase().contains(query) ||
              p.barcode.contains(query),
        )
        .toList();
    final currency = ref.watch(currentCompanyProvider).currency;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.xl,
            AppSpace.xl,
            AppSpace.md,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final search = ScanSearchField(
                onChanged: widget.onSearch,
                onSubmit: (code) => _addByCode(context, ref, code),
                onScanCamera: cameraScanSupported()
                    ? () => _cameraScan(context, ref)
                    : null,
              );
              final categoryDropdown = _FilterDropdown(
                label: 'All Category',
                value: selectedCategory,
                options: categories,
                onChanged: (v) => setState(
                  () => _categoryIndex = v == null ? 0 : chipLabels.indexOf(v),
                ),
              );
              final brandDropdown = _FilterDropdown(
                label: 'Select Brand',
                value: _brand,
                options: brands,
                onChanged: (v) => setState(() => _brand = v),
              );

              if (constraints.maxWidth >= 640) {
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 10),
                    categoryDropdown,
                    const SizedBox(width: 10),
                    brandDropdown,
                  ],
                );
              }
              return Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: categoryDropdown),
                      const SizedBox(width: 10),
                      Expanded(child: brandDropdown),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        if (chipLabels.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              0,
              AppSpace.xl,
              AppSpace.md,
            ),
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
                    AppSpace.xl,
                    0,
                    AppSpace.xl,
                    AppSpace.xl,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: AppSpace.md,
                    crossAxisSpacing: AppSpace.md,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, i) {
                    final product = products[i];
                    final inCart = cart.lines
                        .where((l) => l.product.id == product.id)
                        .fold<num>(0, (s, l) => s + l.quantity);
                    return _ProductTile(
                      product: product,
                      currency: currency,
                      quantityInCart: inCart,
                      onTap: () => ref.read(cartProvider.notifier).add(product),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// A compact outlined dropdown chip used for the category/brand filters.
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String?>(
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<String?>(value: null, child: Text(label)),
        for (final o in options)
          PopupMenuItem<String?>(value: o, child: Text(o)),
      ],
      child: Container(
        height: 44,
        constraints: const BoxConstraints(minWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.field,
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: value == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.currency,
    required this.quantityInCart,
    required this.onTap,
  });

  final Product product;
  final String currency;
  final num quantityInCart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final out = product.isOutOfStock;
    final hasImage = (product.imageUrl ?? '').trim().isNotEmpty;

    return Opacity(
      opacity: out ? 0.5 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.sm),
        onTap: out ? null : onTap,
        borderColor: quantityInCart > 0
            ? scheme.primary.withValues(alpha: 0.5)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: hasImage
                      ? Image.network(
                          product.imageUrl!,
                          height: 70,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _initials(scheme),
                        )
                      : _initials(scheme),
                ),
                if (quantityInCart > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: scheme.surface, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        Fmt.qty(quantityInCart),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                else if (!out)
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
                      child: const Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.white,
                      ),
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
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Fmt.money(product.sellingPrice, currency: currency),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
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

  Widget _initials(ColorScheme scheme) {
    return Container(
      height: 70,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: scheme.primary,
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
                horizontal: AppSpace.lg,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${cart.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'View cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Fmt.money(cart.total, currency: currency),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
