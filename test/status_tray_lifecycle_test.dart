import 'package:flutter_test/flutter_test.dart';

import 'package:call_guard/platform/status_tray_lifecycle.dart';

void main() {
  const defaults = StatusTrayPreferences();

  test('tray stays hidden until the screening role is granted', () {
    final decision = StatusTrayLifecycle.reconcile(
      current: defaults,
      roleGranted: false,
      protectionEnabled: true,
      drivingMode: false,
      notificationsGranted: true,
    );

    expect(decision.mode, StatusTrayMode.hidden);
    expect(decision.preferences.activated, isFalse);
    expect(decision.requestNotificationPermission, isFalse);
  });

  test('role grant auto-enables the tray when protection is on', () {
    final decision = StatusTrayLifecycle.reconcile(
      current: defaults,
      roleGranted: true,
      protectionEnabled: true,
      drivingMode: false,
      notificationsGranted: true,
    );

    expect(decision.mode, StatusTrayMode.active);
    expect(decision.preferences.enabled, isTrue);
    expect(decision.preferences.activated, isTrue);
  });

  test('driving mode and paused protection reuse the same tray entry', () {
    final driving = StatusTrayLifecycle.reconcile(
      current: defaults,
      roleGranted: true,
      protectionEnabled: true,
      drivingMode: true,
      notificationsGranted: true,
    );
    expect(driving.mode, StatusTrayMode.driving);
    expect(driving.preferences.enabled, isTrue);

    final paused = StatusTrayLifecycle.reconcile(
      current: driving.preferences,
      roleGranted: true,
      protectionEnabled: false,
      drivingMode: false,
      notificationsGranted: true,
    );
    expect(paused.mode, StatusTrayMode.paused);
    expect(paused.preferences.enabled, isTrue);
  });

  test('a manual disable survives role and protection changes', () {
    final disabled = StatusTrayLifecycle.userChanged(defaults, false);
    expect(disabled.userOverridden, isTrue);

    final afterRole = StatusTrayLifecycle.reconcile(
      current: disabled,
      roleGranted: true,
      protectionEnabled: true,
      drivingMode: false,
      notificationsGranted: true,
    );
    expect(afterRole.mode, StatusTrayMode.hidden);
    expect(afterRole.preferences.enabled, isFalse);

    final paused = StatusTrayLifecycle.reconcile(
      current: disabled,
      roleGranted: true,
      protectionEnabled: false,
      drivingMode: false,
      notificationsGranted: true,
    );
    expect(paused.mode, StatusTrayMode.hidden);
  });

  test('notification permission is requested only once', () {
    final first = StatusTrayLifecycle.reconcile(
      current: defaults,
      roleGranted: true,
      protectionEnabled: true,
      drivingMode: false,
      notificationsGranted: false,
    );
    expect(first.requestNotificationPermission, isTrue);
    expect(first.preferences.permissionPrompted, isTrue);

    final second = StatusTrayLifecycle.reconcile(
      current: first.preferences,
      roleGranted: true,
      protectionEnabled: true,
      drivingMode: false,
      notificationsGranted: false,
    );
    expect(second.requestNotificationPermission, isFalse);
  });

  test('manual enable resets the permission prompt for a fresh request', () {
    final prompted = defaults.copyWith(permissionPrompted: true);
    final enabled = StatusTrayLifecycle.userChanged(prompted, true);

    expect(enabled.enabled, isTrue);
    expect(enabled.activated, isTrue);
    expect(enabled.userOverridden, isTrue);
    expect(enabled.permissionPrompted, isFalse);
  });

  test('manual enable shows the paused state while protection is off', () {
    final decision = StatusTrayLifecycle.reconcile(
      current: StatusTrayLifecycle.userChanged(defaults, true),
      roleGranted: true,
      protectionEnabled: false,
      drivingMode: false,
      notificationsGranted: true,
    );

    expect(decision.mode, StatusTrayMode.paused);
    expect(decision.preferences.enabled, isTrue);
  });
}
