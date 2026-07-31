import 'package:flutter/material.dart';

import '../permissions/permissions.dart';

/// Stable identifiers for every business module. The string [id] is what gets
/// stored in Firestore under `companies/{id}.modules`.
enum ModuleId {
  inventory('inventory'),
  pos('pos'),
  purchase('purchase'),
  sales('sales'),
  customers('customers'),
  suppliers('suppliers'),
  expense('expense'),
  reports('reports'),
  crm('crm'),
  hr('hr'),
  payroll('payroll'),
  accounting('accounting');

  const ModuleId(this.id);
  final String id;

  static ModuleId? fromId(String id) {
    for (final m in ModuleId.values) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// Describes a module: how it appears in navigation, what it needs to run, and
/// which permission gates its entry point. This is the "manifest" pattern —
/// adding a module is data, not scattered `if` statements.
class ModuleManifest {
  const ModuleManifest({
    required this.id,
    required this.name,
    required this.icon,
    required this.route,
    required this.viewPermission,
    this.group = 'Menu',
    this.core = false,
    this.premium = false,
    this.dependencies = const {},
  });

  final ModuleId id;
  final String name;
  final IconData icon;

  /// Sidebar section this module appears under (e.g. Menu, Offering, Back Office).
  final String group;

  /// go_router path, e.g. `/inventory`.
  final String route;

  /// Permission required to even see/open the module.
  final String viewPermission;

  /// Core modules are always enabled for every company (cannot be turned off).
  final bool core;

  /// Premium modules show an "Upgrade" state when not enabled, instead of
  /// being hidden — this advertises features the company hasn't bought yet.
  final bool premium;

  /// Modules that must be enabled for this one to work
  /// (e.g. POS depends on Inventory).
  final Set<ModuleId> dependencies;
}

/// The static catalog of every module the platform knows about.
/// Enabling/disabling per company is handled separately (see company data).
class ModuleRegistry {
  ModuleRegistry._();

  static const inventory = ModuleManifest(
    id: ModuleId.inventory,
    name: 'Inventory',
    icon: Icons.inventory_2_outlined,
    route: '/inventory',
    viewPermission: Perm.inventoryView,
  );

  static const pos = ModuleManifest(
    id: ModuleId.pos,
    name: 'POS',
    icon: Icons.point_of_sale_outlined,
    route: '/pos',
    viewPermission: Perm.posUse,
    dependencies: {ModuleId.inventory},
  );

  static const purchase = ModuleManifest(
    id: ModuleId.purchase,
    name: 'Purchase',
    icon: Icons.local_shipping_outlined,
    route: '/purchase',
    viewPermission: Perm.purchaseView,
    dependencies: {ModuleId.inventory, ModuleId.suppliers},
  );

  static const sales = ModuleManifest(
    id: ModuleId.sales,
    name: 'Sales',
    icon: Icons.receipt_long_outlined,
    route: '/sales',
    viewPermission: Perm.salesView,
  );

  static const customers = ModuleManifest(
    id: ModuleId.customers,
    name: 'Customers',
    icon: Icons.people_outline,
    route: '/customers',
    viewPermission: Perm.customersManage,
    group: 'Offering',
  );

  static const suppliers = ModuleManifest(
    id: ModuleId.suppliers,
    name: 'Suppliers',
    icon: Icons.store_outlined,
    route: '/suppliers',
    viewPermission: Perm.suppliersManage,
    group: 'Offering',
  );

  static const expense = ModuleManifest(
    id: ModuleId.expense,
    name: 'Expenses',
    icon: Icons.account_balance_wallet_outlined,
    route: '/expense',
    viewPermission: Perm.expenseManage,
    group: 'Back Office',
  );

  static const reports = ModuleManifest(
    id: ModuleId.reports,
    name: 'Reports',
    icon: Icons.bar_chart_outlined,
    route: '/reports',
    viewPermission: Perm.reportsView,
    group: 'Back Office',
  );

  static const crm = ModuleManifest(
    id: ModuleId.crm,
    name: 'CRM',
    icon: Icons.handshake_outlined,
    route: '/crm',
    viewPermission: Perm.customersManage,
    group: 'Offering',
    premium: true,
  );

  static const hr = ModuleManifest(
    id: ModuleId.hr,
    name: 'HR',
    icon: Icons.badge_outlined,
    route: '/hr',
    viewPermission: Perm.usersManage,
    group: 'Back Office',
    premium: true,
  );

  static const payroll = ModuleManifest(
    id: ModuleId.payroll,
    name: 'Payroll',
    icon: Icons.payments_outlined,
    route: '/payroll',
    viewPermission: Perm.usersManage,
    group: 'Back Office',
    premium: true,
  );

  static const accounting = ModuleManifest(
    id: ModuleId.accounting,
    name: 'Accounting',
    icon: Icons.calculate_outlined,
    route: '/accounting',
    viewPermission: Perm.reportsView,
    group: 'Back Office',
    premium: true,
  );

  /// Every module, in display order.
  static const all = <ModuleManifest>[
    inventory,
    pos,
    purchase,
    sales,
    customers,
    suppliers,
    expense,
    reports,
    crm,
    hr,
    payroll,
    accounting,
  ];

  static ModuleManifest byId(ModuleId id) =>
      all.firstWhere((m) => m.id == id);
}
