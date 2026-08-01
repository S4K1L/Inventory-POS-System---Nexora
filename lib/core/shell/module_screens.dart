import 'package:flutter/material.dart';

import '../modules/module.dart';
import '../../modules/accounting/ui/accounting_screen.dart';
import '../../modules/branches/ui/branches_screen.dart';
import '../../modules/crm/ui/crm_screen.dart';
import '../../modules/customers/ui/customers_screen.dart';
import '../../modules/expense/ui/expenses_screen.dart';
import '../../modules/hr/ui/hr_screen.dart';
import '../../modules/inventory/ui/inventory_screen.dart';
import '../../modules/payroll/ui/payroll_screen.dart';
import '../../modules/pos/ui/pos_screen.dart';
import '../../modules/purchase/ui/purchases_screen.dart';
import '../../modules/reports/ui/reports_screen.dart';
import '../../modules/sales/ui/sales_history_screen.dart';
import '../../modules/suppliers/ui/suppliers_screen.dart';
import '../../modules/users/ui/users_screen.dart';

/// Maps a module to its screen. The switch is exhaustive over [ModuleId], so
/// adding a module forces a case here (plus its manifest).
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
    case ModuleId.expense:
      return const ExpensesScreen();
    case ModuleId.reports:
      return const ReportsScreen();
    case ModuleId.users:
      return const UsersScreen();
    case ModuleId.branches:
      return const BranchesScreen();
    case ModuleId.crm:
      return const CrmScreen();
    case ModuleId.hr:
      return const HrScreen();
    case ModuleId.payroll:
      return const PayrollScreen();
    case ModuleId.accounting:
      return const AccountingScreen();
  }
}
