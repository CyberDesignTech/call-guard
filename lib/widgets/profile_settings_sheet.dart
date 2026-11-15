import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../theme/app_palette.dart';
import 'common/icon_box.dart';
import 'common/shield_phone_logo.dart';

class ProfileSettingsSheet extends StatefulWidget {
  const ProfileSettingsSheet({
    required this.language,
    required this.themeMode,
    required this.strings,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
  });

  final AppLanguage language;
  final ThemeMode themeMode;
  final AppStrings strings;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ProfileSettingsSheet> createState() => ProfileSettingsSheetState();
}

class ProfileSettingsSheetState extends State<ProfileSettingsSheet> {
  late AppLanguage _language = widget.language;
  late ThemeMode _themeMode = widget.themeMode;

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const ShieldPhoneLogo(size: 76),
        title: const Text('Call Gate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.strings.call('versionLabel')}  v1.6.0',
              style: TextStyle(
                color: AppPalette.accent(AppPalette.blue),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.strings.call('aboutDescription'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppPalette.bluePale,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 19,
                    color: AppPalette.accent(AppPalette.blue),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      widget.strings.call('aboutPrivacy'),
                      style: TextStyle(color: AppPalette.ink, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(widget.strings.call('closeLabel')),
          ),
        ],
      ),
    );
  }

  Future<void> _copyProjectLink(BuildContext dialogContext) async {
    await Clipboard.setData(
      const ClipboardData(
        text: 'https://github.com/CyberDesignTech/call-guard',
      ),
    );
    if (!mounted) return;
    Navigator.pop(dialogContext);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(widget.strings.call('linkCopied'))),
      );
  }

  void _showSupport() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.favorite_rounded,
          color: AppPalette.accent(AppPalette.red),
        ),
        title: Text(widget.strings.call('supportProject')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.strings.call('supportThanks'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _SupportOption(
                icon: Icons.coffee_outlined,
                title: widget.strings.call('supportCoffeeTitle'),
                description: widget.strings.call('supportCoffeeDescription'),
                color: AppPalette.amber,
              ),
              const SizedBox(height: 10),
              _SupportOption(
                icon: Icons.share_outlined,
                title: widget.strings.call('supportShareTitle'),
                description: widget.strings.call('supportShareDescription'),
                color: AppPalette.blue,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(widget.strings.call('closeLabel')),
          ),
          FilledButton.icon(
            onPressed: () => _copyProjectLink(dialogContext),
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: Text(widget.strings.call('copyLink')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_language);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppPalette.bluePale,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppPalette.accent(AppPalette.blue),
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.call('profileTitle'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.call('profileSubtitle'),
                          style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                strings.call('languageTitle'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              RadioGroup<AppLanguage>(
                groupValue: _language,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _language = value);
                  widget.onLanguageChanged(value);
                },
                child: Column(
                  children: AppLanguage.values
                      .map(
                        (language) => RadioListTile<AppLanguage>(
                          value: language,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppPalette.accent(AppPalette.blue),
                          title: Text(
                            '${language.flag}  ${language.label}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Divider(height: 22),
              Text(
                strings.call('themeTitle'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              RadioGroup<ThemeMode>(
                groupValue: _themeMode,
                onChanged: (mode) {
                  if (mode == null) return;
                  setState(() => _themeMode = mode);
                  widget.onThemeModeChanged(mode);
                },
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.call('themeSystem')),
                      secondary: const Icon(Icons.brightness_auto_outlined),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.call('themeLight')),
                      secondary: const Icon(Icons.light_mode_outlined),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.call('themeDark')),
                      secondary: const Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconBox(
                  icon: Icons.info_outline_rounded,
                  color: AppPalette.blue,
                  background: AppPalette.bluePale,
                  size: 39,
                ),
                title: Text(
                  strings.call('aboutApp'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showAbout,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconBox(
                  icon: Icons.favorite_outline_rounded,
                  color: AppPalette.red,
                  background: AppPalette.redPale,
                  size: 39,
                ),
                title: Text(
                  strings.call('supportProject'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showSupport,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
