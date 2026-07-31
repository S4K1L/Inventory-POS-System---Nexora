import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_tokens.dart';
import '../../ui/brand_logo.dart';
import '../../ui/form_widgets.dart';
import '../auth_providers.dart';
import '../../company/company_providers.dart';

/// Shown when a signed-in user has no company yet. Creating the company writes
/// the user's profile, which moves the router into the app.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _company.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = ref.read(currentUserProvider);
      await ref.read(companyRepositoryProvider).createCompanyWithOwner(
            ownerUid: user.uid,
            ownerEmail: user.email,
            companyName: _company.text.trim(),
            ownerDisplayName: user.displayName,
          );
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Could not create your business: $e\n\nIf this is a permissions '
            'error, deploy firestore.rules to your Firebase project.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(size: 46)),
                  const SizedBox(height: AppSpace.xxl),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(Icons.storefront,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Text('Set up your business',
                      textAlign: TextAlign.center, style: text.headlineSmall),
                  const SizedBox(height: 6),
                  Text("You'll be the owner. You can rename it later.",
                      textAlign: TextAlign.center, style: text.bodyMedium),
                  const SizedBox(height: AppSpace.xxl),
                  TextFormField(
                    controller: _company,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Business / shop name',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your business name'
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpace.md),
                    FormErrorBox(_error!),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const ButtonSpinner()
                        : const Text('Create business'),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => ref.read(authRepositoryProvider).signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
