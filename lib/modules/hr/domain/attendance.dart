import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Attendance state for one person on one day.
enum AttendanceStatus {
  present('present', 'Present'),
  absent('absent', 'Absent'),
  leave('leave', 'Leave');

  const AttendanceStatus(this.id, this.label);
  final String id;
  final String label;

  static AttendanceStatus? fromId(String? id) {
    for (final s in AttendanceStatus.values) {
      if (s.id == id) return s;
    }
    return null;
  }

  Color get color => switch (this) {
        AttendanceStatus.present => AppColors.success,
        AttendanceStatus.absent => AppColors.danger,
        AttendanceStatus.leave => AppColors.warning,
      };
}

/// An attendance mark. Stored at `companies/{cid}/attendance/{date}_{uid}`
/// where date is `yyyy-MM-dd`.
class AttendanceRecord {
  const AttendanceRecord({
    required this.uid,
    required this.date,
    required this.status,
  });

  final String uid;
  final String date;
  final AttendanceStatus status;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'date': date,
        'status': status.id,
      };
}
