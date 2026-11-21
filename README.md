# CallGate

**CallGate v2.5.0** is an offline Android call-screening application that
filters incoming calls, synchronizes selected quiet modes with Android Do Not
Disturb, and keeps all settings and history on the device.

[![Version](https://img.shields.io/badge/version-2.5.0-4c8bf5.svg)](https://github.com/CyberDesignTech/call-guard/releases/latest)
![Platform](https://img.shields.io/badge/platform-Android%2010%2B%20(API%2029%2B)-34a853.svg)
![Architecture](https://img.shields.io/badge/architecture-arm64--v8a-fbbc04.svg)
![Privacy](https://img.shields.io/badge/privacy-100%25%20offline%20%7C%20zero%20telemetry-673ab7.svg)
[![License](https://img.shields.io/badge/license-MIT-e91e63.svg)](LICENSE)

## Download Latest APK

Download the latest release from:

- [GitHub Releases](https://github.com/CyberDesignTech/call-guard/releases/latest)
- [CallGate-2.5.0.apk](release/CallGate-2.5.0.apk) from this repository

The APK targets Android 10 (API 29) and newer and is built for
`arm64-v8a`. To install it, download the APK, allow installation from the
selected file manager or browser when Android asks, and open the app. Android
will guide you through granting the call-screening role and optional
permissions.

## Key Features

- **Priority-based call filtering** powered by Android
  `CallScreeningService`.
- Emergency service numbers bypass user-configured blocking rules.
- Allowlist, blocklist, country and operator rules, temporary rules, hidden
  number filtering, short-number handling, and international-call filtering.
- Four status-bar notification states: active protection, Driving Mode, Silence
  Mode, and paused protection.
- **Messenger Silence Mode** through Android
  `NotificationManager.Policy`, covering notifications from apps such as
  Telegram, WhatsApp, Viber, and Signal without reading their content.
- Built-in call-rule simulator for testing local settings.
- Local blocked-call journal and callback reminders.
- Six UI languages: `uk`, `en`, `pl`, `de`, `es`, and `fr`.

## Screenshots

Screenshots can be added under `docs/screenshots/` using the following
placeholders:

| Screen | File |
| --- | --- |
| Home and protection status | `docs/screenshots/home.png` |
| Call lists and country rules | `docs/screenshots/lists.png` |
| Silence and DND settings | `docs/screenshots/silence-mode.png` |
| Local call journal | `docs/screenshots/call-journal.png` |

## Privacy & Security

- **100% offline:** settings, lists, contacts lookups, and call history remain
  on the device.
- **Zero telemetry:** CallGate has no account, analytics service, cloud
  backend, or remote synchronization.
- CallGate does **not** declare
  `BIND_NOTIFICATION_LISTENER_SERVICE` and does **not** use
  `AccessibilityService`.
- The app uses Android's protected `BIND_SCREENING_SERVICE` boundary for call
  screening.
- If the local SQLite database is unavailable while evaluating a call, the
  rule engine fails open and allows the call rather than risking accidental
  blocking.
- Permissions are explicit and optional where possible:
  `READ_CONTACTS`, `READ_CALL_LOG`, `POST_NOTIFICATIONS`,
  `ACCESS_NOTIFICATION_POLICY`, `SCHEDULE_EXACT_ALARM`,
  `RECEIVE_BOOT_COMPLETED`, and `WAKE_LOCK`.
- Signing keys, passwords, local SDK paths, environment files, and build
  outputs are excluded from Git by `.gitignore`.

## Architecture Overview

```text
Flutter UI (lib/)
  ├─ settings, localization, lists, journal, simulator
  ├─ DatabaseHelper / sqflite
  └─ typed MethodChannel facade

Android Kotlin
  ├─ MainActivity              Flutter bridge and permission flows
  ├─ CallGuardScreeningService cold call-screening entry point
  ├─ CallRuleEngine             priority-based native rule evaluation
  ├─ DndSyncController           NotificationManager.Policy ownership
  ├─ CallGuardDatabase           shared SQLite access and migrations
  └─ receivers / schedulers      alarms, boot recovery, notifications
```

The Flutter database helper and native database layer share the same SQLite
file and setting keys. The native screening service remains independent of
Flutter startup so it can respond quickly during an incoming call.

## Building from Source

### Requirements

- Flutter SDK compatible with the version in `pubspec.yaml`
- Android SDK with API 29 or newer
- JDK 17
- Android device or emulator for runtime validation

Clone the repository and run:

```sh
git clone https://github.com/CyberDesignTech/call-guard.git
cd call-guard

flutter pub get
flutter analyze
flutter test

cd android
./gradlew :app:testDebugUnitTest :app:lintDebug
cd ..

flutter build apk --release --target-platform android-arm64
```

The unsigned or locally signed output is written to
`build/app/outputs/flutter-apk/app-release.apk`.

For a production release, keep `android/key.properties` and the signing
keystore outside version control. The repository intentionally contains no
release credentials.

## Documentation & Support

- [Official website](https://www.cyberdesigntech.link/)
- [FAQ](https://www.cyberdesigntech.link/#faq)
- [GitHub Issues](https://github.com/CyberDesignTech/call-guard/issues)

## License

CallGate is released under the [MIT License](LICENSE).
