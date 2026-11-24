import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../platform/call_screening_channel.dart';

class TermsWelcomeDialog extends StatefulWidget {
  const TermsWelcomeDialog({required this.strings, this.reviewOnly = false});

  final AppStrings strings;
  final bool reviewOnly;

  static Future<bool?> show(
    BuildContext context, {
    required AppStrings strings,
    bool reviewOnly = false,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: reviewOnly,
    builder: (_) =>
        TermsWelcomeDialog(strings: strings, reviewOnly: reviewOnly),
  );

  @override
  State<TermsWelcomeDialog> createState() => _TermsWelcomeDialogState();
}

class _TermsWelcomeDialogState extends State<TermsWelcomeDialog> {
  bool _allowPop = false;

  Future<void> _openPrivacyPolicy() async {
    try {
      await CallScreeningChannel().openExternalUrl(
        'https://www.cyberdesigntech.link/privacy.html',
      );
    } on PlatformException {
      // The terms remain available if no browser can open the policy.
    } on MissingPluginException {
      // The external-link bridge is Android-specific.
    }
  }

  void _close({required bool accepted}) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(accepted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final colors = Theme.of(context).colorScheme;
    return PopScope<Object?>(
      canPop: widget.reviewOnly || _allowPop,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        icon: Icon(Icons.shield_outlined, color: colors.primary, size: 32),
        title: Text(strings.call('termsTitle'), textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TermsPoint(
                icon: Icons.storage_rounded,
                title: strings.call('termsLocalityTitle'),
                description: strings.call('termsLocalityBody'),
              ),
              const SizedBox(height: 14),
              _TermsPoint(
                icon: Icons.tune_rounded,
                title: strings.call('termsModesTitle'),
                description: strings.call('termsModesBody'),
              ),
              const SizedBox(height: 14),
              _TermsPoint(
                icon: Icons.settings_suggest_outlined,
                title: strings.call('termsAndroidTitle'),
                description: strings.call('termsAndroidBody'),
              ),
              const SizedBox(height: 14),
              _TermsPoint(
                icon: Icons.phone_in_talk_rounded,
                title: strings.call('termsEmergencyTitle'),
                description: strings.call('termsEmergencyBody'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _openPrivacyPolicy,
                  icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                  label: Text(strings.call('privacyPolicy')),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => _close(accepted: !widget.reviewOnly),
            child: Text(
              widget.reviewOnly
                  ? strings.call('closeLabel')
                  : strings.call('termsAcceptContinue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsPoint extends StatelessWidget {
  const _TermsPoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary, size: 21),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
