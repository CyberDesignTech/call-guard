import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../platform/call_screening_channel.dart';
import '../theme/app_palette.dart';
import 'common/icon_box.dart';

/// Opens the shared "Support the project" dialog from the profile menu or the
/// bottom info banner.
Future<void> showSupportProjectDialog(
  BuildContext context,
  AppStrings strings,
) {
  final channel = CallScreeningChannel();
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
              title: strings.call('supportKofiTitle'),
              description: strings.call('supportKofiDescription'),
              color: AppPalette.amber,
              onTap: () async {
                await channel.openExternalUrl('https://ko-fi.com/O4F42APP5S');
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
            ),
            const SizedBox(height: 10),
            _SupportOption(
              icon: Icons.share_outlined,
              title: strings.call('supportShareTitle'),
              description: strings.call('supportShareDescription'),
              color: AppPalette.blue,
              onTap: () => _copyProjectLink(context, dialogContext, strings),
            ),
            const SizedBox(height: 10),
            _SupportOption(
              icon: Icons.star_rounded,
              title: strings.call('rateAppTitle'),
              description: strings.call('rateAppDescription'),
              color: AppPalette.amber,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (_) => Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppPalette.accent(AppPalette.amber),
                  ),
                ),
              ),
              onTap: () async {
                final opened = await channel.openExternalUrl(
                  'market://details?id=com.wepr.callguard',
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(strings.call('playStoreSoon'))),
                    );
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(strings.call('closeLabel')),
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
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
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
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    ),
  );
}