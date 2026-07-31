/// A customer. Stored at `companies/{cid}/customers/{id}`.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.dueAmount = 0,
    this.loyaltyPoints = 0,
    this.notes = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;

  /// Outstanding receivable from this customer (rises on credit sales).
  final num dueAmount;

  final num loyaltyPoints;
  final String notes;
  final bool active;

  Customer copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    num? dueAmount,
    num? loyaltyPoints,
    String? notes,
    bool? active,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      dueAmount: dueAmount ?? this.dueAmount,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      notes: notes ?? this.notes,
      active: active ?? this.active,
    );
  }

  factory Customer.fromMap(String id, Map<String, dynamic> data) {
    return Customer(
      id: id,
      name: (data['name'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      address: (data['address'] ?? '') as String,
      dueAmount: (data['dueAmount'] ?? 0) as num,
      loyaltyPoints: (data['loyaltyPoints'] ?? 0) as num,
      notes: (data['notes'] ?? '') as String,
      active: data['active'] != false,
    );
  }

  /// [dueAmount]/[loyaltyPoints] are excluded — they only change via sales /
  /// payments, not through the edit form.
  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'active': active,
      };
}
