/// Fine-grained permission keys, in `module.action` form.
///
/// Kept as string constants (not an enum) so custom, company-defined roles can
/// reference them from Firestore without a code change.
class Perm {
  Perm._();

  // Inventory
  static const inventoryView = 'inventory.view';
  static const inventoryCreate = 'inventory.create';
  static const inventoryEdit = 'inventory.edit';
  static const inventoryDelete = 'inventory.delete';
  static const inventoryAdjust = 'inventory.adjust';

  // POS / Sales
  static const posUse = 'pos.use';
  static const posDiscount = 'pos.discount';
  static const posRefund = 'pos.refund';
  static const salesView = 'sales.view';

  // Purchase
  static const purchaseView = 'purchase.view';
  static const purchaseManage = 'purchase.manage';

  // Contacts
  static const customersManage = 'customers.manage';
  static const suppliersManage = 'suppliers.manage';

  // Money
  static const expenseManage = 'expense.manage';
  static const reportsView = 'reports.view';

  // Admin
  static const usersManage = 'users.manage';
  static const settingsManage = 'settings.manage';
  static const modulesManage = 'modules.manage';
}

/// A role bundles a set of permissions. Built-in roles live here; companies can
/// later store custom roles in Firestore using the same shape.
class Role {
  const Role({
    required this.id,
    required this.name,
    required this.permissions,
  });

  final String id;
  final String name;
  final Set<String> permissions;

  bool can(String permission) =>
      permissions.contains('*') || permissions.contains(permission);
}

/// Built-in roles, mirroring the product spec
/// (Owner, Manager, Cashier, Warehouse Manager, Accountant, Salesman).
class Roles {
  Roles._();

  static const owner = Role(
    id: 'owner',
    name: 'Owner',
    permissions: {'*'}, // full access
  );

  static const manager = Role(
    id: 'manager',
    name: 'Manager',
    permissions: {
      Perm.inventoryView,
      Perm.inventoryCreate,
      Perm.inventoryEdit,
      Perm.inventoryAdjust,
      Perm.posUse,
      Perm.posDiscount,
      Perm.posRefund,
      Perm.salesView,
      Perm.purchaseView,
      Perm.purchaseManage,
      Perm.customersManage,
      Perm.suppliersManage,
      Perm.expenseManage,
      Perm.reportsView,
      Perm.usersManage,
    },
  );

  // POS-only employee: sees just the POS screen. Can still attach existing
  // customers and complete sales (those are data operations, not gated modules).
  static const cashier = Role(
    id: 'cashier',
    name: 'Cashier (POS only)',
    permissions: {
      Perm.posUse,
      Perm.posDiscount,
    },
  );

  static const warehouseManager = Role(
    id: 'warehouse_manager',
    name: 'Warehouse Manager',
    permissions: {
      Perm.inventoryView,
      Perm.inventoryCreate,
      Perm.inventoryEdit,
      Perm.inventoryDelete,
      Perm.inventoryAdjust,
      Perm.purchaseView,
      Perm.suppliersManage,
    },
  );

  static const accountant = Role(
    id: 'accountant',
    name: 'Accountant',
    permissions: {
      Perm.reportsView,
      Perm.expenseManage,
      Perm.salesView,
      Perm.purchaseView,
    },
  );

  static const salesman = Role(
    id: 'salesman',
    name: 'Salesman',
    permissions: {
      Perm.posUse,
      Perm.salesView,
      Perm.customersManage,
      Perm.inventoryView,
    },
  );

  static const all = <Role>[
    owner,
    manager,
    cashier,
    warehouseManager,
    accountant,
    salesman,
  ];

  static Role byId(String id) =>
      all.firstWhere((r) => r.id == id, orElse: () => cashier);
}
