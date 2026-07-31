import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../core/utils/format.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/inventory_providers.dart';
import '../../suppliers/suppliers_providers.dart';
import '../domain/purchase.dart';
import '../domain/purchases_repository.dart';
import '../purchase_providers.dart';

/// A single editable purchase line, owning its own text controllers.
class _Line {
  _Line(this.product)
      : qtyCtrl = TextEditingController(text: '1'),
        costCtrl = TextEditingController(
            text: product.purchasePrice > 0
                ? Fmt.qty(product.purchasePrice)
                : '');

  final Product product;
  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;

  num get qty => num.tryParse(qtyCtrl.text.trim()) ?? 0;
  num get cost => num.tryParse(costCtrl.text.trim()) ?? 0;
  num get lineTotal => qty * cost;

  void dispose() {
    qtyCtrl.dispose();
    costCtrl.dispose();
  }
}

/// Create a purchase (receive goods): pick a supplier, add product lines with
/// cost, then receive — which increments stock via the purchase transaction.
class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final List<_Line> _lines = [];
  String _supplierId = '';
  final _discount = TextEditingController();
  final _tax = TextEditingController();
  final _shipping = TextEditingController();
  final _paid = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    for (final c in [_discount, _tax, _shipping, _paid]) {
      c.dispose();
    }
    super.dispose();
  }

  num get _subtotal => _lines.fold<num>(0, (s, l) => s + l.lineTotal);
  num _val(TextEditingController c) => num.tryParse(c.text.trim()) ?? 0;
  num get _total =>
      (_subtotal - _val(_discount)).clamp(0, double.infinity) +
      _val(_tax) +
      _val(_shipping);
  num get _due => (_total - _val(_paid)).clamp(0, double.infinity);

  Future<void> _addProduct() async {
    final product = await _pickProduct();
    if (product == null) return;
    if (_lines.any((l) => l.product.id == product.id)) return;
    setState(() => _lines.add(_Line(product)));
  }

  Future<Product?> _pickProduct() {
    return showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ProductPickerSheet(),
    );
  }

  Future<void> _receive() async {
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one product');
      return;
    }
    if (_lines.any((l) => l.qty <= 0)) {
      setState(() => _error = 'Every line needs a quantity greater than 0');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final suppliers = ref.read(suppliersProvider).value ?? const [];
    final supplierName = _supplierId.isEmpty
        ? ''
        : suppliers
            .firstWhere((s) => s.id == _supplierId,
                orElse: () => suppliers.first)
            .name;

    final req = PurchaseRequest(
      supplierId: _supplierId,
      supplierName: supplierName,
      items: _lines
          .map((l) => PurchaseItem(
                productId: l.product.id,
                name: l.product.name,
                quantity: l.qty,
                unitCost: l.cost,
              ))
          .toList(),
      discount: _val(_discount),
      tax: _val(_tax),
      shipping: _val(_shipping),
      paid: _val(_paid),
    );

    try {
      final purchase = await ref.read(receivePurchaseProvider).call(req);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Received ${purchase.billNo} · stock updated')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() =>
          _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currentCompanyProvider).currency;
    final suppliers = (ref.watch(suppliersProvider).value ?? const [])
        .where((s) => s.active)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Receive purchase')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.xl),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _supplierId.isEmpty ? null : _supplierId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Supplier (optional)',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('No supplier')),
                  for (final s in suppliers)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _supplierId = v ?? ''),
              ),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Text('Products', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addProduct,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add product'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              if (_lines.isEmpty)
                AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('No products added yet',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ),
                )
              else
                for (final line in _lines) _lineTile(line, currency),
              const SizedBox(height: AppSpace.lg),
              _totalsCard(currency),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.md),
                FormErrorBox(_error!),
              ],
              const SizedBox(height: AppSpace.lg),
              FilledButton.icon(
                onPressed: _busy ? null : _receive,
                icon: _busy
                    ? const ButtonSpinner()
                    : const Icon(Icons.inventory_2_outlined),
                label: Text(_busy
                    ? ''
                    : 'Receive · ${Fmt.money(_total, currency: currency)}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineTile(_Line line, String currency) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text('In stock: ${Fmt.qty(line.product.stock)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _miniField(line.qtyCtrl, 'Qty', 64),
            const SizedBox(width: 8),
            _miniField(line.costCtrl, 'Cost', 88),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() {
                _lines.remove(line);
                line.dispose();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniField(TextEditingController c, String label, double width) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
    );
  }

  Widget _totalsCard(String currency) {
    String m(num v) => Fmt.money(v, currency: currency);
    return AppCard(
      child: Column(
        children: [
          _totalRow('Subtotal', m(_subtotal)),
          const SizedBox(height: 8),
          _adjustRow('Discount', _discount),
          _adjustRow('Tax', _tax),
          _adjustRow('Shipping', _shipping),
          const Divider(height: 20),
          _totalRow('Total', m(_total), bold: true),
          const SizedBox(height: 8),
          _adjustRow('Paid', _paid),
          const SizedBox(height: 4),
          _totalRow('Due to supplier', m(_due)),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
        fontSize: bold ? 17 : 14,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }

  Widget _adjustRow(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SizedBox(
            width: 120,
            height: 38,
            child: TextField(
              controller: c,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A searchable product picker used when adding purchase lines.
class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = (ref.watch(productsProvider).value ?? const [])
        .where((p) =>
            _query.isEmpty ||
            p.name.toLowerCase().contains(_query) ||
            p.sku.toLowerCase().contains(_query))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search product to add…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text('Stock: ${Fmt.qty(p.stock)} ${p.unit}'),
                  trailing: const Icon(Icons.add),
                  onTap: () => Navigator.of(context).pop(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
