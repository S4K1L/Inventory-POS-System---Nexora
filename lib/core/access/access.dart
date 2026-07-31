import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../company/company_providers.dart';
import '../company/domain/company.dart';
import '../modules/module.dart';
import '../profile/domain/user_profile.dart';

/// The three-way gate from the design:
///   1. the module must be enabled for the company, AND
///   2. any dependency modules must be enabled, AND
///   3. the user's role must grant the required permission.
///
/// Feature flags ([feature]) are a finer check *within* a module.
class Access {
  const Access(this._company, this._profile);

  final Company _company;
  final UserProfile _profile;

  /// Is this module enabled for the company AND are its dependencies enabled?
  bool hasModule(ModuleManifest module) {
    if (!_company.hasModule(module)) return false;
    for (final depId in module.dependencies) {
      if (!_company.hasModule(ModuleRegistry.byId(depId))) return false;
    }
    return true;
  }

  /// A sub-feature flag, e.g. `inventory.barcode`.
  bool feature(String key, {bool defaultValue = false}) =>
      _company.hasFeature(key, defaultValue: defaultValue);

  /// A role permission, e.g. `inventory.create`.
  bool can(String permission) => _profile.can(permission);

  /// The full gate for opening a module: enabled + permitted.
  bool canOpen(ModuleManifest module) =>
      hasModule(module) && can(module.viewPermission);

  /// Modules to surface in navigation. Enabled modules the user can open, plus
  /// premium modules that aren't enabled (shown as locked "upgrade" teasers).
  List<ModuleManifest> visibleModules() {
    return ModuleRegistry.all.where((m) {
      if (canOpen(m)) return true;
      // Advertise premium modules the company could upgrade to.
      if (m.premium && can(m.viewPermission)) return true;
      return false;
    }).toList();
  }

  bool isLocked(ModuleManifest module) => !hasModule(module);
}

/// Composes the current company + profile into a single [Access] object.
/// Watch this anywhere to gate UI.
final accessProvider = Provider<Access>((ref) {
  final company = ref.watch(currentCompanyProvider);
  final profile = ref.watch(currentProfileProvider);
  return Access(company, profile);
});
