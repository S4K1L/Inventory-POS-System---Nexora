import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/access/access.dart';
import '../../../core/access/gates.dart';
import '../../../core/company/company_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/pill_chips.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/format.dart';
import '../domain/product.dart';
import '../inventory_actions.dart';
import '../inventory_providers.dart';
import 'product_form_screen.dart';
import 'stock_adjust_sheet.dart';

/// Product list — the Inventory module's main screen. Actions are permission
/// gated so a Cashier sees a read-only list while a Manager gets full controls.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _query = '';
  _StockFilter _filter = _StockFilter.all;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final currency = ref.watch(currentCompanyProvider).currency;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            onSearch: (v) => setState(() => _query = v.trim().toLowerCase()),
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
            onAdd: () => _openForm(context),
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (products) {
                if (products.isEmpty) return _EmptyState(onAdd: () => _openForm(context));
                final list = _applyFilters(products);
                if (list.isEmpty) {
                  return const Center(child: Text('No matching products.'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, i) => const SizedBox(height: AppSpace.md),
                  itemBuilder: (_, i) => _ProductCard(
                    product: list[i],
                    currency: currency,
                    onEdit: () => _openForm(context, existing: list[i]),
                    onAdjust: () => StockAdjustSheet.show(context, list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Product> _applyFilters(List<Product> products) {
    return products.where((p) {
      final matchesQuery = _query.isEmpty ||
          p.name.toLowerCase().contains(_query) ||
          p.sku.toLowerCase().contains(_query) ||
          p.brand.toLowerCase().contains(_query) ||
          p.barcode.contains(_query);
      final matchesFilter = switch (_filter) {
        _StockFilter.all => true,
        _StockFilter.low => p.isLowStock,
        _StockFilter.out => p.isOutOfStock,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  void _openForm(BuildContext context, {Product? existing}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductFormScreen(existing: existing),
    ));
  }
}

enum _StockFilter { all, low, out }

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onSearch,
    required this.filter,
    required this.onFilter,
    required this.onAdd,
  });

  final ValueChanged<String> onSearch;
  final _StockFilter filter;
  final ValueChanged<_StockFilter> onFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      onChanged: onSearch,
      decoration: const InputDecoration(
        hintText: 'Search by name, SKU, brand or barcode…',
        prefixIcon: Icon(Icons.search),
        isDense: true,
      ),
    );
    final chips = PillChips(
      labels: const ['All', 'Low stock', 'Out of stock'],
      selectedIndex: _StockFilter.values.indexOf(filter),
      onSelected: (i) => onFilter(_StockFilter.values[i]),
    );
    final addBtn = PermissionGate(
      permission: Perm.inventoryCreate,
      child: FilledButton.icon(
        onPressed: onAdd,
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Product'),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: AppSpace.md),
            addBtn,
          ],
        ),
        const SizedBox(height: AppSpace.md),
        chips,
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.product,
    required this.currency,
    required this.onEdit,
    required this.onAdjust,
  });

  final Product product;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      if (product.categoryName.isNotEmpty) product.categoryName,
      if (product.brand.isNotEmpty) product.brand,
      if (product.sku.isNotEmpty) 'SKU ${product.sku}',
    ].join('  ·  ');

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(product.sellingPrice, currency: currency),
                  style: text.titleSmall),
              const SizedBox(height: 4),
              _stockPill(),
            ],
          ),
          _Menu(product: product, onEdit: onEdit, onAdjust: onAdjust),
        ],
      ),
    );
  }

  Widget _stockPill() {
    if (product.isOutOfStock) {
      return const StatusPill(label: 'Out of stock', color: AppColors.danger);
    }
    if (product.isLowStock) {
      return StatusPill(
          label: 'Low · ${Fmt.qty(product.stock)}', color: AppColors.warning);
    }
    return StatusPill(
        label: '${Fmt.qty(product.stock)} ${product.unit}',
        color: AppColors.success);
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({
    required this.product,
    required this.onEdit,
    required this.onAdjust,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessProvider);
    final canEdit = access.can(Perm.inventoryEdit);
    final canAdjust = access.can(Perm.inventoryAdjust);
    final canDelete = access.can(Perm.inventoryDelete);

    if (!canEdit && !canAdjust && !canDelete) return const SizedBox(width: 8);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case 'adjust':
            onAdjust();
          case 'edit':
            onEdit();
          case 'archive':
            await ref
                .read(inventoryActionsProvider)
                .archiveProduct(product.id);
        }
      },
      itemBuilder: (_) => [
        if (canAdjust)
          const PopupMenuItem(
            value: 'adjust',
            child: ListTile(
              leading: Icon(Icons.swap_vert),
              title: Text('Adjust stock'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (canEdit)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (canDelete)
          const PopupMenuItem(
            value: 'archive',
            child: ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text('Archive'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 40, color: scheme.primary),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('No products yet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Add your first item to start tracking stock.',
              style: text.bodyMedium),
          const SizedBox(height: AppSpace.xl),
          PermissionGate(
            permission: Perm.inventoryCreate,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Product'),
            ),
          ),
        ],
      ),
    );
  }
}
