# CallGate

**CallGate v2.5.0** — локальний фільтр вхідних дзвінків для Android. Керуйте правилами, тишею та блокуваннями без акаунта й власного серверного бекенду.

## Можливості

- Білий і чорний списки, тимчасові правила та фільтри країн і операторів.
- Фільтр коротких/службових номерів довжиною 2–6 цифр із винятками для контактів і Білого списку.
- Безумовний дозвіл екстрених кодів `101–104`, `112`, `911` і `999`.
- Блокування прихованих номерів, невідомих контактів і міжнародних викликів.
- Режим «За кермом», ручна тиша та розклад із вибором днів і режимом «Лише білий список».
- Керування режимами захисту й водіння зі сповіщення в системній шторці.
- Журнал блокувань, нагадування передзвонити та повторний дзвінок у режимі тиші.
- Інтерфейс українською, англійською, польською, німецькою, іспанською та французькою.

Контакти, правила й журнал зберігаються локально в SQLite на пристрої. Серверного акаунта чи синхронізації CallGate не має.

## Вимоги

- Android 10 (API 29) або новіший.
- Системна роль фільтрації дзвінків (`CallScreeningService`), яку користувач надає в Android.
- Для розробки: Flutter SDK, Android SDK та JDK 17 (версії Android Gradle Plugin/Kotlin задаються проєктом).

## Збірка та перевірки

З кореня репозиторію:

```sh
/home/wepr/flutter/bin/flutter pub get
/home/wepr/flutter/bin/flutter analyze
/home/wepr/flutter/bin/flutter test
cd android
./gradlew :app:testDebugUnitTest :app:lintDebug
cd ..
/home/wepr/flutter/bin/flutter build apk --release --target-platform android-arm64
```

Зібраний APK з’явиться у `build/app/outputs/flutter-apk/app-release.apk`.

### Підпис release APK

Production-підпис налаштовується локальним файлом `android/key.properties` і keystore-файлом. Обидва ігноруються Git — **не додавайте їх у коміт і не передавайте паролі**.

Структура `android/key.properties`:

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=callgate
storeFile=/absolute/path/to/callgate-release.jks
```

Release збірка використовує alias `callgate`, якщо `android/key.properties` присутній. Для стороннього середовища без цього файла передбачений debug-signing fallback; такі APK не призначені для публікації.

## Архітектура

- **Flutter / Dart (`lib/`)** — інтерфейс, локалізація, налаштування, екрани списків і журналу, симулятор правил.
- **SQLite (`DatabaseHelper`)** — локальне сховище налаштувань, списків, каталогу країн/операторів і журналів.
- **Android / Kotlin (`android/app/src/main/kotlin/...`)** — `CallGuardScreeningService` приймає подію системи Android, `CallRuleEngine` оцінює номер і повертає системі рішення дозволити або відхилити дзвінок. `CallGuardDatabase` читає ту саму SQLite-базу, що й Flutter.
- **MethodChannel** — міст між Flutter та Android для системної ролі, дозволів, журналу викликів, сповіщень і статусних подій.
- **Лендінг (`landing/`)** — статична багатомовна сторінка про можливості застосунку та посилання на релізний APK.

## Структура проєкту

```text
lib/                         Flutter UI, дані, локалізація та симулятор правил
android/app/src/main/        AndroidManifest, Kotlin-служба й системні інтеграції
android/app/src/test/        Kotlin unit-тести
test/                        Dart/Flutter та widget-тести
landing/                     Статичний сайт CallGate
release/                     Актуальний релізний APK
```
