import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/product.dart';
import '../domain/stock_movement.dart';
import '../inventory_actions.dart';

/// Bottom sheet for changing a product's stock. Choose a movement type and a
/// quantity; the sign is derived from the type (in vs out).
class StockAdjustSheet extends ConsumerStatefulWidget {
  const StockAdjustSheet({super.key, required this.product});
  final Product product;

  static Future<void> show(BuildContext context, Product product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StockAdjustSheet(product: product),
      ),
    );
  }

  @override
  ConsumerState<StockAdjustSheet> createState() => _StockAdjustSheetState();
}

class _StockAdjustSheetState extends ConsumerState<StockAdjustSheet> {
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();
  StockMovementType _type = StockMovementType.add;
  bool _busy = false;
  String? _error;

  // Types offered here and whether they add (+) or remove (−) stock.
  static const _outTypes = {
    StockMovementType.remove,
    StockMovementType.damage,
    StockMovementType.lost,
    StockMovementType.transferOut,
  };

  static const _choices = [
    StockMovementType.add,
    StockMovementType.remove,
    StockMovementType.returned,
    StockMovementType.damage,
    StockMovementType.lost,
    StockMovementType.adjustment,
  ];

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = num.tryParse(_qty.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a quantity greater than 0');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    // For "adjustment" the number is the signed delta as typed; for others the
    // sign comes from the movement type.
    final delta = _type == StockMovementType.adjustment
        ? qty
        : (_outTypes.contains(_type) ? -qty : qty);

    try {
      await ref.read(inventoryActionsProvider).adjustStock(
            productId: widget.product.id,
            delta: delta,
            type: _type,
            note: _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Adjust stock · ${widget.product.name}',
              style: theme.textTheme.titleMedium),
          Text('Current: ${widget.product.stock} ${widget.product.unit}',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final t in _choices)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: InputDecoration(
              labelText: _type == StockMovementType.adjustment
                  ? 'Signed change (e.g. -3)'
                  : 'Quantity',
              prefixIcon: const Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
