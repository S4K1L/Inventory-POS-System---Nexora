/// A supplier/vendor. Stored at `companies/{cid}/suppliers/{id}`.
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.dueAmount = 0,
    this.notes = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;

  /// Outstanding payable to this supplier (increases on credit purchases).
  final num dueAmount;

  final String notes;
  final bool active;

  Supplier copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    num? dueAmount,
    String? notes,
    bool? active,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      dueAmount: dueAmount ?? this.dueAmount,
      notes: notes ?? this.notes,
      active: active ?? this.active,
    );
  }

  factory Supplier.fromMap(String id, Map<String, dynamic> data) {
    return Supplier(
      id: id,
      name: (data['name'] ?? '') as String,
      contactPerson: (data['contactPerson'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      address: (data['address'] ?? '') as String,
      dueAmount: (data['dueAmount'] ?? 0) as num,
      notes: (data['notes'] ?? '') as String,
      active: data['active'] != false,
    );
  }

  /// [dueAmount] is excluded from normal writes — it only changes through
  /// purchase transactions / payments.
  Map<String, dynamic> toMap() => {
        'name': name,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'active': active,
      };
}
