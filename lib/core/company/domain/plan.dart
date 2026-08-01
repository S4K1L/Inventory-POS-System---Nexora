import '../../modules/module.dart';

/// Subscription tiers assigned by the platform admin.
/// - demo: short free trial (7 days), Pro features locked.
/// - starter: paid, Pro features locked; admin sets the duration in months.
/// - pro: everything unlocked; admin sets the duration in months.
enum PlanTier {
  demo('demo', 'Demo'),
  starter('starter', 'Starter'),
  pro('pro', 'Pro');

  const PlanTier(this.id, this.label);
  final String id;
  final String label;

  static PlanTier fromId(String? id) {
    return PlanTier.values.firstWhere(
      (p) => p.id == id,
      orElse: () => PlanTier.demo,
    );
  }

  /// Free trial length for the demo plan.
  static const demoDuration = Duration(days: 7);
}

/// Which modules each plan unlocks.
class PlanCatalog {
  PlanCatalog._();

  /// Modules that require the Pro plan. Locked on Demo and Starter.
  static const proModules = {
    ModuleId.crm,
    ModuleId.hr,
    ModuleId.payroll,
    ModuleId.accounting,
  };

  /// Everything except the Pro-only modules — available on every plan.
  static const _base = {
    ModuleId.inventory,
    ModuleId.pos,
    ModuleId.purchase,
    ModuleId.sales,
    ModuleId.customers,
    ModuleId.suppliers,
    ModuleId.expense,
    ModuleId.reports,
  };

  static const _all = {..._base, ...proModules};

  static Set<ModuleId> modulesFor(PlanTier tier) {
    switch (tier) {
      case PlanTier.pro:
        return _all;
      case PlanTier.demo:
      case PlanTier.starter:
        return _base;
    }
  }
}
