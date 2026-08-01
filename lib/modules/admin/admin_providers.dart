import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import '../../core/company/domain/company.dart';
import '../../core/company/domain/plan.dart';
import '../../core/platform/platform_providers.dart';
import '../../core/profile/domain/user_profile.dart';
import '../branches/branches_providers.dart';
import '../branches/domain/branch.dart';

/// Platform-wide analytics computed from all companies + pricing config.
class AdminStats {
  const AdminStats({
    required this.total,
    required this.active,
    required this.pending,
    required this.suspended,
    required this.expired,
    required this.expiringSoon,
    required this.mrr,
    required this.planCounts,
    required this.currency,
  });

  final int total;
  final int active;
  final int pending;
  final int suspended;
  final int expired;

  /// Active companies whose plan lapses within 7 days.
  final int expiringSoon;

  /// Estimated monthly recurring revenue from active paid plans.
  final num mrr;

  /// Active companies per plan tier.
  final Map<PlanTier, int> planCounts;

  final String currency;
}

final adminStatsProvider = Provider<AdminStats>((ref) {
  final companies = ref.watch(allCompaniesProvider).value ?? const [];
  final config = ref.watch(currentPlatformConfigProvider);

  var active = 0, pending = 0, suspended = 0, expired = 0, expiringSoon = 0;
  num mrr = 0;
  final planCounts = {for (final t in PlanTier.values) t: 0};

  for (final c in companies) {
    if (c.status == CompanyStatus.pending) {
      pending++;
    } else if (c.status == CompanyStatus.suspended) {
      suspended++;
    } else if (c.isExpired) {
      expired++;
    } else {
      // Approved + within period.
      active++;
      planCounts[c.plan] = (planCounts[c.plan] ?? 0) + 1;
      if (c.daysLeft <= 7) expiringSoon++;
      if (c.plan == PlanTier.starter) mrr += config.starterPrice;
      if (c.plan == PlanTier.pro) mrr += config.proPrice;
    }
  }

  return AdminStats(
    total: companies.length,
    active: active,
    pending: pending,
    suspended: suspended,
    expired: expired,
    expiringSoon: expiringSoon,
    mrr: mrr,
    planCounts: planCounts,
    currency: config.currency,
  );
});

/// Companies filtered/searched for the Companies section.
class CompanyFilter {
  const CompanyFilter({this.query = '', this.status});
  final String query;
  final CompanyStatus? status;
}

final companyFilterProvider =
    NotifierProvider<CompanyFilterNotifier, CompanyFilter>(
        CompanyFilterNotifier.new);

class CompanyFilterNotifier extends Notifier<CompanyFilter> {
  @override
  CompanyFilter build() => const CompanyFilter();
  void setQuery(String q) => state = CompanyFilter(query: q, status: state.status);
  void setStatus(CompanyStatus? s) =>
      state = CompanyFilter(query: state.query, status: s);
}

final filteredCompaniesProvider = Provider<List<Company>>((ref) {
  final all = ref.watch(allCompaniesProvider).value ?? const [];
  final f = ref.watch(companyFilterProvider);
  final q = f.query.trim().toLowerCase();
  return all.where((c) {
    final matchesStatus = f.status == null ||
        (f.status == CompanyStatus.approved
            ? c.isActive
            : c.status == f.status);
    final matchesQuery = q.isEmpty ||
        c.name.toLowerCase().contains(q) ||
        c.ownerEmail.toLowerCase().contains(q);
    return matchesStatus && matchesQuery;
  }).toList();
});

/// The tenant's team (admin can read via rules).
final companyUsersProvider =
    StreamProvider.family<List<UserProfile>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value(const []);
  return ref.watch(companyRepositoryProvider).watchEmployees(companyId);
});

/// The tenant's branches (admin read).
final companyBranchesProvider =
    StreamProvider.family<List<Branch>, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value(const []);
  return ref.watch(branchesRepositoryProvider).watchBranches(companyId);
});
