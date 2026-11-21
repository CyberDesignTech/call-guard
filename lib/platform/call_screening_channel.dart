import 'package:flutter/services.dart';

import '../models/recent_call_log_entry.dart';

/// Android permission and call-screening-role state returned over the bridge.
class CallScreeningPermissions {
  const CallScreeningPermissions({
    required this.roleAvailable,
    required this.callScreeningRole,
    required this.readContacts,
    required this.notificationsGranted,
  });

  final bool roleAvailable;
  final bool callScreeningRole;
  final bool readContacts;
  final bool notificationsGranted;

  factory CallScreeningPermissions.fromMap(Map<String, Object?>? values) =>
      CallScreeningPermissions(
        roleAvailable: values?['roleAvailable'] == true,
        callScreeningRole: values?['callScreeningRole'] == true,
        readContacts: values?['readContacts'] == true,
        notificationsGranted: values?['notificationsGranted'] == true,
      );
}

/// Normalized verdict payload shared by native simulation and Dart UI code.
class CallSimulationVerdict {
  const CallSimulationVerdict({
    required this.allowed,
    required this.reason,
    required this.phoneNumber,
  });

  final bool allowed;
  final String reason;
  final String phoneNumber;

  factory CallSimulationVerdict.fromMap(Map<String, Object?> values) =>
      CallSimulationVerdict(
        allowed: values['verdict'] == 'ALLOW',
        reason: values['reason'] as String? ?? 'unknown',
        phoneNumber: values['phoneNumber'] as String? ?? '',
      );
}

class ContactPickerResult {
  const ContactPickerResult({
    this.permissionRequired = false,
    this.name,
    this.phone,
  });

  final bool permissionRequired;
  final String? name;
  final String? phone;

  factory ContactPickerResult.fromMap(Map<String, Object?> values) =>
      ContactPickerResult(
        permissionRequired: values['permissionRequired'] == true,
        name: values['name'] as String?,
        phone: values['phone'] as String?,
      );
}

/// Typed facade over the Flutter-to-Android MethodChannel.
///
/// Native Android owns telecom, DND, notification, contact, and alarm APIs;
/// Dart owns presentation and persists user settings through [DatabaseHelper].
class CallScreeningChannel {
  CallScreeningChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.wepr.callguard/screening');

  final MethodChannel _channel;
  Future<bool> Function()? _openCallJournalHandler;
  Future<void> Function()? _statusModesChangedHandler;
  Future<void> Function()? _callHandledHandler;

  /// Reads the current system role and permission state without prompting.
  Future<CallScreeningPermissions> checkPermissions() async =>
      CallScreeningPermissions.fromMap(
        await _channel.invokeMapMethod<String, Object?>('checkPermissions'),
      );

  Future<CallScreeningPermissions> requestCallScreeningRole() async =>
      CallScreeningPermissions.fromMap(
        await _channel.invokeMapMethod<String, Object?>(
          'requestCallScreeningRole',
        ),
      );

  Future<void> openDefaultAppsSettings() async {
    await _channel.invokeMethod<bool>('openDefaultAppsSettings');
  }

  Future<RecentCallLogResult> getRecentCallLog({int limit = 50}) async =>
      RecentCallLogResult.fromMap(
        await _channel.invokeMapMethod<String, Object?>('getRecentCallLog', {
              'limit': limit,
            }) ??
            const <String, Object?>{},
      );

  Future<void> openCallLogSettings() async {
    await _channel.invokeMethod<bool>('openCallLogSettings');
  }

  Future<ContactPickerResult?> pickContact() async {
    final values = await _channel.invokeMapMethod<String, Object?>(
      'pickContact',
    );
    return values == null ? null : ContactPickerResult.fromMap(values);
  }

  Future<String?> lookupContactName(String phoneNumber) async => _channel
      .invokeMethod<String>('lookupContactName', {'phoneNumber': phoneNumber});

  Future<CallScreeningPermissions> requestContactsPermission() async =>
      CallScreeningPermissions.fromMap(
        await _channel.invokeMapMethod<String, Object?>(
          'requestContactsPermission',
        ),
      );

  Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ??
      false;

  Future<void> openNotificationSettings() async {
    await _channel.invokeMethod<bool>('openNotificationSettings');
  }

  Future<bool> isDndPolicyAccessGranted() async =>
      await _channel.invokeMethod<bool>('isDndPolicyAccessGranted') ?? false;

  Future<bool> openDndPolicyAccessSettings() async =>
      await _channel.invokeMethod<bool>('openDndPolicyAccessSettings') ?? false;

  /// Requests native reconciliation of CallGate modes with Android DND.
  Future<bool> syncDndState() async =>
      await _channel.invokeMethod<bool>('syncDndState') ?? false;

  Future<void> updateStatusIndicator({
    required bool enabled,
    required bool protectionEnabled,
    required bool drivingMode,
    required String locale,
  }) async {
    await _channel.invokeMethod<bool>('updateStatusIndicator', {
      'enabled': enabled,
      'protectionEnabled': protectionEnabled,
      'drivingMode': drivingMode,
      'locale': locale,
    });
  }

  Future<bool> consumePendingCallJournal() async =>
      await _channel.invokeMethod<bool>('consumePendingCallJournal') ?? false;

  void setOpenCallJournalHandler(Future<bool> Function() handler) {
    _openCallJournalHandler = handler;
    _installMethodCallHandler();
  }

  void setStatusModesChangedHandler(Future<void> Function() handler) {
    _statusModesChangedHandler = handler;
    _installMethodCallHandler();
  }

  void setCallHandledHandler(Future<void> Function() handler) {
    _callHandledHandler = handler;
    _installMethodCallHandler();
  }

  void _installMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openCallJournal') {
        return await _openCallJournalHandler?.call() ?? false;
      }
      if (call.method == 'statusModesChanged') {
        await _statusModesChangedHandler?.call();
        return true;
      }
      if (call.method == 'callHandled') {
        await _callHandledHandler?.call();
        return true;
      }
      return null;
    });
  }

  Future<void> scheduleReminder({
    required int id,
    required int remindAt,
  }) async {
    await _channel.invokeMethod<bool>('scheduleReminder', {
      'id': id,
      'remindAt': remindAt,
    });
  }

  Future<void> cancelReminder(int id) async {
    await _channel.invokeMethod<bool>('cancelReminder', {'id': id});
  }

  Future<void> restorePendingReminders() async {
    await _channel.invokeMethod<bool>('restorePendingReminders');
  }

  Future<void> openDialer(String phoneNumber) async {
    await _channel.invokeMethod<bool>('openDialer', {
      'phoneNumber': phoneNumber,
    });
  }

  Future<bool> openExternalUrl(String url) async {
    return await _channel.invokeMethod<bool>('openExternalUrl', {'url': url}) ??
        false;
  }

  Future<CallSimulationVerdict> simulateCall(String phoneNumber) async {
    final values = await _channel.invokeMapMethod<String, Object?>(
      'simulateCall',
      {'phoneNumber': phoneNumber},
    );
    if (values == null) {
      throw PlatformException(
        code: 'EMPTY_VERDICT',
        message: 'The native call-rule engine returned no verdict.',
      );
    }
    return CallSimulationVerdict.fromMap(values);
  }
}
