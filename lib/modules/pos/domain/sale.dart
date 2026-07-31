import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Supported tender types. Includes Bangladesh mobile wallets from the spec.
enum PaymentMethod {
  cash('cash', 'Cash', Icons.payments_outlined),
  card('card', 'Card', Icons.credit_card),
  bkash('bkash', 'bKash', Icons.smartphone),
  nagad('nagad', 'Nagad', Icons.smartphone),
  rocket('rocket', 'Rocket', Icons.smartphone),
  bank('bank', 'Bank', Icons.account_balance_outlined);

  const PaymentMethod(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;

  static PaymentMethod fromId(String? id) => PaymentMethod.values
      .firstWhere((m) => m.id == id, orElse: () => PaymentMethod.cash);

  Color get color => switch (this) {
        PaymentMethod.cash => AppColors.success,
        PaymentMethod.card => AppColors.brand,
        PaymentMethod.bkash => const Color(0xFFE2136E),
        PaymentMethod.nagad => const Color(0xFFF7941D),
        PaymentMethod.rocket => const Color(0xFF8A2BE2),
        PaymentMethod.bank => AppColors.accent,
      };
}

/// One line on a sale (denormalized so the receipt is stable even if the
/// product later changes).
class SaleItem {
  const SaleItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final String productId;
  final String name;
  final num unitPrice;
  final num quantity;

  num get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'lineTotal': lineTotal,
      };

  factory SaleItem.fromMap(Map<String, dynamic> data) => SaleItem(
        productId: (data['productId'] ?? '') as String,
        name: (data['name'] ?? '') as String,
        unitPrice: (data['unitPrice'] ?? 0) as num,
        quantity: (data['quantity'] ?? 0) as num,
      );
}

/// A completed sale. Stored at `companies/{cid}/sales/{id}`.
class Sale {
  const Sale({
    required this.id,
    required this.invoiceNo,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paid,
    required this.paymentMethod,
    required this.createdAt,
    this.customerName = '',
    this.userId = '',
  });

  final String id;
  final String invoiceNo;
  final List<SaleItem> items;
  final num subtotal;
  final num discount;
  final num tax;
  final num total;
  final num paid;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;
  final String customerName;
  final String userId;

  num get change => (paid - total).clamp(0, double.infinity);
  int get itemCount => items.fold(0, (n, i) => n + i.quantity.toInt());

  Map<String, dynamic> toMap() => {
        'invoiceNo': invoiceNo,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'total': total,
        'paid': paid,
        'change': change,
        'paymentMethod': paymentMethod.id,
        'customerName': customerName,
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Sale.fromMap(String id, Map<String, dynamic> data) {
    final rawItems = (data['items'] as List?) ?? const [];
    return Sale(
      id: id,
      invoiceNo: (data['invoiceNo'] ?? '') as String,
      items: rawItems
          .map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: (data['subtotal'] ?? 0) as num,
      discount: (data['discount'] ?? 0) as num,
      tax: (data['tax'] ?? 0) as num,
      total: (data['total'] ?? 0) as num,
      paid: (data['paid'] ?? 0) as num,
      paymentMethod: PaymentMethod.fromId(data['paymentMethod'] as String?),
      customerName: (data['customerName'] ?? '') as String,
      userId: (data['userId'] ?? '') as String,
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '') as String) ?? DateTime.now(),
    );
  }
}
