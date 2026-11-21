/// Visual mode of the persistent status notification.
enum StatusTrayMode { hidden, active, driving, paused }

/// Persisted user choices and activation state for the status notification.
class StatusTrayPreferences {
  const StatusTrayPreferences({
    this.enabled = true,
    this.userOverridden = false,
    this.activated = false,
    this.permissionPrompted = false,
  });

  final bool enabled;
  final bool userOverridden;
  final bool activated;
  final bool permissionPrompted;

  StatusTrayPreferences copyWith({
    bool? enabled,
    bool? userOverridden,
    bool? activated,
    bool? permissionPrompted,
  }) => StatusTrayPreferences(
    enabled: enabled ?? this.enabled,
    userOverridden: userOverridden ?? this.userOverridden,
    activated: activated ?? this.activated,
    permissionPrompted: permissionPrompted ?? this.permissionPrompted,
  );
}

/// Result of reconciling role, protection, driving, and notification state.
class StatusTrayDecision {
  const StatusTrayDecision({
    required this.preferences,
    required this.mode,
    required this.requestNotificationPermission,
  });

  final StatusTrayPreferences preferences;
  final StatusTrayMode mode;
  final bool requestNotificationPermission;
}

/// Keeps the notification hidden until screening is configured, then preserves
/// its state across protection pauses unless the user explicitly disables it.
///
/// This lifecycle is deliberately separate from native DND ownership: the
/// notification may describe a paused mode without changing system policy.
class StatusTrayLifecycle {
  const StatusTrayLifecycle._();

  /// Computes the next tray state without performing platform or database I/O.
  static StatusTrayDecision reconcile({
    required StatusTrayPreferences current,
    required bool roleGranted,
    required bool protectionEnabled,
    required bool drivingMode,
    required bool notificationsGranted,
  }) {
    var next = current;
    if (roleGranted && protectionEnabled && !next.userOverridden) {
      next = next.copyWith(enabled: true, activated: true);
    } else if (roleGranted && protectionEnabled && next.enabled) {
      next = next.copyWith(activated: true);
    }

    final shouldRequestPermission =
        roleGranted &&
        next.enabled &&
        next.activated &&
        !notificationsGranted &&
        !next.permissionPrompted;
    if (shouldRequestPermission) {
      next = next.copyWith(permissionPrompted: true);
    }

    final visible = roleGranted && next.activated && next.enabled;
    final mode = !visible
        ? StatusTrayMode.hidden
        : !protectionEnabled
        ? StatusTrayMode.paused
        : drivingMode
        ? StatusTrayMode.driving
        : StatusTrayMode.active;
    return StatusTrayDecision(
      preferences: next,
      mode: mode,
      requestNotificationPermission: shouldRequestPermission,
    );
  }

  /// Applies an explicit user toggle and resets the permission prompt on enable.
  static StatusTrayPreferences userChanged(
    StatusTrayPreferences current,
    bool enabled,
  ) => current.copyWith(
    enabled: enabled,
    activated: enabled ? true : current.activated,
    userOverridden: true,
    permissionPrompted: enabled ? false : current.permissionPrompted,
  );
}
