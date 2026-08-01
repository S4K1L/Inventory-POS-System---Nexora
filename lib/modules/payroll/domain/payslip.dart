/// A monthly payslip for one employee. Stored at
/// `companies/{cid}/payslips/{id}`.
class Payslip {
  const Payslip({
    required this.id,
    required this.uid,
    required this.employeeName,
    required this.month, // yyyy-MM
    required this.basic,
    this.bonus = 0,
    this.deduction = 0,
    required this.createdAt,
  });

  final String id;
  final String uid;
  final String employeeName;
  final String month;
  final num basic;
  final num bonus;
  final num deduction;
  final DateTime createdAt;

  num get net => basic + bonus - deduction;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'employeeName': employeeName,
        'month': month,
        'basic': basic,
        'bonus': bonus,
        'deduction': deduction,
        'net': net,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Payslip.fromMap(String id, Map<String, dynamic> data) {
    return Payslip(
      id: id,
      uid: (data['uid'] ?? '') as String,
      employeeName: (data['employeeName'] ?? '') as String,
      month: (data['month'] ?? '') as String,
      basic: (data['basic'] ?? 0) as num,
      bonus: (data['bonus'] ?? 0) as num,
      deduction: (data['deduction'] ?? 0) as num,
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '') as String) ?? DateTime.now(),
    );
  }
}
