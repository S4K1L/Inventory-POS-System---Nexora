import '../../modules/module.dart';

/// Subscription tiers. A plan is a convenient *bundle* of modules; a company's
/// actual access is plan defaults overridden by per-company toggles.
enum PlanTier {
  starter('starter', 'Starter'),
  business('business', 'Business'),
  professional('professional', 'Professional'),
  enterprise('enterprise', 'Enterprise');

  const PlanTier(this.id, this.label);
  final String id;
  final String label;

  static PlanTier fromId(String? id) {
    return PlanTier.values.firstWhere(
      (p) => p.id == id,
      orElse: () => PlanTier.starter,
    );
  }
}

/// Which modules each plan unlocks by default. Core modules are always on and
/// don't need listing here.
class PlanCatalog {
  PlanCatalog._();

  static const _starter = {
    ModuleId.inventory,
    ModuleId.pos,
    ModuleId.sales,
    ModuleId.customers,
    ModuleId.reports,
  };

  static const _business = {
    ..._starter,
    ModuleId.purchase,
    ModuleId.suppliers,
    ModuleId.expense,
    ModuleId.crm,
    ModuleId.accounting,
  };

  static const _professional = {
    ..._business,
    ModuleId.hr,
    ModuleId.payroll,
  };

  static Set<ModuleId> modulesFor(PlanTier tier) {
    switch (tier) {
      case PlanTier.starter:
        return _starter;
      case PlanTier.business:
        return _business;
      case PlanTier.professional:
      case PlanTier.enterprise:
        return _professional;
    }
  }
}
