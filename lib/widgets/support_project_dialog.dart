import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../theme/app_palette.dart';
import 'common/icon_box.dart';

/// Opens the shared "Support the project" dialog from the profile menu or the
/// bottom info banner.
Future<void> showSupportProjectDialog(
  BuildContext context,
  AppStrings strings,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        Icons.favorite_rounded,
        color: AppPalette.accent(AppPalette.red),
      ),
      title: Text(strings.call('supportProject')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.call('supportThanks'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _SupportOption(
              icon: Icons.coffee_outlined,
              title: strings.call('supportCoffeeTitle'),
              description: strings.call('supportCoffeeDescription'),
              color: AppPalette.amber,
            ),
            const SizedBox(height: 10),
            _SupportOption(
              icon: Icons.share_outlined,
              title: strings.call('supportShareTitle'),
              description: strings.call('supportShareDescription'),
              color: AppPalette.blue,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(strings.call('closeLabel')),
        ),
        FilledButton.icon(
          onPressed: () => _copyProjectLink(context, dialogContext, strings),
          icon: const Icon(Icons.copy_rounded, size: 17),
          label: Text(strings.call('copyLink')),
        ),
      ],
    ),
  );
}

Future<void> _copyProjectLink(
  BuildContext context,
  BuildContext dialogContext,
  AppStrings strings,
) async {
  await Clipboard.setData(
    const ClipboardData(text: 'https://github.com/CyberDesignTech/call-guard'),
  );
  if (!dialogContext.mounted) return;
  Navigator.pop(dialogContext);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(strings.call('linkCopied'))));
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppPalette.line),
    ),
    child: Row(
      children: [
        IconBox(
          icon: icon,
          color: color,
          background: AppPalette.accentSurface(color),
          size: 39,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(color: AppPalette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
