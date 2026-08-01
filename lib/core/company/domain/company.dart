import '../../modules/module.dart';
import 'plan.dart';

/// Where a tenant sits in the platform approval/subscription lifecycle.
enum CompanyStatus {
  pending('pending', 'Pending approval'),
  approved('approved', 'Active'),
  suspended('suspended', 'Suspended');

  const CompanyStatus(this.id, this.label);
  final String id;
  final String label;

  /// Legacy companies (no status field) are treated as approved so existing
  /// tenants aren't locked out; new signups explicitly write `pending`.
  static CompanyStatus fromId(String? id) {
    return CompanyStatus.values.firstWhere(
      (s) => s.id == id,
      orElse: () => CompanyStatus.approved,
    );
  }
}

/// A tenant. Owns its own inventory, sales, users, branches, module/feature
/// toggles, and its subscription state (status + plan + expiry) set by the
/// platform admin.
class Company {
  const Company({
    required this.id,
    required this.name,
    this.currency = 'BDT',
    this.timezone = 'Asia/Dhaka',
    this.plan = PlanTier.demo,
    this.status = CompanyStatus.approved,
    this.planExpiresAt,
    this.ownerEmail = '',
    this.createdAt,
    this.moduleOverrides = const {},
    this.features = const {},
  });

  final String id;
  final String name;
  final String currency;
  final String timezone;
  final PlanTier plan;
  final CompanyStatus status;

  /// When the current plan lapses. Null = no expiry set yet (e.g. pending).
  final DateTime? planExpiresAt;

  final String ownerEmail;
  final DateTime? createdAt;

  /// Per-company module toggles overriding the plan default in either
  /// direction.
  final Map<String, bool> moduleOverrides;

  /// Sub-feature flags within a module, e.g. `inventory.barcode`.
  final Map<String, bool> features;

  static const empty = Company(id: '', name: '');
  bool get isEmpty => id.isEmpty;

  bool get isExpired =>
      planExpiresAt != null && DateTime.now().isAfter(planExpiresAt!);

  /// The tenant can use the app only when approved and within its plan period.
  bool get isActive => status == CompanyStatus.approved && !isExpired;

  /// Days left on the current plan (0 if expired / none).
  int get daysLeft {
    if (planExpiresAt == null) return 0;
    final diff = planExpiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Module resolution: core modules always on; explicit override wins;
  /// otherwise the plan bundle decides (Pro modules locked on Demo/Starter).
  bool hasModule(ModuleManifest module) {
    if (module.core) return true;
    final override = moduleOverrides[module.id.id];
    if (override != null) return override;
    return PlanCatalog.modulesFor(plan).contains(module.id);
  }

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
      status: CompanyStatus.fromId(data['status'] as String?),
      planExpiresAt: _date(data['planExpiresAt']),
      ownerEmail: (data['ownerEmail'] ?? '') as String,
      createdAt: _date(data['createdAt']),
      moduleOverrides: _boolMap(data['modules']),
      features: _boolMap(data['features']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'currency': currency,
        'timezone': timezone,
        'plan': plan.id,
        'status': status.id,
        'planExpiresAt': planExpiresAt?.toIso8601String(),
        'ownerEmail': ownerEmail,
        'createdAt': createdAt?.toIso8601String(),
        'modules': moduleOverrides,
        'features': features,
      };

  static DateTime? _date(dynamic raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  static Map<String, bool> _boolMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v == true));
  }
}
