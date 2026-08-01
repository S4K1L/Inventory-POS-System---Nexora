import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/platform_config.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/form_widgets.dart';

/// Admin-editable platform settings: trial length, plan pricing, currency.
class SettingsSection extends ConsumerStatefulWidget {
  const SettingsSection({super.key});

  @override
  ConsumerState<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<SettingsSection> {
  final _demoDays = TextEditingController();
  final _starter = TextEditingController();
  final _pro = TextEditingController();
  final _currency = TextEditingController();
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _demoDays.dispose();
    _starter.dispose();
    _pro.dispose();
    _currency.dispose();
    super.dispose();
  }

  void _fill(PlatformConfig c) {
    _demoDays.text = '${c.demoDays}';
    _starter.text = c.starterPrice == 0 ? '' : '${c.starterPrice}';
    _pro.text = c.proPrice == 0 ? '' : '${c.proPrice}';
    _currency.text = c.currency;
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final config = PlatformConfig(
        demoDays: int.tryParse(_demoDays.text.trim()) ?? 7,
        starterPrice: num.tryParse(_starter.text.trim()) ?? 0,
        proPrice: num.tryParse(_pro.text.trim()) ?? 0,
        currency: _currency.text.trim().isEmpty ? 'BDT' : _currency.text.trim(),
      );
      await ref.read(platformConfigActionsProvider).save(config);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(platformConfigProvider);
    // Populate fields once when config first loads.
    configAsync.whenData((c) {
      if (!_loaded) _fill(c);
    });

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.xl),
          children: [
            Text('Platform settings',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Applies to every tenant. Changes take effect immediately.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpace.lg),
            AppCard(
              child: Column(
                children: [
                  _field(_demoDays, 'Demo trial length (days)',
                      Icons.timelapse_outlined),
                  const SizedBox(height: AppSpace.md),
                  _field(_starter, 'Starter price / month',
                      Icons.sell_outlined),
                  const SizedBox(height: AppSpace.md),
                  _field(_pro, 'Pro price / month', Icons.workspace_premium_outlined),
                  const SizedBox(height: AppSpace.md),
                  _field(_currency, 'Currency code', Icons.attach_money,
                      number: false),
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
              child: _busy ? const ButtonSpinner() : const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool number = true}) {
    return TextField(
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
