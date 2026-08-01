import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../auth/domain/auth_repository.dart';
import '../profile/domain/user_profile.dart';
import 'data/firestore_company_repository.dart';
import 'domain/company.dart';
import 'domain/company_repository.dart';
import 'domain/plan.dart';

/// Swap seam for the tenant/data backend (mirrors [authRepositoryProvider]).
final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return FirestoreCompanyRepository(FirebaseFirestore.instance);
});

/// The signed-in user's profile (company + role). Empty until loaded / if the
/// user hasn't onboarded a company yet.
final profileProvider = StreamProvider<UserProfile>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user.isEmpty) return Stream.value(UserProfile.empty);
  return ref.watch(companyRepositoryProvider).watchProfile(user.uid);
});

/// The current profile synchronously (empty while loading).
final currentProfileProvider = Provider<UserProfile>((ref) {
  return ref.watch(profileProvider).value ?? UserProfile.empty;
});

/// The company the current user belongs to.
final companyProvider = StreamProvider<Company>((ref) {
  final profile = ref.watch(currentProfileProvider);
  if (!profile.hasCompany) return Stream.value(Company.empty);
  return ref.watch(companyRepositoryProvider).watchCompany(profile.companyId);
});

/// The current company synchronously (empty while loading).
final currentCompanyProvider = Provider<Company>((ref) {
  return ref.watch(companyProvider).value ?? Company.empty;
});

/// All companies on the platform (super-admin only).
final allCompaniesProvider = StreamProvider<List<Company>>((ref) {
  return ref.watch(companyRepositoryProvider).watchAllCompanies();
});

/// Super-admin subscription controls.
final adminSubscriptionProvider = Provider<AdminSubscription>((ref) {
  return AdminSubscription(ref.watch(companyRepositoryProvider));
});

class AdminSubscription {
  AdminSubscription(this._repo);
  final CompanyRepository _repo;

  /// Approve a company on [plan]. Demo runs 7 days; Starter/Pro run [months].
  Future<void> approve(String companyId, PlanTier plan, {int months = 1}) {
    final expiry = plan == PlanTier.demo
        ? DateTime.now().add(PlanTier.demoDuration)
        : _addMonths(DateTime.now(), months);
    return _repo.adminUpdateSubscription(
      companyId: companyId,
      status: CompanyStatus.approved,
      plan: plan,
      planExpiresAt: expiry,
    );
  }

  /// Extend the current plan by [months] (or 7 days for demo).
  Future<void> extend(Company company, {int months = 1}) {
    final from = (company.planExpiresAt != null &&
            company.planExpiresAt!.isAfter(DateTime.now()))
        ? company.planExpiresAt!
        : DateTime.now();
    final expiry = company.plan == PlanTier.demo
        ? from.add(PlanTier.demoDuration)
        : _addMonths(from, months);
    return _repo.adminUpdateSubscription(
      companyId: company.id,
      status: CompanyStatus.approved,
      plan: company.plan,
      planExpiresAt: expiry,
    );
  }

  /// Change plan, keeping the current expiry (or setting one for demo).
  Future<void> changePlan(Company company, PlanTier plan, {int months = 1}) {
    final expiry = plan == PlanTier.demo
        ? DateTime.now().add(PlanTier.demoDuration)
        : _addMonths(DateTime.now(), months);
    return _repo.adminUpdateSubscription(
      companyId: company.id,
      status: CompanyStatus.approved,
      plan: plan,
      planExpiresAt: expiry,
    );
  }

  Future<void> suspend(Company company) {
    return _repo.adminUpdateSubscription(
      companyId: company.id,
      status: CompanyStatus.suspended,
      plan: company.plan,
      planExpiresAt: company.planExpiresAt,
    );
  }

  static DateTime _addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    final day = d.day;
    // Clamp day for shorter months.
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day,
        d.hour, d.minute);
  }
}

/// Everyone in the current user's company (owner + employees).
final employeesProvider = StreamProvider<List<UserProfile>>((ref) {
  final profile = ref.watch(currentProfileProvider);
  if (!profile.hasCompany) return Stream.value(const []);
  return ref.watch(companyRepositoryProvider).watchEmployees(profile.companyId);
});

/// Owner-side staff administration, bound to the current company.
final userAdminProvider = Provider<UserAdmin>((ref) {
  return UserAdmin(
    ref.watch(authRepositoryProvider),
    ref.watch(companyRepositoryProvider),
    ref.watch(currentProfileProvider).companyId,
  );
});

class UserAdmin {
  UserAdmin(this._auth, this._company, this._companyId);

  final AuthRepository _auth;
  final CompanyRepository _company;
  final String _companyId;

  /// Creates an employee's login and their company profile in one step. Does
  /// not disturb the owner's session (see [AuthRepository.createEmployeeAccount]).
  Future<void> addEmployee({
    required String name,
    required String email,
    required String password,
    required String roleId,
    String branchId = '',
  }) async {
    final uid = await _auth.createEmployeeAccount(
      email: email,
      password: password,
      displayName: name,
    );
    await _company.addEmployee(
      companyId: _companyId,
      uid: uid,
      email: email.trim(),
      roleId: roleId,
      branchId: branchId,
      displayName: name.trim(),
    );
  }

  Future<void> setRole(String uid, String roleId) =>
      _company.updateEmployeeRole(uid: uid, roleId: roleId);

  Future<void> setActive(String uid, bool active) =>
      _company.setEmployeeActive(uid: uid, active: active);
}
