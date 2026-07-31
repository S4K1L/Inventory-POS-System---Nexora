import 'package:flutter_test/flutter_test.dart';

import 'package:nexora/core/company/domain/company.dart';
import 'package:nexora/core/company/domain/plan.dart';
import 'package:nexora/core/modules/module.dart';
import 'package:nexora/core/permissions/permissions.dart';

void main() {
  group('Module access resolution', () {
    test('plan bundles unlock modules', () {
      const starter = Company(id: 'c1', name: 'S', plan: PlanTier.starter);
      const professional =
          Company(id: 'c2', name: 'P', plan: PlanTier.professional);

      expect(starter.hasModule(ModuleRegistry.inventory), isTrue);
      expect(starter.hasModule(ModuleRegistry.payroll), isFalse);
      expect(professional.hasModule(ModuleRegistry.payroll), isTrue);
    });

    test('per-company override beats the plan in both directions', () {
      const grantCrm = Company(
        id: 'c1',
        name: 'S',
        plan: PlanTier.starter,
        moduleOverrides: {'crm': true},
      );
      const blockPos = Company(
        id: 'c2',
        name: 'B',
        plan: PlanTier.business,
        moduleOverrides: {'pos': false},
      );

      expect(grantCrm.hasModule(ModuleRegistry.crm), isTrue,
          reason: 'override grants CRM even on Starter');
      expect(blockPos.hasModule(ModuleRegistry.pos), isFalse,
          reason: 'override blocks POS even though the plan includes it');
    });

    test('feature flags default off and honor overrides', () {
      const company = Company(
        id: 'c1',
        name: 'S',
        features: {'inventory.barcode': true},
      );
      expect(company.hasFeature('inventory.barcode'), isTrue);
      expect(company.hasFeature('inventory.qr'), isFalse);
    });
  });

  group('Role permissions', () {
    test('owner can do everything', () {
      expect(Roles.owner.can(Perm.settingsManage), isTrue);
      expect(Roles.owner.can('anything.at.all'), isTrue);
    });

    test('cashier is limited to POS-ish permissions', () {
      expect(Roles.cashier.can(Perm.posUse), isTrue);
      expect(Roles.cashier.can(Perm.settingsManage), isFalse);
      expect(Roles.cashier.can(Perm.inventoryDelete), isFalse);
    });
  });
}
