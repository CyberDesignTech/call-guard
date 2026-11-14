import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../platform/call_screening_channel.dart';
import '../theme/app_palette.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/page_intro.dart';
import '../widgets/common/prototype_footnote.dart';
import '../widgets/common/rule_switch.dart';
import '../widgets/common/section_heading.dart';
import '../widgets/common/thin_divider.dart';

class AnsweringModePage extends StatefulWidget {
  const AnsweringModePage({
    required this.strings,
    required this.enabled,
    required this.onEnabledChanged,
    required this.scenario,
    required this.onScenarioChanged,
    required this.localNotification,
    required this.onLocalNotificationChanged,
  });

  final AppStrings strings;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final String scenario;
  final ValueChanged<String> onScenarioChanged;
  final bool localNotification;
  final ValueChanged<bool> onLocalNotificationChanged;

  @override
  State<AnsweringModePage> createState() => _AnsweringModePageState();
}

class _AnsweringModePageState extends State<AnsweringModePage>
    with WidgetsBindingObserver {
  final _screeningChannel = CallScreeningChannel();
  bool _contactsGranted = false;
  bool _notificationsGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    try {
      final permissions = await _screeningChannel.checkPermissions();
      if (!mounted) return;
      setState(() {
        _contactsGranted = permissions.readContacts;
        _notificationsGranted = permissions.notificationsGranted;
      });
    } on PlatformException {
      // Permissions are provided by the Android bridge.
    } on MissingPluginException {
      // Keep the page usable on platforms without the Android bridge.
    }
  }

  Future<void> _requestContactsPermission() async {
    try {
      final permissions = await _screeningChannel.requestContactsPermission();
      if (mounted) setState(() => _contactsGranted = permissions.readContacts);
    } on PlatformException {
      await _refreshPermissions();
    } on MissingPluginException {
      // Contacts access is available only on Android.
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await _screeningChannel.requestNotificationPermission();
    } on PlatformException {
      // Refresh below reflects the effective system setting.
    } on MissingPluginException {
      // Notification access is available only on Android.
    }
    await _refreshPermissions();
  }

  Widget _permissionWarning({
    required String message,
    required String actionLabel,
    required VoidCallback onPressed,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppPalette.amberPale,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppPalette.amber.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 19,
          color: AppPalette.accent(AppPalette.amber),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(color: AppPalette.ink, fontSize: 12),
              ),
              const SizedBox(height: 5),
              TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
    children: [
      PageIntro(
        eyebrow: widget.strings.call('answerEyebrow'),
        title: widget.strings.answerTitle,
        subtitle: widget.strings.call('answerSubtitle'),
      ),
      if (widget.localNotification && !_notificationsGranted) ...[
        const SizedBox(height: 12),
        _permissionWarning(
          message: widget.strings.call(
            'answeringNotificationsPermissionWarning',
          ),
          actionLabel: widget.strings.call('grantNotificationPermission'),
          onPressed: _requestNotificationPermission,
        ),
      ],
      if (widget.scenario == 'unknown_numbers' && !_contactsGranted) ...[
        const SizedBox(height: 12),
        _permissionWarning(
          message: widget.strings.call('answeringContactsPermissionWarning'),
          actionLabel: widget.strings.call('grantContacts'),
          onPressed: _requestContactsPermission,
        ),
      ],
      const SizedBox(height: 18),
      AppPanel(
        child: RuleSwitch(
          icon: Icons.phone_disabled_outlined,
          title: widget.strings.call('answeringEnabledLabel'),
          subtitle: widget.strings.call('answeringEnabledDescription'),
          value: widget.enabled,
          onChanged: widget.onEnabledChanged,
        ),
      ),
      const SizedBox(height: 21),
      SectionHeading(
        title: widget.strings.call('answeringScenarioTitle'),
        subtitle: widget.strings.call('answeringScenarioHint'),
      ),
      const SizedBox(height: 10),
      AppPanel(
        child: RadioGroup<String>(
          groupValue: widget.scenario,
          onChanged: (value) {
            if (value != null) widget.onScenarioChanged(value);
          },
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'quiet_mode',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(widget.strings.call('answeringQuietScenario')),
                secondary: const Icon(Icons.notifications_off_outlined),
                dense: true,
              ),
              const ThinDivider(),
              RadioListTile<String>(
                value: 'unknown_numbers',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(widget.strings.call('answeringUnknownScenario')),
                secondary: const Icon(Icons.person_search_outlined),
                dense: true,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      AppPanel(
        child: RuleSwitch(
          icon: Icons.notifications_active_outlined,
          title: widget.strings.call('answeringNotificationLabel'),
          subtitle: widget.strings.call('answeringNotificationHint'),
          value: widget.localNotification,
          onChanged: widget.onLocalNotificationChanged,
          iconColor: AppPalette.amber,
          iconBackground: AppPalette.amberPale,
        ),
      ),
      const SizedBox(height: 16),
      PrototypeFootnote(label: widget.strings.call('prototypeFootnote')),
    ],
  );
}
