import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import 'domain/attendance.dart';

/// Contract for attendance data.
abstract interface class HrRepository {
  /// productId-free: returns uid → status for a given [date] (yyyy-MM-dd).
  Stream<Map<String, AttendanceStatus>> watchAttendance(
      String companyId, String date);
  Future<void> setAttendance(String companyId, AttendanceRecord record);
}

class FirestoreHrRepository implements HrRepository {
  FirestoreHrRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String cid) =>
      _db.collection('companies').doc(cid).collection('attendance');

  @override
  Stream<Map<String, AttendanceStatus>> watchAttendance(
      String companyId, String date) {
    return _col(companyId).where('date', isEqualTo: date).snapshots().map((s) {
      final map = <String, AttendanceStatus>{};
      for (final d in s.docs) {
        final status = AttendanceStatus.fromId(d.data()['status'] as String?);
        final uid = d.data()['uid'] as String?;
        if (status != null && uid != null) map[uid] = status;
      }
      return map;
    });
  }

  @override
  Future<void> setAttendance(String companyId, AttendanceRecord record) {
    return _col(companyId)
        .doc('${record.date}_${record.uid}')
        .set(record.toMap());
  }
}

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  return FirestoreHrRepository(FirebaseFirestore.instance);
});

/// The date being viewed on the HR screen (yyyy-MM-dd), defaults to today.
final attendanceDateProvider = NotifierProvider<AttendanceDate, String>(
  AttendanceDate.new,
);

class AttendanceDate extends Notifier<String> {
  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  String build() => _fmt(DateTime.now());
  void set(DateTime d) => state = _fmt(d);
}

/// uid → status for the selected date.
final attendanceProvider = StreamProvider<Map<String, AttendanceStatus>>((ref) {
  final cid = ref.watch(currentProfileProvider).companyId;
  final date = ref.watch(attendanceDateProvider);
  if (cid.isEmpty) return Stream.value(const {});
  return ref.watch(hrRepositoryProvider).watchAttendance(cid, date);
});

final hrActionsProvider = Provider<HrActions>((ref) {
  return HrActions(
    ref.watch(hrRepositoryProvider),
    ref.watch(currentProfileProvider).companyId,
  );
});

class HrActions {
  HrActions(this._repo, this._companyId);
  final HrRepository _repo;
  final String _companyId;

  Future<void> mark(String uid, String date, AttendanceStatus status) {
    return _repo.setAttendance(
        _companyId, AttendanceRecord(uid: uid, date: date, status: status));
  }
}
