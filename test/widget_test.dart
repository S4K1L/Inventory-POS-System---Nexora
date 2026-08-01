import 'package:flutter_test/flutter_test.dart';

import 'package:nexora/core/company/domain/company.dart';
import 'package:nexora/core/company/domain/plan.dart';
import 'package:nexora/core/modules/module.dart';
import 'package:nexora/core/permissions/permissions.dart';

void main() {
  group('Module access resolution', () {
    test('Pro modules are locked on Demo/Starter, unlocked on Pro', () {
      const starter = Company(id: 'c1', name: 'S', plan: PlanTier.starter);
      const pro = Company(id: 'c2', name: 'P', plan: PlanTier.pro);

      // Base module available everywhere.
      expect(starter.hasModule(ModuleRegistry.inventory), isTrue);
      // Pro-only modules gated by plan.
      expect(starter.hasModule(ModuleRegistry.payroll), isFalse);
      expect(starter.hasModule(ModuleRegistry.accounting), isFalse);
      expect(pro.hasModule(ModuleRegistry.payroll), isTrue);
      expect(pro.hasModule(ModuleRegistry.accounting), isTrue);
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
        plan: PlanTier.pro,
        moduleOverrides: {'pos': false},
      );

      expect(grantCrm.hasModule(ModuleRegistry.crm), isTrue,
          reason: 'override grants Pro CRM even on Starter');
      expect(blockPos.hasModule(ModuleRegistry.pos), isFalse,
          reason: 'override blocks POS even on Pro');
    });

    test('company is active only when approved and not expired', () {
      final active = Company(
        id: 'c1',
        name: 'A',
        planExpiresAt: DateTime.now().add(const Duration(days: 3)),
      );
      final expired = Company(
        id: 'c2',
        name: 'E',
        planExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      const pending = Company(id: 'c3', name: 'P', status: CompanyStatus.pending);

      expect(active.isActive, isTrue);
      expect(expired.isActive, isFalse);
      expect(pending.isActive, isFalse);
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
