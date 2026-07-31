import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../profile/domain/user_profile.dart';
import 'data/firestore_company_repository.dart';
import 'domain/company.dart';
import 'domain/company_repository.dart';

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
