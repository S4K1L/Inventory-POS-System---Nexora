import 'branch.dart';

/// Contract for branch data.
abstract interface class BranchesRepository {
  Stream<List<Branch>> watchBranches(String companyId);
  Future<String> createBranch(String companyId, Branch branch);
  Future<void> updateBranch(String companyId, Branch branch);
  Future<void> setBranchActive(String companyId, String branchId, bool active);
}
