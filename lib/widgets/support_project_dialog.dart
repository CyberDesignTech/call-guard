import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../platform/call_screening_channel.dart';
import '../theme/app_palette.dart';
import 'common/shield_phone_logo.dart';

Future<void> showAboutAppDialog(BuildContext context, AppStrings strings) {
  final channel = CallScreeningChannel();
  Future<void> openUrl(String url) async {
    try {
      await channel.openExternalUrl(url);
    } on PlatformException {
      // Keep the dialog available if Android cannot open the URL.
    } on MissingPluginException {
      // External URLs are provided by the Android method channel.
    }
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const ShieldPhoneLogo(size: 76),
      title: const Text('Call Gate'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${strings.call('versionLabel')}  v2.6.0',
              style: TextStyle(
                color: AppPalette.accent(AppPalette.blue),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              strings.call('aboutDescription'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              strings.call('aboutPrivacy'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.ink, fontSize: 12),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_rounded),
              title: Text(strings.call('developerWebsite')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => openUrl('https://www.cyberdesigntech.link/'),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code_rounded),
              title: Text(strings.call('projectGithub')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () =>
                  openUrl('https://github.com/CyberDesignTech/call-guard'),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(strings.call('privacyPolicy')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () =>
                  openUrl('https://www.cyberdesigntech.link/privacy.html'),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(strings.call('aboutHelpFaq')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => openUrl('https://www.cyberdesigntech.link/#faq'),
            ),
            const SizedBox(height: 8),
            Text(
              strings.call('copyrightLine'),
              textAlign: TextAlign.center,
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.7),
              ),
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
