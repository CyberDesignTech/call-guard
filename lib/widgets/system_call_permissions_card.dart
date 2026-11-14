import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../platform/call_screening_channel.dart';
import '../theme/app_palette.dart';
import 'common/app_panel.dart';
import 'common/icon_box.dart';
import 'common/thin_divider.dart';

class SystemCallPermissionsCard extends StatefulWidget {
  const SystemCallPermissionsCard({required this.strings});

  final AppStrings strings;

  @override
  State<SystemCallPermissionsCard> createState() =>
      SystemCallPermissionsCardState();
}

class SystemCallPermissionsCardState extends State<SystemCallPermissionsCard>
    with WidgetsBindingObserver {
  final _channel = CallScreeningChannel();
  CallScreeningPermissions _permissions = const CallScreeningPermissions(
    roleAvailable: false,
    callScreeningRole: false,
    readContacts: false,
    notificationsGranted: false,
  );
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final permissions = await _channel.checkPermissions();
      if (!mounted) return;
      setState(() {
        _permissions = permissions;
        _loading = false;
        _hasError = false;
      });
      if (permissions.notificationsGranted) {
        unawaited(_restoreReminderAlarms());
      }
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _requestRole() async {
    try {
      await _channel.requestCallScreeningRole();
    } on PlatformException {
      // Refresh below to show the actual role state after a denial or failure.
    } on MissingPluginException {
      // The native implementation is Android-only.
    }
    await _refresh();
  }

  Future<void> _openDefaultAppsSettings() async {
    try {
      await _channel.openDefaultAppsSettings();
    } on PlatformException {
      if (!mounted) return;
      setState(() => _hasError = true);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  Widget _roleManagementButton() => PopupMenuButton<String>(
    tooltip: widget.strings.call('changeRevokeRole'),
    onSelected: (action) {
      if (action == 'request') {
        unawaited(_requestRole());
      } else {
        unawaited(_openDefaultAppsSettings());
      }
    },
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'request',
        child: Text(widget.strings.call('requestRoleAgain')),
      ),
      PopupMenuItem(
        value: 'settings',
        child: Text(widget.strings.call('defaultAppsSettings')),
      ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.strings.call('changeRevokeRole'),
            style: TextStyle(
              color: AppPalette.accent(AppPalette.blue),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded, size: 18),
        ],
      ),
    ),
  );

  Future<void> _requestContacts() async {
    try {
      await _channel.requestContactsPermission();
    } on PlatformException {
      // Refresh below to show the actual permission state.
    } on MissingPluginException {
      // The native implementation is Android-only.
    }
    await _refresh();
  }

  Future<void> _requestNotifications() async {
    try {
      await _channel.requestNotificationPermission();
    } on PlatformException {
      // The status refresh below presents the actual system setting.
    } on MissingPluginException {
      // Notifications permission requests are Android-only.
    }
    await _refresh();
  }

  Future<void> _restoreReminderAlarms() async {
    try {
      await _channel.restorePendingReminders();
    } on PlatformException {
      // Keep the permission card responsive if alarm restoration fails.
    } on MissingPluginException {
      // Alarm restoration is Android-only.
    }
  }

  Widget _permissionRow({
    required IconData icon,
    required String title,
    required bool granted,
    required String grantedLabel,
    required String actionLabel,
    required VoidCallback onRequest,
    String? missingLabel,
    Widget? grantedAction,
    bool unavailable = false,
  }) {
    final color = granted ? AppPalette.green : AppPalette.amber;
    return Row(
      children: [
        IconBox(
          icon: icon,
          color: color,
          background: AppPalette.accentSurface(color),
          size: 38,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                _loading
                    ? widget.strings.call('checkingPermissions')
                    : granted
                    ? grantedLabel
                    : unavailable
                    ? widget.strings.call('roleUnavailable')
                    : widget.strings.call(missingLabel ?? 'roleMissing'),
                style: TextStyle(color: AppPalette.muted, fontSize: 10),
              ),
            ],
          ),
        ),
        if (_loading)
          Icon(Icons.sync_rounded, color: AppPalette.muted, size: 20)
        else if (granted && grantedAction != null)
          grantedAction
        else if (!granted && !unavailable)
          TextButton(
            onPressed: onRequest,
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          )
        else
          Icon(
            granted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: granted ? AppPalette.green : AppPalette.muted,
            size: 20,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AppPanel(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.strings.call('screeningStatusTitle'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _permissionRow(
            icon: Icons.shield_outlined,
            title: widget.strings.call('systemRoleLabel'),
            granted: _permissions.callScreeningRole,
            grantedLabel: widget.strings.call('roleGranted'),
            actionLabel: widget.strings.call('grantRole'),
            onRequest: _requestRole,
            grantedAction: _roleManagementButton(),
            unavailable: !_permissions.roleAvailable && !_loading,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: ThinDivider(),
          ),
          _permissionRow(
            icon: Icons.contacts_outlined,
            title: widget.strings.call('contactsLabel'),
            granted: _permissions.readContacts,
            grantedLabel: widget.strings.call('contactsGranted'),
            actionLabel: widget.strings.call('grantContacts'),
            onRequest: _requestContacts,
            missingLabel: 'contactsMissing',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: ThinDivider(),
          ),
          _permissionRow(
            icon: Icons.notifications_active_outlined,
            title: widget.strings.call('notificationPermissionLabel'),
            granted: _permissions.notificationsGranted,
            grantedLabel: widget.strings.call('notificationsGranted'),
            actionLabel: widget.strings.call('grantNotificationPermission'),
            onRequest: _requestNotifications,
            missingLabel: 'notificationsMissing',
          ),
          if (_hasError) ...[
            const SizedBox(height: 8),
            Text(
              widget.strings.call('permissionCheckError'),
              style: TextStyle(
                color: AppPalette.accent(AppPalette.red),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
