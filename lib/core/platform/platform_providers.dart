import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_config.dart';

/// Reads/writes the single platform config document (admin only per rules).
final platformConfigProvider = StreamProvider<PlatformConfig>((ref) {
  return FirebaseFirestore.instance
      .collection('platform')
      .doc('config')
      .snapshots()
      .map((doc) => PlatformConfig.fromMap(doc.data()));
});

/// Convenience: current config (defaults until loaded).
final currentPlatformConfigProvider = Provider<PlatformConfig>((ref) {
  return ref.watch(platformConfigProvider).value ?? const PlatformConfig();
});

final platformConfigActionsProvider = Provider<PlatformConfigActions>((ref) {
  return PlatformConfigActions(FirebaseFirestore.instance);
});

class PlatformConfigActions {
  PlatformConfigActions(this._db);
  final FirebaseFirestore _db;

  Future<void> save(PlatformConfig config) {
    return _db
        .collection('platform')
        .doc('config')
        .set(config.toMap(), SetOptions(merge: true));
  }
}
