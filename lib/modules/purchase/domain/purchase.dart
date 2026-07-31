/// One line on a purchase: a product, quantity received, and unit cost.
class PurchaseItem {
  const PurchaseItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitCost,
  });

  final String productId;
  final String name;
  final num quantity;
  final num unitCost;

  num get lineTotal => quantity * unitCost;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'unitCost': unitCost,
        'lineTotal': lineTotal,
      };

  factory PurchaseItem.fromMap(Map<String, dynamic> d) => PurchaseItem(
        productId: (d['productId'] ?? '') as String,
        name: (d['name'] ?? '') as String,
        quantity: (d['quantity'] ?? 0) as num,
        unitCost: (d['unitCost'] ?? 0) as num,
      );
}

/// A received purchase (goods in). Stored at `companies/{cid}/purchases/{id}`.
class Purchase {
  const Purchase({
    required this.id,
    required this.billNo,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.shipping,
    required this.total,
    required this.paid,
    required this.createdAt,
    this.note = '',
    this.userId = '',
  });

  final String id;
  final String billNo;
  final String supplierId;
  final String supplierName;
  final List<PurchaseItem> items;
  final num subtotal;
  final num discount;
  final num tax;
  final num shipping;
  final num total;
  final num paid;
  final DateTime createdAt;
  final String note;
  final String userId;

  num get due => (total - paid).clamp(0, double.infinity);
  int get itemCount => items.fold(0, (n, i) => n + i.quantity.toInt());

  Map<String, dynamic> toMap() => {
        'billNo': billNo,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'shipping': shipping,
        'total': total,
        'paid': paid,
        'due': due,
        'note': note,
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Purchase.fromMap(String id, Map<String, dynamic> data) {
    final raw = (data['items'] as List?) ?? const [];
    return Purchase(
      id: id,
      billNo: (data['billNo'] ?? '') as String,
      supplierId: (data['supplierId'] ?? '') as String,
      supplierName: (data['supplierName'] ?? '') as String,
      items: raw
          .map((e) => PurchaseItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: (data['subtotal'] ?? 0) as num,
      discount: (data['discount'] ?? 0) as num,
      tax: (data['tax'] ?? 0) as num,
      shipping: (data['shipping'] ?? 0) as num,
      total: (data['total'] ?? 0) as num,
      paid: (data['paid'] ?? 0) as num,
      note: (data['note'] ?? '') as String,
      userId: (data['userId'] ?? '') as String,
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '') as String) ?? DateTime.now(),
    );
  }
}
