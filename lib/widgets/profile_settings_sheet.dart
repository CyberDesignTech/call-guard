import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_palette.dart';
import 'common/icon_box.dart';
import 'support_project_dialog.dart';
import 'terms_welcome_dialog.dart';

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
                onTap: () => showAboutAppDialog(context, strings),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconBox(
                  icon: Icons.description_outlined,
                  color: AppPalette.accent(AppPalette.blue),
                  background: AppPalette.bluePale,
                  size: 39,
                ),
                title: Text(
                  strings.call('termsTitle'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => unawaited(
                  TermsWelcomeDialog.show(
                    context,
                    strings: strings,
                    reviewOnly: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
