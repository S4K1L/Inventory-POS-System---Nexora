import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/form_widgets.dart';
import '../../branches/branches_providers.dart';

/// Owner-facing sheet to create an employee login + profile in one step.
class AddEmployeeSheet extends ConsumerStatefulWidget {
  const AddEmployeeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const AddEmployeeSheet(),
      ),
    );
  }

  @override
  ConsumerState<AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends ConsumerState<AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  // Default to the POS-only role, matching the common case.
  String _roleId = Roles.cashier.id;
  String _branchId = '';
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  // Owner can assign any built-in role except Owner.
  List<Role> get _assignableRoles =>
      Roles.all.where((r) => r.id != Roles.owner.id).toList();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(userAdminProvider).addEmployee(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            roleId: _roleId,
            branchId: _branchId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_name.text.trim()} added')));
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final role = Roles.byId(_roleId);
    final branches =
        (ref.watch(branchesProvider).value ?? const []).where((b) => b.active).toList();
    // Default the assigned branch to the first one.
    if (_branchId.isEmpty && branches.isNotEmpty) _branchId = branches.first.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add employee', style: text.titleLarge),
            const SizedBox(height: 2),
            Text('Creates their login and access. You set the first password.',
                style: text.bodySmall),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (their login)',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Temporary password',
                prefixIcon: const Icon(Icons.lock_outline),
                helperText: 'At least 6 characters — share it with them',
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
            const SizedBox(height: AppSpace.md),
            DropdownButtonFormField<String>(
              initialValue: _roleId,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: [
                for (final r in _assignableRoles)
                  DropdownMenuItem(value: r.id, child: Text(r.name)),
              ],
              onChanged: (v) => setState(() => _roleId = v ?? _roleId),
            ),
            if (branches.length > 1) ...[
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<String>(
                initialValue: _branchId.isEmpty ? null : _branchId,
                decoration: const InputDecoration(
                  labelText: 'Assigned branch',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                items: [
                  for (final b in branches)
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => setState(() => _branchId = v ?? _branchId),
              ),
            ],
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.field,
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_roleSummary(role), style: text.bodySmall),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              FormErrorBox(_error!),
            ],
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy ? const ButtonSpinner() : const Text('Add employee'),
            ),
          ],
        ),
      ),
    );
  }

  String _roleSummary(Role role) {
    if (role.id == Roles.cashier.id) {
      return 'Cashier sees only the POS screen — ideal for counter staff.';
    }
    if (role.permissions.contains('*')) {
      return 'Full access to everything.';
    }
    return '${role.name} can access the modules their permissions allow.';
  }
}
