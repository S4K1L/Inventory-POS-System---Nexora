import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import 'data/firestore_branches_repository.dart';
import 'domain/branch.dart';
import 'domain/branches_repository.dart';

final branchesRepositoryProvider = Provider<BranchesRepository>((ref) {
  return FirestoreBranchesRepository(FirebaseFirestore.instance);
});

/// All branches of the current company.
final branchesProvider = StreamProvider<List<Branch>>((ref) {
  final profile = ref.watch(currentProfileProvider);
  if (!profile.hasCompany) return Stream.value(const []);
  return ref.watch(branchesRepositoryProvider).watchBranches(profile.companyId);
});

/// The owner's manual branch selection (null = default to first). Employees
/// ignore this — they're locked to their assigned branch.
final manualBranchProvider =
    NotifierProvider<ManualBranchNotifier, String?>(ManualBranchNotifier.new);

class ManualBranchNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String branchId) => state = branchId;
}

/// The effective active branch id.
/// - An employee assigned to a branch is locked to it.
/// - Otherwise (owner/manager) it's the manual selection, or the first branch.
final currentBranchIdProvider = Provider<String>((ref) {
  final profile = ref.watch(currentProfileProvider);
  final branches = ref.watch(branchesProvider).value ?? const [];

  if (profile.branchId.isNotEmpty &&
      branches.any((b) => b.id == profile.branchId)) {
    return profile.branchId;
  }
  final manual = ref.watch(manualBranchProvider);
  if (manual != null && branches.any((b) => b.id == manual)) return manual;
  return branches.isNotEmpty ? branches.first.id : '';
});

/// The active [Branch] object.
final currentBranchProvider = Provider<Branch>((ref) {
  final id = ref.watch(currentBranchIdProvider);
  final branches = ref.watch(branchesProvider).value ?? const [];
  return branches.firstWhere((b) => b.id == id, orElse: () => Branch.empty);
});

/// Whether the current user may switch branches (owners/managers can).
final canSwitchBranchProvider = Provider<bool>((ref) {
  return ref.watch(currentProfileProvider).branchId.isEmpty;
});

final branchActionsProvider = Provider<BranchActions>((ref) {
  return BranchActions(
    ref.watch(branchesRepositoryProvider),
    ref.watch(currentProfileProvider).companyId,
  );
});

class BranchActions {
  BranchActions(this._repo, this._companyId);
  final BranchesRepository _repo;
  final String _companyId;

  Future<String> create(Branch b) => _repo.createBranch(_companyId, b);
  Future<void> update(Branch b) => _repo.updateBranch(_companyId, b);
  Future<void> setActive(String id, bool active) =>
      _repo.setBranchActive(_companyId, id, active);
}
