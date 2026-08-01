/// A store branch / sub-outlet. Stored at `companies/{cid}/branches/{id}`.
///
/// The product *catalog* is shared company-wide, but stock, sales, purchases
/// and expenses are tracked per branch (under `branches/{id}/...`).
class Branch {
  const Branch({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String address;
  final String phone;
  final bool active;

  static const empty = Branch(id: '', name: '');
  bool get isEmpty => id.isEmpty;

  Branch copyWith({String? name, String? address, String? phone, bool? active}) {
    return Branch(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      active: active ?? this.active,
    );
  }

  factory Branch.fromMap(String id, Map<String, dynamic> data) {
    return Branch(
      id: id,
      name: (data['name'] ?? '') as String,
      address: (data['address'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      active: data['active'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'phone': phone,
        'active': active,
      };
}
