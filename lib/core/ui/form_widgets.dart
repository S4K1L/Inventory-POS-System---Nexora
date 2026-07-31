import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A soft, bordered inline error box for forms.
class FormErrorBox extends StatelessWidget {
  const FormErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: AppRadius.field,
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style:
                    TextStyle(color: scheme.onErrorContainer, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// White spinner sized for use inside a FilledButton.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}
