import '../../modules/module.dart';
import 'plan.dart';

/// A tenant. One [Company] owns its own inventory, sales, users, and — most
/// importantly here — its own module and feature toggles.
///
/// Firestore shape (`companies/{id}`):
/// ```
/// {
///   name: "Shakil Store",
///   currency: "BDT",
///   plan: "business",
///   modules:  { "crm": true, "payroll": false },   // per-company overrides
///   features: { "inventory.barcode": true, "inventory.qr": false }
/// }
/// ```
class Company {
  const Company({
    required this.id,
    required this.name,
    this.currency = 'BDT',
    this.timezone = 'Asia/Dhaka',
    this.plan = PlanTier.starter,
    this.moduleOverrides = const {},
    this.features = const {},
  });

  final String id;
  final String name;
  final String currency;
  final String timezone;
  final PlanTier plan;

  /// Explicit per-company module toggles. Overrides the plan default in either
  /// direction: `{crm: true}` grants CRM even on Starter; `{pos: false}` blocks
  /// POS even on a plan that includes it.
  final Map<String, bool> moduleOverrides;

  /// Sub-feature flags within a module, e.g. `inventory.barcode`.
  final Map<String, bool> features;

  static const empty = Company(id: '', name: '');
  bool get isEmpty => id.isEmpty;

  /// The resolution rule: core modules are always on; otherwise an explicit
  /// override wins; otherwise fall back to the plan bundle.
  bool hasModule(ModuleManifest module) {
    if (module.core) return true;
    final override = moduleOverrides[module.id.id];
    if (override != null) return override;
    return PlanCatalog.modulesFor(plan).contains(module.id);
  }

  /// A feature flag. [defaultValue] applies when the company hasn't set it.
  bool hasFeature(String key, {bool defaultValue = false}) {
    return features[key] ?? defaultValue;
  }

  factory Company.fromMap(String id, Map<String, dynamic> data) {
    return Company(
      id: id,
      name: (data['name'] ?? '') as String,
      currency: (data['currency'] ?? 'BDT') as String,
      timezone: (data['timezone'] ?? 'Asia/Dhaka') as String,
      plan: PlanTier.fromId(data['plan'] as String?),
      moduleOverrides: _boolMap(data['modules']),
      features: _boolMap(data['features']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'currency': currency,
        'timezone': timezone,
        'plan': plan.id,
        'modules': moduleOverrides,
        'features': features,
      };

  static Map<String, bool> _boolMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v == true));
  }
}
