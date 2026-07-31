import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/form_widgets.dart';
import '../domain/customer.dart';
import '../customers_providers.dart';

/// Create or edit a customer. Pass [existing] to edit.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.existing});
  final Customer? existing;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _address =
      TextEditingController(text: widget.existing?.address ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final base = (widget.existing ?? const Customer(id: '', name: '')).copyWith(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      notes: _notes.text.trim(),
    );
    try {
      final actions = ref.read(customerActionsProvider);
      if (_isEdit) {
        await actions.update(base);
      } else {
        await actions.create(base);
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit customer' : 'New customer')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.xl),
              children: [
                _field(_name, 'Customer name',
                    icon: Icons.person_outline, required: true),
                _field(_phone, 'Phone',
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone),
                _field(_email, 'Email',
                    icon: Icons.mail_outline,
                    keyboard: TextInputType.emailAddress),
                _field(_address, 'Address',
                    icon: Icons.location_on_outlined, lines: 2),
                _field(_notes, 'Notes', icon: Icons.notes, lines: 2),
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  FormErrorBox(_error!),
                ],
                const SizedBox(height: AppSpace.xl),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const ButtonSpinner()
                      : Text(_isEdit ? 'Save changes' : 'Add customer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    IconData? icon,
    bool required = false,
    TextInputType? keyboard,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          alignLabelWithHint: lines > 1,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}
