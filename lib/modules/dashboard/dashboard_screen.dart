import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/stat_card.dart';
import '../../core/ui/status_pill.dart';
import '../../core/utils/format.dart';
import '../inventory/domain/product.dart';
import '../inventory/inventory_providers.dart';
import '../inventory/ui/product_form_screen.dart';
import '../pos/pos_providers.dart';

/// Dashboard. Inventory KPIs are live; sales/profit fill in with the POS module.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(currentCompanyProvider);
    final profile = ref.watch(currentProfileProvider);
    final stats = ref.watch(inventoryStatsProvider);
    final today = ref.watch(todayStatsProvider);
    final products = ref.watch(productsProvider).value ?? const [];
    final lowStock =
        products.where((p) => p.isLowStock || p.isOutOfStock).take(6).toList();

    final firstName =
        (profile.displayName ?? profile.email).split(' ').first;

    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cols = w >= 1100 ? 4 : (w >= 680 ? 2 : 1);
      final twoCol = w >= 900;

      return ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          _WelcomeBanner(
            name: firstName,
            company: company.name,
            plan: company.plan.label,
            onAddProduct: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ProductFormScreen(),
            )),
          ),
          const SizedBox(height: AppSpace.xl),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpace.lg,
            crossAxisSpacing: AppSpace.lg,
            childAspectRatio: 1.75,
            children: [
              StatCard(
                label: "Today's Sales",
                value: Fmt.money(today.revenue, currency: company.currency),
                icon: Icons.trending_up_rounded,
                color: AppColors.brand,
              ),
              StatCard(
                label: 'Orders Today',
                value: today.count.toString(),
                icon: Icons.receipt_long_outlined,
                color: AppColors.accent,
              ),
              StatCard(
                label: 'Stock Value',
                value: Fmt.money(stats.stockValue, currency: company.currency),
                icon: Icons.savings_outlined,
                color: AppColors.success,
              ),
              StatCard(
                label: 'Total Products',
                value: stats.totalProducts.toString(),
                icon: Icons.inventory_2_outlined,
                color: AppColors.brandLight,
              ),
              StatCard(
                label: 'Low Stock',
                value: stats.lowStock.toString(),
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
              StatCard(
                label: 'Out of Stock',
                value: stats.outOfStock.toString(),
                icon: Icons.remove_shopping_cart_outlined,
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          if (twoCol)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 3, child: _SalesOverviewCard()),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(flex: 2, child: _LowStockCard(items: lowStock)),
                ],
              ),
            )
          else ...[
            const _SalesOverviewCard(),
            const SizedBox(height: AppSpace.lg),
            _LowStockCard(items: lowStock),
          ],
        ],
      );
    });
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.name,
    required this.company,
    required this.plan,
    required this.onAddProduct,
  });

  final String name;
  final String company;
  final String plan;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('$plan plan',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
                Text('Welcome back, $name 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    )),
                const SizedBox(height: 4),
                Text(company,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: onAddProduct,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.brand,
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Product'),
                    ),
                    OutlinedButton.icon(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor:
                            Colors.white.withValues(alpha: 0.6),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5)),
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(Icons.point_of_sale, size: 18),
                      label: const Text('New Sale (soon)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          if (MediaQuery.sizeOf(context).width >= 720)
            Icon(Icons.storefront_rounded,
                size: 92, color: Colors.white.withValues(alpha: 0.25)),
        ],
      ),
    );
  }
}

class _SalesOverviewCard extends StatelessWidget {
  const _SalesOverviewCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Sales Overview', style: text.titleMedium),
              const Spacer(),
              StatusPill(
                  label: 'Last 7 days',
                  color: scheme.onSurfaceVariant,
                  icon: Icons.calendar_today_outlined),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          SizedBox(
            height: 150,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart_rounded,
                      size: 40, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 10),
                  Text('Sales trends appear once the POS module is live',
                      textAlign: TextAlign.center, style: text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.items});
  final List<Product> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('Low Stock Alerts', style: text.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 32),
                    const SizedBox(height: 8),
                    Text('Everything is well stocked',
                        style: text.bodySmall),
                  ],
                ),
              ),
            )
          else
            for (final p in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium),
                    ),
                    StatusPill(
                      label: p.isOutOfStock
                          ? 'Out'
                          : '${Fmt.qty(p.stock)} left',
                      color: p.isOutOfStock
                          ? AppColors.danger
                          : AppColors.warning,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
