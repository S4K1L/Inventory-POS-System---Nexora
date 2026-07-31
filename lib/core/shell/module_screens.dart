import 'package:flutter/material.dart';

import '../modules/module.dart';
import '../../modules/customers/ui/customers_screen.dart';
import '../../modules/inventory/ui/inventory_screen.dart';
import '../../modules/pos/ui/pos_screen.dart';
import '../../modules/purchase/ui/purchases_screen.dart';
import '../../modules/sales/ui/sales_history_screen.dart';
import '../../modules/suppliers/ui/suppliers_screen.dart';
import 'module_placeholder.dart';

/// Maps a module to its screen. Modules that aren't built yet fall back to a
/// placeholder. Adding a module = one case here (plus its manifest).
Widget screenForModule(ModuleManifest module) {
  switch (module.id) {
    case ModuleId.inventory:
      return const InventoryScreen();
    case ModuleId.pos:
      return const PosScreen();
    case ModuleId.sales:
      return const SalesHistoryScreen();
    case ModuleId.suppliers:
      return const SuppliersScreen();
    case ModuleId.purchase:
      return const PurchasesScreen();
    case ModuleId.customers:
      return const CustomersScreen();
    default:
      return ModulePlaceholder(module: module);
  }
}
