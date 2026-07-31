import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/access/access.dart';
import '../../../core/scanning/camera_scan.dart';
import '../domain/product.dart';
import '../inventory_actions.dart';
import '../inventory_features.dart';
import '../inventory_providers.dart';

/// Create or edit a product. Pass [existing] to edit; null to create.
/// The barcode/QR and wholesale fields respect per-company feature flags.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.existing});
  final Product? existing;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _sku = TextEditingController(text: widget.existing?.sku ?? '');
  late final _barcode =
      TextEditingController(text: widget.existing?.barcode ?? '');
  late final _brand = TextEditingController(text: widget.existing?.brand ?? '');
  late final _unit =
      TextEditingController(text: widget.existing?.unit ?? 'pcs');
  late final _purchase = TextEditingController(
      text: _numText(widget.existing?.purchasePrice));
  late final _selling =
      TextEditingController(text: _numText(widget.existing?.sellingPrice));
  late final _wholesale =
      TextEditingController(text: _numText(widget.existing?.wholesalePrice));
  late final _minStock =
      TextEditingController(text: _numText(widget.existing?.minStock));
  final _opening = TextEditingController(text: '0');

  String? _categoryId;
  String _categoryName = '';
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  static String _numText(num? v) =>
      (v == null || v == 0) ? '' : v.toString();

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId;
    _categoryName = widget.existing?.categoryName ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _name, _sku, _barcode, _brand, _unit,
      _purchase, _selling, _wholesale, _minStock, _opening,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  num _parse(TextEditingController c) => num.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final actions = ref.read(inventoryActionsProvider);
    final base = (widget.existing ?? const Product(id: '', name: '')).copyWith(
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      barcode: _barcode.text.trim(),
      categoryId: _categoryId,
      categoryName: _categoryName,
      brand: _brand.text.trim(),
      unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
      purchasePrice: _parse(_purchase),
      sellingPrice: _parse(_selling),
      wholesalePrice: _parse(_wholesale),
      minStock: _parse(_minStock),
    );

    try {
      if (_isEdit) {
        await actions.updateProduct(base);
      } else {
        await actions.createProduct(base, openingStock: _parse(_opening));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(accessProvider);
    final showBarcode = access.feature(InventoryFeatures.barcode);
    final showWholesale =
        access.feature(InventoryFeatures.wholesale, defaultValue: true);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'New product')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _field(_name, 'Product name', icon: Icons.label_outline,
                    required: true),
                _field(_sku, 'SKU', icon: Icons.qr_code_2_outlined),
                if (showBarcode) _barcodeField(),
                _CategoryPicker(
                  categoryId: _categoryId,
                  onChanged: (id, name) => setState(() {
                    _categoryId = id;
                    _categoryName = name;
                  }),
                ),
                _field(_brand, 'Brand', icon: Icons.branding_watermark_outlined),
                _field(_unit, 'Unit (pcs, kg, box...)',
                    icon: Icons.straighten),
                const Divider(height: 32),
                _field(_purchase, 'Purchase price',
                    icon: Icons.shopping_cart_outlined, number: true),
                _field(_selling, 'Selling price',
                    icon: Icons.sell_outlined, number: true, required: true),
                if (showWholesale)
                  _field(_wholesale, 'Wholesale price',
                      icon: Icons.store_outlined, number: true),
                _field(_minStock, 'Minimum stock (low-stock alert)',
                    icon: Icons.warning_amber_outlined, number: true),
                if (!_isEdit)
                  _field(_opening, 'Opening stock',
                      icon: Icons.inventory_2_outlined, number: true),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEdit ? 'Save changes' : 'Create product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Barcode field with an optional camera-scan button. Also accepts input
  /// from a USB/Bluetooth scanner when focused (it just types the code in).
  Widget _barcodeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: _barcode,
        decoration: InputDecoration(
          labelText: 'Barcode / QR',
          prefixIcon: const Icon(Icons.barcode_reader),
          helperText: 'Scan with a USB scanner, camera, or type it in',
          suffixIcon: cameraScanSupported()
              ? IconButton(
                  tooltip: 'Scan with camera',
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: () async {
                    final code = await scanWithCamera(context);
                    if (code != null && mounted) {
                      setState(() => _barcode.text = code);
                    }
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    IconData? icon,
    bool number = false,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType:
            number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}

/// Category dropdown backed by the categories collection, with an inline
/// "New category" option that creates one on the fly.
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({required this.categoryId, required this.onChanged});
  final String? categoryId;
  final void Function(String? id, String name) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue:
            categories.any((c) => c.id == categoryId) ? categoryId : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Category',
          prefixIcon: Icon(Icons.category_outlined),
        ),
        items: [
          for (final c in categories)
            DropdownMenuItem(value: c.id, child: Text(c.name)),
          const DropdownMenuItem(value: '__new__', child: Text('➕ New category…')),
        ],
        onChanged: (value) async {
          if (value == '__new__') {
            final name = await _promptName(context);
            if (name != null && name.trim().isNotEmpty) {
              final id =
                  await ref.read(inventoryActionsProvider).createCategory(name);
              onChanged(id, name.trim());
            }
            return;
          }
          final matches = categories.where((c) => c.id == value);
          onChanged(value, matches.isEmpty ? '' : matches.first.name);
        },
      ),
    );
  }

  Future<String?> _promptName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Add')),
        ],
      ),
    );
  }
}
