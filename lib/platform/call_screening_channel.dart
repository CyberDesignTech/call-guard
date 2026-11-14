import 'package:flutter/services.dart';

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

class CallScreeningChannel {
  CallScreeningChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.wepr.callguard/screening');

  final MethodChannel _channel;

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

  Future<ContactPickerResult?> pickContact() async {
    final values = await _channel.invokeMapMethod<String, Object?>(
      'pickContact',
    );
    return values == null ? null : ContactPickerResult.fromMap(values);
  }

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
