/// Reasons a product's stock changes. Mirrors the spec's stock operations.
enum StockMovementType {
  add('add', 'Stock In'),
  remove('remove', 'Stock Out'),
  adjustment('adjustment', 'Adjustment'),
  damage('damage', 'Damaged'),
  lost('lost', 'Lost'),
  returned('return', 'Returned'),
  transferIn('transfer_in', 'Transfer In'),
  transferOut('transfer_out', 'Transfer Out'),
  sale('sale', 'Sale'),
  purchase('purchase', 'Purchase');

  const StockMovementType(this.id, this.label);
  final String id;
  final String label;

  static StockMovementType fromId(String? id) => StockMovementType.values
      .firstWhere((t) => t.id == id, orElse: () => StockMovementType.adjustment);
}

/// An immutable log entry recording a change to a product's stock. Stored at
/// `companies/{companyId}/stock_movements/{id}`.
class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.delta,
    required this.resultingStock,
    required this.createdAt,
    this.note = '',
    this.userId = '',
  });

  final String id;
  final String productId;
  final StockMovementType type;

  /// Signed change applied (+ in, − out).
  final num delta;

  /// Stock level *after* this movement, for auditability.
  final num resultingStock;

  final DateTime createdAt;
  final String note;
  final String userId;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'type': type.id,
        'delta': delta,
        'resultingStock': resultingStock,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'userId': userId,
      };

  factory StockMovement.fromMap(String id, Map<String, dynamic> data) {
    return StockMovement(
      id: id,
      productId: (data['productId'] ?? '') as String,
      type: StockMovementType.fromId(data['type'] as String?),
      delta: (data['delta'] ?? 0) as num,
      resultingStock: (data['resultingStock'] ?? 0) as num,
      createdAt:
          DateTime.tryParse((data['createdAt'] ?? '') as String) ?? DateTime.now(),
      note: (data['note'] ?? '') as String,
      userId: (data['userId'] ?? '') as String,
    );
  }
}
