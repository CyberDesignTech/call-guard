(function () {
  'use strict';

  const translations = {
  uk: {
    pageTitle: 'Call Gate — Ваш спокій під контролем',
    pageDesc: 'Інтелектуальний офлайн-фільтр вхідних дзвінків для Android. Блокуйте спам, налаштовуйте розклад тиші, зберігайте 100% приватності.',
    navFeatures: 'Можливості',
    navHow: 'Як це працює',
    navPrivacy: 'Приватність',
    navFaq: 'FAQ',
    navDownload: 'Завантажити APK',
    badge: '100% Offline • Без реклами • Безкоштовно назавжди',
    heroTitle: 'Call Gate — <span class="accent">Ваш спокій під контролем</span>',
    heroSub: 'Інтелектуальний офлайн-фільтр вхідних дзвінків для Android. Блокуйте спам, налаштовуйте розклад тиші та зберігайте 100% приватності без передачі контактів у хмару.',
    heroDownload: 'Завантажити APK',
    heroSim: 'Спробувати симулятор',
    heroMeta: 'v2.2.0 • Android 10+ • 19 MB',
    phoneProtection: 'Захист',
    phoneOn: 'Увімкнено',
    phoneQuietTitle: 'Тихий режим активний',
    phoneQuietSub: '22:00 — 07:00 • Вихідні',
    phoneRejected: 'Відхилені',
    phoneMissed: 'Пропущені',
    tagSpam: 'Спам',
    tagForeign: 'Закордон',
    tagCallback: 'Передзвонити',
    phoneMom: 'Мама',
    featuresTitle: 'Ключові переваги',
    featuresSub: 'Все, що потрібно для спокою — без хмари, реклами та підписок.',
    f1t: '100% локальна приватність',
    f1d: 'Без серверів, хмарних баз чи збору адресної книги. Правила та журнали залишаються лише на вашому пристрої.',
    f2t: 'Розклад, режим «За кермом» і швидкі дії',
    f2d: 'Налаштуйте години тиші та керуйте захистом і режимом водіння прямо зі шторки сповіщень.',
    f3t: 'Екстрені служби завжди дозволені',
    f3d: 'Коди 101–104, 112, 911 і 999 проходять безумовно. Це окремо від прориву повторного дзвінка в режимі тиші.',
    f4t: 'Короткі номери та міжнародні фільтри',
    f4d: 'Опційно блокуйте короткі й службові номери 2–6 цифр, крім контактів та екстрених служб, і керуйте фільтрами країн та операторів.',
    f5t: 'Помічник передзвону та нагадування',
    f5d: 'Тихе відхилення викликів за сценарієм і зручні нагадування передзвонити пізніше.',
    f6t: 'Безкоштовно і без реклами назавжди',
    f6d: "Жодних прихованих підписок, банерів і нав'язливих платних функцій.",
    demoTitle: 'Тестовий виклик',
    demoSub: 'Перевірте, як Call Gate прийме виклик — прямо тут.',
    scMama: 'Мама (Білий список)',
    scUnknown: 'Невідомий номер уночі (1-й дзвінок)',
    scEmergency: 'Екстрений дзвінок (3-й раз за 5 хв)',
    scForeign: 'Закордонний спам-префікс',
    checkBtn: 'Перевірити правило',
    verdictIdle: 'Оберіть сценарій або введіть номер',
    verdictIdleReason: 'Натисніть «Перевірити правило», щоб побачити рішення Call Gate.',
    verdictAllowed: 'Цей виклик дозволено',
    verdictBlocked: 'Цей виклик відхилено',
    reasonMama: 'Номер у білому списку — виклики від близьких завжди проходять.',
    reasonUnknownNight: 'Тихий режим активний: невідомий номер вночі відхилено (1-й дзвінок).',
    reasonEmergency: 'Екстрений прорив: 3-й дзвінок від того ж номера за 5 хвилин — пропущено.',
    reasonForeign: 'Префікс країни/оператора заблоковано фільтром країн.',
    reasonCustomAllowed: 'Номер не підпадає під правила блокування — дозволено.',
    reasonCustomBlocked: 'Відхилено за правилами тиші/фільтра.',
    howTitle: 'Як почати за 3 кроки',
    step1t: 'Завантажити APK',
    step1d: 'Встановіть Call Gate з релізу та відкрийте застосунок.',
    step2t: 'Надати роль фільтрації',
    step2d: 'Призначте Call Gate системною роллю визначення/фільтрації викликів (CallScreeningService).',
    step3t: 'Обрати режим спокою',
    step3d: 'Налаштуйте розклад тиші та списки — і насолоджуйтесь спокоєм.',
    tourTitle: 'Повний огляд можливостей Call Gate',
    tourSub: 'Живі сценарії з життя, а не сухий список функцій.',
    t1t: 'Багаторівневий контроль вхідних',
    t1d: 'Білий і чорний списки, фільтр невідомих контактів та прихованих номерів — ви вирішуєте, хто може додзвонитися.',
    t2t: 'Гео- та операторський щит',
    t2d: 'Миттєве блокування небажаних міжнародних префіксів і кодів операторів одним перемикачем.',
    t3t: 'Інтелектуальний розклад тиші + Екстрений прорив',
    t3d: 'Спокій уночі та у вихідні, але 3-й дзвінок із того самого номера за 5 хвилин гарантовано проривається крізь тишу.',
    t4t: 'Помічник передзвону та нагадування',
    t4d: 'Тихе відхилення виклику за обраним сценарієм із нагадуванням передзвонити у зручний час.',
    t5t: 'Симулятор правил і локальний бекап',
    t5d: 'Перевірка будь-якого номера перед реальним дзвінком та експорт/імпорт налаштувань у файл без хмари.',
    t6t: 'Інтерфейс 6 мовами світу',
    t6d: 'Повна адаптація інтерфейсу українською, англійською, польською, німецькою, іспанською та французькою мовами.',
    privacyTitle: 'Приватність понад усе',
    privacySub: 'Call Gate працює як системний CallScreeningService і не має дозволу на інтернет. Ваші контакти, журнали дзвінків і правила ніколи не залишають пристрій.',
    pp1: 'Жодного доступу до мережі',
    pp2: 'Жодного збору адресної книги',
    pp3: 'Бекап лише у локальний файл',
    pp4: 'Без реклами і підписок',
    faqTitle: 'Часті запитання',
    q1: 'Чи передаються мої контакти на сервер?',
    a1: 'Ні. Call Gate працює повністю офлайн. Ваші контакти, журнали дзвінків і правила ніколи не залишають пристрій.',
    q2: 'Чому екстрений прорив спрацьовує саме з 3-го дзвінка?',
    a2: 'Спамери зазвичай роблять 1–2 автодозвони. Три дзвінки за 5 хвилин від одного номера — ознака реальної термінової ситуації, тому виклик пропускається.',
    q3: 'Чи працює без інтернету?',
    a3: "Так, усі правила та фільтрація працюють локально без жодного з'єднання.",
    q4: 'На яких версіях Android працює застосунок?',
    a4: 'Android 10 і новіші (API 29+).',
    q5: 'Як зробити резервну копію налаштувань?',
    a5: 'Експортуйте правила у файл через меню налаштувань і збережіть його локально. Відновлення — імпортом того ж файлу.',
    footerNote: 'Локальна приватність. Жодної хмари.',
    shareBtn: 'Поділитися сторінкою',
    toastCopied: 'Посилання скопійовано!',
    toastFail: 'Не вдалося скопіювати посилання'
  },
  en: {
    pageTitle: 'Call Gate — Your peace of mind, under control',
    pageDesc: 'Intelligent offline filter for incoming calls on Android. Block spam, schedule quiet hours, keep 100% privacy.',
    navFeatures: 'Features',
    navHow: 'How it works',
    navPrivacy: 'Privacy',
    navFaq: 'FAQ',
    navDownload: 'Download APK',
    badge: '100% Offline • No ads • Free forever',
    heroTitle: 'Call Gate — <span class="accent">Your peace of mind, under control</span>',
    heroSub: 'Intelligent offline filter for incoming calls on Android. Block spam, schedule quiet hours, and keep 100% privacy without uploading contacts to the cloud.',
    heroDownload: 'Download APK',
    heroSim: 'Try simulator',
    heroMeta: 'v2.2.0 • Android 10+ • 19 MB',
    phoneProtection: 'Protection',
    phoneOn: 'On',
    phoneQuietTitle: 'Quiet mode active',
    phoneQuietSub: '22:00 — 07:00 • Weekends',
    phoneRejected: 'Rejected',
    phoneMissed: 'Missed',
    tagSpam: 'Spam',
    tagForeign: 'Foreign',
    tagCallback: 'Call back',
    phoneMom: 'Mom',
    featuresTitle: 'Key advantages',
    featuresSub: 'Everything you need for peace of mind — no cloud, no ads, no subscriptions.',
    f1t: '100% local privacy',
    f1d: 'No servers, cloud databases, or address-book collection. Rules and call logs stay on your device.',
    f2t: 'Smart schedule, driving mode & quick controls',
    f2d: 'Set quiet hours and control protection or driving mode directly from the notification shade.',
    f3t: 'Emergency services are always allowed',
    f3d: 'Codes 101–104, 112, 911, and 999 always pass. This is separate from repeat-call breakthrough during quiet hours.',
    f4t: 'Short-number and international filters',
    f4d: 'Optionally block 2–6 digit short/service numbers, except contacts and emergency services, alongside country and operator filters.',
    f5t: 'Callback helper & reminders',
    f5d: 'Quietly reject calls by scenario and get handy reminders to call back later.',
    f6t: 'Free and ad-free forever',
    f6d: 'No hidden subscriptions, banners, or pushy paid features.',
    demoTitle: 'Test call',
    demoSub: 'See how Call Gate handles a call — right here.',
    scMama: 'Mom (Whitelist)',
    scUnknown: 'Unknown number at night (1st call)',
    scEmergency: 'Emergency call (3rd time in 5 min)',
    scForeign: 'Foreign spam prefix',
    checkBtn: 'Check rule',
    verdictIdle: 'Pick a scenario or enter a number',
    verdictIdleReason: 'Press "Check rule" to see Call Gate\'s decision.',
    verdictAllowed: 'This call is allowed',
    verdictBlocked: 'This call is rejected',
    reasonMama: 'Number is on the whitelist — calls from loved ones always get through.',
    reasonUnknownNight: 'Quiet mode active: unknown number at night rejected (1st call).',
    reasonEmergency: 'Emergency breakthrough: 3rd call from the same number within 5 minutes — allowed.',
    reasonForeign: 'Country/operator prefix blocked by the country filter.',
    reasonCustomAllowed: 'Number does not match any blocking rule — allowed.',
    reasonCustomBlocked: 'Rejected by quiet/filter rules.',
    howTitle: 'Get started in 3 steps',
    step1t: 'Download APK',
    step1d: 'Install Call Gate from the release and open the app.',
    step2t: 'Grant screening role',
    step2d: 'Assign Call Gate the system call screening/filtering role (CallScreeningService).',
    step3t: 'Choose quiet mode',
    step3d: 'Set up the quiet schedule and lists — then enjoy the peace.',
    tourTitle: 'Full feature tour of Call Gate',
    tourSub: 'Real-life scenarios, not a dry feature list.',
    t1t: 'Multi-level control of incoming calls',
    t1d: 'Whitelist and blacklist, filter unknown contacts and hidden numbers — you decide who can reach you.',
    t2t: 'Geo & operator shield',
    t2d: 'Instantly block unwanted international prefixes and operator codes with one toggle.',
    t3t: 'Smart quiet schedule + Emergency breakthrough',
    t3d: 'Peace at night and on weekends, but the 3rd call from the same number within 5 minutes breaks through.',
    t4t: 'Callback helper & reminders',
    t4d: 'Quietly reject a call by chosen scenario and get a reminder to call back at a convenient time.',
    t5t: 'Rule simulator & local backup',
    t5d: 'Test any number before a real call and export/import settings to a file — no cloud.',
    t6t: 'Interface in 6 world languages',
    t6d: 'Fully adapted into Ukrainian, English, Polish, German, Spanish, and French.',
    privacyTitle: 'Privacy above all',
    privacySub: 'Call Gate runs as a system CallScreeningService with no internet permission. Your contacts, call logs, and rules never leave the device.',
    pp1: 'No network access',
    pp2: 'No address book collection',
    pp3: 'Backup only to a local file',
    pp4: 'No ads or subscriptions',
    faqTitle: 'Frequently asked questions',
    q1: 'Are my contacts sent to a server?',
    a1: 'No. Call Gate works fully offline. Your contacts, call logs, and rules never leave the device.',
    q2: 'Why does emergency breakthrough trigger on the 3rd call?',
    a2: 'Spammers usually make 1–2 auto-redials. Three calls within 5 minutes from one number signals a real emergency, so the call is let through.',
    q3: 'Does it work without internet?',
    a3: 'Yes, all rules and filtering run locally without any connection.',
    q4: 'Which Android versions are supported?',
    a4: 'Android 10 and newer (API 29+).',
    q5: 'How do I back up my settings?',
    a5: 'Export your rules to a file via settings and store it locally. Restore by importing the same file.',
    footerNote: 'Local privacy. No cloud.',
    shareBtn: 'Share page',
    toastCopied: 'Link copied!',
    toastFail: 'Could not copy link'
  },
  pl: {
    pageTitle: 'Call Gate — Twój spokój pod kontrolą',
    pageDesc: 'Inteligentny filtr połączeń przychodzących offline dla Androida. Blokuj spam, planuj ciszę, zachowaj 100% prywatności.',
    navFeatures: 'Funkcje',
    navHow: 'Jak to działa',
    navPrivacy: 'Prywatność',
    navFaq: 'FAQ',
    navDownload: 'Pobierz APK',
    badge: '100% Offline • Bez reklam • Za darmo na zawsze',
    heroTitle: 'Call Gate — <span class="accent">Twój spokój pod kontrolą</span>',
    heroSub: 'Inteligentny filtr połączeń przychodzących offline dla Androida. Blokuj spam, ustawiaj godziny ciszy i zachowaj 100% prywatności bez przesyłania kontaktów do chmury.',
    heroDownload: 'Pobierz APK',
    heroSim: 'Wypróbuj symulator',
    heroMeta: 'v2.2.0 • Android 10+ • 19 MB',
    phoneProtection: 'Ochrona',
    phoneOn: 'Włączona',
    phoneQuietTitle: 'Tryb cichy aktywny',
    phoneQuietSub: '22:00 — 07:00 • Weekendy',
    phoneRejected: 'Odrzucone',
    phoneMissed: 'Nieodebrane',
    tagSpam: 'Spam',
    tagForeign: 'Zagranica',
    tagCallback: 'Oddzwonić',
    phoneMom: 'Mama',
    featuresTitle: 'Kluczowe zalety',
    featuresSub: 'Wszystko, czego potrzebujesz dla spokoju — bez chmury, reklam i subskrypcji.',
    f1t: '100% lokalna prywatność',
    f1d: 'Bez serwerów, baz w chmurze i zbierania książki adresowej. Reguły i rejestry połączeń pozostają na urządzeniu.',
    f2t: 'Rozkład, tryb jazdy i szybkie sterowanie',
    f2d: 'Ustaw godziny ciszy i steruj ochroną lub trybem jazdy bezpośrednio z obszaru powiadomień.',
    f3t: 'Służby ratunkowe zawsze dozwolone',
    f3d: 'Kody 101–104, 112, 911 i 999 zawsze przechodzą. To osobna funkcja od przepuszczania ponownych połączeń w trybie ciszy.',
    f4t: 'Filtry krótkich numerów i połączeń międzynarodowych',
    f4d: 'Opcjonalnie blokuj krótkie numery usługowe 2–6 cyfr, z wyjątkiem kontaktów i służb ratunkowych, oraz filtruj kraje i operatorów.',
    f5t: 'Pomocnik oddzwaniania i przypomnienia',
    f5d: 'Ciche odrzucanie połączeń według scenariusza i wygodne przypomnienia o oddzwonieniu później.',
    f6t: 'Darmowe i bez reklam na zawsze',
    f6d: 'Brak ukrytych subskrypcji, banerów i nachalnych płatnych funkcji.',
    demoTitle: 'Połączenie testowe',
    demoSub: 'Zobacz, jak Call Gate obsłuży połączenie — właśnie tutaj.',
    scMama: 'Mama (Biała lista)',
    scUnknown: 'Nieznany numer w nocy (1. połączenie)',
    scEmergency: 'Połączenie awaryjne (3. raz w 5 min)',
    scForeign: 'Zagraniczny prefiks spamu',
    checkBtn: 'Sprawdź regułę',
    verdictIdle: 'Wybierz scenariusz lub wpisz numer',
    verdictIdleReason: 'Naciśnij „Sprawdź regułę”, aby zobaczyć decyzję Call Gate.',
    verdictAllowed: 'To połączenie jest dozwolone',
    verdictBlocked: 'To połączenie odrzucono',
    reasonMama: 'Numer na białej liście — połączenia od bliskich zawsze przechodzą.',
    reasonUnknownNight: 'Tryb cichy aktywny: nieznany numer w nocy odrzucony (1. połączenie).',
    reasonEmergency: 'Przełamanie awaryjne: 3. połączenie z tego samego numeru w 5 minut — dozwolone.',
    reasonForeign: 'Prefiks kraju/operatora zablokowany filtrem krajów.',
    reasonCustomAllowed: 'Numer nie pasuje do żadnej reguły blokowania — dozwolony.',
    reasonCustomBlocked: 'Odrzucono według reguł ciszy/filtra.',
    howTitle: 'Zacznij w 3 krokach',
    step1t: 'Pobierz APK',
    step1d: 'Zainstaluj Call Gate z wydania i otwórz aplikację.',
    step2t: 'Nadaj rolę filtrowania',
    step2d: 'Przypisz Call Gate systemową rolę wykrywania/filtrowania połączeń (CallScreeningService).',
    step3t: 'Wybierz tryb ciszy',
    step3d: 'Ustaw rozkład ciszy i listy — i ciesz się spokojem.',
    tourTitle: 'Pełny przegląd możliwości Call Gate',
    tourSub: 'Żywe scenariusze z życia, a nie sucha lista funkcji.',
    t1t: 'Wielopoziomowa kontrola połączeń przychodzących',
    t1d: 'Biała i czarna lista, filtr nieznanych kontaktów i ukrytych numerów — Ty decydujesz, kto może się dodzwonić.',
    t2t: 'Tarcza geo i operatorów',
    t2d: 'Natychmiastowe blokowanie niechcianych międzynarodowych prefiksów i kodów operatorów jednym przełącznikiem.',
    t3t: 'Inteligentny rozkład ciszy + Przełamanie awaryjne',
    t3d: 'Spokój w nocy i weekendy, ale 3. połączenie z tego samego numeru w 5 minut przebija się przez ciszę.',
    t4t: 'Pomocnik oddzwaniania i przypomnienia',
    t4d: 'Ciche odrzucenie połączenia według wybranego scenariusza z przypomnieniem o oddzwonieniu w dogodnym czasie.',
    t5t: 'Symulator reguł i lokalna kopia zapasowa',
    t5d: 'Testuj dowolny numer przed realnym połączeniem i eksportuj/importuj ustawienia do pliku — bez chmury.',
    t6t: 'Interfejs w 6 językach świata',
    t6d: 'Pełna adaptacja na ukraiński, angielski, polski, niemiecki, hiszpański i francuski.',
    privacyTitle: 'Prywatność przede wszystkim',
    privacySub: 'Call Gate działa jako systemowy CallScreeningService bez uprawnień do internetu. Twoje kontakty, dzienniki połączeń i reguły nigdy nie opuszczają urządzenia.',
    pp1: 'Brak dostępu do sieci',
    pp2: 'Brak zbierania książki adresowej',
    pp3: 'Kopia zapasowa tylko do lokalnego pliku',
    pp4: 'Bez reklam i subskrypcji',
    faqTitle: 'Najczęstsze pytania',
    q1: 'Czy moje kontakty są wysyłane na serwer?',
    a1: 'Nie. Call Gate działa w pełni offline. Twoje kontakty, dzienniki połączeń i reguły nigdy nie opuszczają urządzenia.',
    q2: 'Dlaczego przełamanie awaryjne działa od 3. połączenia?',
    a2: 'Spamerzy zwykle wykonują 1–2 automatyczne oddzwonienia. Trzy połączenia w 5 minut z jednego numeru sygnalizują prawdziwą sytuację awaryjną, więc połączenie jest przepuszczane.',
    q3: 'Czy działa bez internetu?',
    a3: 'Tak, wszystkie reguły i filtrowanie działają lokalnie bez żadnego połączenia.',
    q4: 'Jakie wersje Androida są obsługiwane?',
    a4: 'Android 10 i nowsze (API 29+).',
    q5: 'Jak wykonać kopię zapasową ustawień?',
    a5: 'Wyeksportuj reguły do pliku w ustawieniach i zapisz je lokalnie. Przywróć, importując ten sam plik.',
    footerNote: 'Lokalna prywatność. Bez chmury.',
    shareBtn: 'Udostępnij stronę',
    toastCopied: 'Link skopiowany!',
    toastFail: 'Nie udało się skopiować linku'
  },
  de: {
    pageTitle: 'Call Gate — Deine Ruhe unter Kontrolle',
    pageDesc: 'Intelligenter Offline-Filter für eingehende Anrufe auf Android. Spam blockieren, Ruhezeiten planen, 100% Privatsphäre.',
    navFeatures: 'Funktionen',
    navHow: 'So funktioniert\'s',
    navPrivacy: 'Privatsphäre',
    navFaq: 'FAQ',
    navDownload: 'APK herunterladen',
    badge: '100% Offline • Werbefrei • Für immer kostenlos',
    heroTitle: 'Call Gate — <span class="accent">Deine Ruhe unter Kontrolle</span>',
    heroSub: 'Intelligenter Offline-Filter für eingehende Anrufe auf Android. Blockiere Spam, plane Ruhezeiten und bewahre 100% Privatsphäre ohne Kontakte in die Cloud zu senden.',
    heroDownload: 'APK herunterladen',
    heroSim: 'Simulator testen',
    heroMeta: 'v2.2.0 • Android 10+ • 19 MB',
    phoneProtection: 'Schutz',
    phoneOn: 'Aktiv',
    phoneQuietTitle: 'Ruhemodus aktiv',
    phoneQuietSub: '22:00 — 07:00 • Wochenende',
    phoneRejected: 'Abgelehnt',
    phoneMissed: 'Verpasst',
    tagSpam: 'Spam',
    tagForeign: 'Ausland',
    tagCallback: 'Zurückrufen',
    phoneMom: 'Mama',
    featuresTitle: 'Hauptvorteile',
    featuresSub: 'Alles für deine Ruhe — ohne Cloud, Werbung und Abos.',
    f1t: '100% lokale Privatsphäre',
    f1d: 'Keine Server, Cloud-Datenbanken oder Adressbuch-Erfassung. Regeln und Anrufprotokolle bleiben auf deinem Gerät.',
    f2t: 'Zeitplan, Fahrmodus & Schnellsteuerung',
    f2d: 'Lege Ruhezeiten fest und steuere Schutz oder Fahrmodus direkt über die Benachrichtigungsleiste.',
    f3t: 'Notdienste sind immer zugelassen',
    f3d: 'Die Codes 101–104, 112, 911 und 999 werden immer durchgelassen. Das ist getrennt vom Rückruf-Durchbruch im Ruhemodus.',
    f4t: 'Kurznummern- und internationale Filter',
    f4d: 'Optional kurze Servicecodes mit 2–6 Ziffern blockieren, außer Kontakten und Notdiensten, zusätzlich zu Länder- und Operatorfiltern.',
    f5t: 'Rückruf-Helfer & Erinnerungen',
    f5d: 'Anrufe still ablehnen nach Szenario und bequeme Erinnerungen zum späteren Rückruf.',
    f6t: 'Kostenlos und werbefrei für immer',
    f6d: 'Keine versteckten Abos, Banner oder aufdringlichen Premium-Funktionen.',
    demoTitle: 'Testanruf',
    demoSub: 'Sieh, wie Call Gate einen Anruf behandelt — direkt hier.',
    scMama: 'Mama (Whitelist)',
    scUnknown: 'Unbekannte Nummer nachts (1. Anruf)',
    scEmergency: 'Notfall-Anruf (3. Mal in 5 Min)',
    scForeign: 'Ausländischer Spam-Prefix',
    checkBtn: 'Regel prüfen',
    verdictIdle: 'Szenario wählen oder Nummer eingeben',
    verdictIdleReason: 'Drücke „Regel prüfen", um die Entscheidung von Call Gate zu sehen.',
    verdictAllowed: 'Dieser Anruf ist erlaubt',
    verdictBlocked: 'Dieser Anruf wurde abgelehnt',
    reasonMama: 'Nummer auf der Whitelist — Anrufe von Nahestehenden kommen immer durch.',
    reasonUnknownNight: 'Ruhemodus aktiv: unbekannte Nummer nachts abgelehnt (1. Anruf).',
    reasonEmergency: 'Notfall-Durchbruch: 3. Anruf derselben Nummer innerhalb 5 Minuten — erlaubt.',
    reasonForeign: 'Länder-/Operator-Prefix durch Länderfilter blockiert.',
    reasonCustomAllowed: 'Nummer passt zu keiner Blockierregel — erlaubt.',
    reasonCustomBlocked: 'Nach Ruhe-/Filterregeln abgelehnt.',
    howTitle: 'In 3 Schritten starten',
    step1t: 'APK herunterladen',
    step1d: 'Installiere Call Gate aus dem Release und öffne die App.',
    step2t: 'Filterrolle gewähren',
    step2d: 'Weise Call Gate die systemweite Anruf-Filterrolle (CallScreeningService) zu.',
    step3t: 'Ruhemodus wählen',
    step3d: 'Ruheplan und Listen einrichten — und Ruhe genießen.',
    tourTitle: 'Vollständiger Funktionsüberblick von Call Gate',
    tourSub: 'Lebendige Alltagsszenarien statt trockener Funktionsliste.',
    t1t: 'Mehrstufige Kontrolle eingehender Anrufe',
    t1d: 'Whitelist und Blacklist, Filter für unbekannte Kontakte und versteckte Nummern — du entscheidest, wer dich erreichen kann.',
    t2t: 'Geo- & Operator-Schild',
    t2d: 'Unerwünschte internationale Vorwahlen und Operatorcodes mit einem Schalter sofort blockieren.',
    t3t: 'Smarter Ruheplan + Notfall-Durchbruch',
    t3d: 'Ruhe nachts und am Wochenende, aber der 3. Anruf derselben Nummer in 5 Minuten bricht durch.',
    t4t: 'Rückruf-Helfer & Erinnerungen',
    t4d: 'Anruf still nach gewähltem Szenario ablehnen mit Erinnerung, später zurückzurufen.',
    t5t: 'Regelsimulator & lokales Backup',
    t5d: 'Beliebige Nummer vor einem echten Anruf testen und Einstellungen in Datei exportieren/importieren — ohne Cloud.',
    t6t: 'Oberfläche in 6 Weltsprachen',
    t6d: 'Vollständig angepasst auf Ukrainisch, Englisch, Polnisch, Deutsch, Spanisch und Französisch.',
    privacyTitle: 'Privatsphäre an erster Stelle',
    privacySub: 'Call Gate läuft als systemweiter CallScreeningService ohne Internet-Berechtigung. Deine Kontakte, Anrufprotokolle und Regeln verlassen das Gerät nie.',
    pp1: 'Kein Netzwerkzugriff',
    pp2: 'Keine Adressbuch-Erfassung',
    pp3: 'Backup nur in lokale Datei',
    pp4: 'Keine Werbung und Abos',
    faqTitle: 'Häufige Fragen',
    q1: 'Werden meine Kontakte an einen Server gesendet?',
    a1: 'Nein. Call Gate arbeitet vollständig offline. Deine Kontakte, Anrufprotokolle und Regeln verlassen das Gerät nie.',
    q2: 'Warum greift der Notfall-Durchbruch beim 3. Anruf?',
    a2: 'Spammer machen meist 1–2 Auto-Rückrufe. Drei Anrufe innerhalb von 5 Minuten von einer Nummer signalisieren einen echten Notfall, daher wird der Anruf durchgelassen.',
    q3: 'Funktioniert es ohne Internet?',
    a3: 'Ja, alle Regeln und Filterung laufen lokal ohne jede Verbindung.',
    q4: 'Welche Android-Versionen werden unterstützt?',
    a4: 'Android 10 und neuer (API 29+).',
    q5: 'Wie erstelle ich ein Backup meiner Einstellungen?',
    a5: 'Exportiere deine Regeln über Einstellungen in eine Datei und speichere sie lokal. Wiederherstellung durch Import derselben Datei.',
    footerNote: 'Lokale Privatsphäre. Keine Cloud.',
    shareBtn: 'Seite teilen',
    toastCopied: 'Link kopiert!',
    toastFail: 'Link konnte nicht kopiert werden'
  },
  es: {
    pageTitle: 'Call Gate — Tu tranquilidad bajo control',
    pageDesc: 'Filtro inteligente offline de llamadas entrantes para Android. Bloquea spam, programa silencio, conserva 100% de privacidad.',
    navFeatures: 'Funciones',
    navHow: 'Cómo funciona',
    navPrivacy: 'Privacidad',
    navFaq: 'FAQ',
    navDownload: 'Descargar APK',
    badge: '100% Offline • Sin anuncios • Gratis para siempre',
    heroTitle: 'Call Gate — <span class="accent">Tu tranquilidad bajo control</span>',
    heroSub: 'Filtro inteligente offline de llamadas entrantes para Android. Bloquea spam, programa horas de silencio y conserva el 100% de privacidad sin subir contactos a la nube.',
    heroDownload: 'Descargar APK',
    heroSim: 'Probar simulador',
    heroMeta: 'v2.2.0 • Android 10+ • 19 MB',
    phoneProtection: 'Protección',
    phoneOn: 'Activada',
    phoneQuietTitle: 'Modo silencio activo',
    phoneQuietSub: '22:00 — 07:00 • Fines de semana',
    phoneRejected: 'Rechazadas',
    phoneMissed: 'Perdidas',
    tagSpam: 'Spam',
    tagForeign: 'Extranjero',
    tagCallback: 'Devolver llamada',
    phoneMom: 'Mamá',
    featuresTitle: 'Ventajas clave',
    featuresSub: 'Todo lo que necesitas para la tranquilidad — sin nube, anuncios ni suscripciones.',
    f1t: '100% privacidad local',
    f1d: 'Sin servidores, bases de datos en la nube ni recopilación de la agenda. Las reglas y el registro permanecen en tu dispositivo.',
    f2t: 'Horario, modo conducción y controles rápidos',
    f2d: 'Programa las horas de silencio y controla la protección o el modo conducción desde la cortina de notificaciones.',
    f3t: 'Los servicios de emergencia siempre pasan',
    f3d: 'Los códigos 101–104, 112, 911 y 999 siempre se permiten. Es independiente del paso de llamadas repetidas en modo silencio.',
    f4t: 'Filtro de números cortos e internacionales',
    f4d: 'Bloquea opcionalmente códigos cortos/de servicio de 2–6 dígitos, excepto contactos y emergencias, además de filtrar países y operadores.',
    f5t: 'Asistente de devolución y recordatorios',
    f5d: 'Rechazo silencioso de llamadas por escenario y recordatorios cómodos para devolver la llamada.',
    f6t: 'Gratis y sin anuncios para siempre',
    f6d: 'Sin suscripciones ocultas, banners ni funciones de pago insistentes.',
    demoTitle: 'Llamada de prueba',
    demoSub: 'Mira cómo Call Gate gestiona una llamada — aquí mismo.',
    scMama: 'Mamá (Lista blanca)',
    scUnknown: 'Número desconocido de noche (1.ª llamada)',
    scEmergency: 'Llamada de emergencia (3.ª vez en 5 min)',
    scForeign: 'Prefijo spam extranjero',
    checkBtn: 'Comprobar regla',
    verdictIdle: 'Elige un escenario o introduce un número',
    verdictIdleReason: 'Pulsa «Comprobar regla» para ver la decisión de Call Gate.',
    verdictAllowed: 'Esta llamada está permitida',
    verdictBlocked: 'Esta llamada fue rechazada',
    reasonMama: 'Número en la lista blanca: las llamadas de los tuyos siempre pasan.',
    reasonUnknownNight: 'Modo silencio activo: número desconocido de noche rechazado (1.ª llamada).',
    reasonEmergency: 'Ruptura de emergencia: 3.ª llamada del mismo número en 5 minutos — permitida.',
    reasonForeign: 'Prefijo de país/operador bloqueado por el filtro de países.',
    reasonCustomAllowed: 'El número no coincide con ninguna regla de bloqueo — permitido.',
    reasonCustomBlocked: 'Rechazado por reglas de silencio/filtro.',
    howTitle: 'Empieza en 3 pasos',
    step1t: 'Descargar APK',
    step1d: 'Instala Call Gate desde el release y abre la app.',
    step2t: 'Conceder rol de filtrado',
    step2d: 'Asigna a Call Gate el rol del sistema de detección/filtrado de llamadas (CallScreeningService).',
    step3t: 'Elegir modo de silencio',
    step3d: 'Configura el horario de silencio y las listas — y disfruta de la tranquilidad.',
    tourTitle: 'Recorrido completo por las funciones de Call Gate',
    tourSub: 'Escenarios reales de la vida, no una lista seca de funciones.',
    t1t: 'Control multinivel de llamadas entrantes',
    t1d: 'Lista blanca y negra, filtro de contactos desconocidos y números ocultos — tú decides quién puede llamarte.',
    t2t: 'Escudo geo y de operadores',
    t2d: 'Bloqueo instantáneo de prefijos internacionales no deseados y códigos de operador con un solo interruptor.',
    t3t: 'Horario de silencio inteligente + Ruptura de emergencia',
    t3d: 'Tranquilidad de noche y fines de semana, pero la 3.ª llamada del mismo número en 5 minutos atraviesa el silencio.',
    t4t: 'Asistente de devolución y recordatorios',
    t4d: 'Rechazo silencioso de una llamada según el escenario elegido con recordatorio para devolver la llamada a la hora conveniente.',
    t5t: 'Simulador de reglas y copia de seguridad local',
    t5d: 'Prueba cualquier número antes de una llamada real y exporta/importa ajustes a un archivo — sin nube.',
    t6t: 'Interfaz en 6 idiomas del mundo',
    t6d: 'Totalmente adaptado al ucraniano, inglés, polaco, alemán, español y francés.',
    privacyTitle: 'Privacidad ante todo',
    privacySub: 'Call Gate se ejecuta como CallScreeningService del sistema sin permiso de internet. Tus contactos, registros de llamadas y reglas nunca salen del dispositivo.',
    pp1: 'Sin acceso a la red',
    pp2: 'Sin recopilación de agenda',
    pp3: 'Copia de seguridad solo a archivo local',
    pp4: 'Sin anuncios ni suscripciones',
    faqTitle: 'Preguntas frecuentes',
    q1: '¿Se envían mis contactos a un servidor?',
    a1: 'No. Call Gate funciona completamente offline. Tus contactos, registros de llamadas y reglas nunca salen del dispositivo.',
    q2: '¿Por qué la ruptura de emergencia se activa en la 3.ª llamada?',
    a2: 'Los spammers suelen hacer 1–2 reintentos automáticos. Tres llamadas en 5 minutos de un mismo número señalan una emergencia real, por lo que se permite la llamada.',
    q3: '¿Funciona sin internet?',
    a3: 'Sí, todas las reglas y el filtrado se ejecutan localmente sin ninguna conexión.',
    q4: '¿Qué versiones de Android son compatibles?',
    a4: 'Android 10 y superiores (API 29+).',
    q5: '¿Cómo hago una copia de seguridad de los ajustes?',
    a5: 'Exporta las reglas a un archivo desde ajustes y guárdalo localmente. Restaura importando el mismo archivo.',
    footerNote: 'Privacidad local. Sin nube.',
    shareBtn: 'Compartir página',
    toastCopied: '¡Enlace copiado!',
    toastFail: 'No se pudo copiar el enlace'
  },
  fr: {
    pageTitle: 'Call Gate — Votre tranquillité sous contrôle',
    pageDesc: 'Filtre intelligent hors ligne des appels entrants pour Android. Bloquez le spam, programmez le silence, gardez 100% de confidentialité.',
    navFeatures: 'Fonctions',
    navHow: 'Comment ça marche',
    navPrivacy: 'Confidentialité',
    navFaq: 'FAQ',
    navDownload: 'Télécharger l\'APK',
    badge: '100% Offline • Sans pub • Gratuit pour toujours',
    heroTitle: 'Call Gate — <span class="accent">Votre tranquillité sous contrôle</span>',
    heroSub: 'Filtre intelligent hors ligne des appels entrants pour Android. Bloquez le spam, programmez les heures de silence et gardez 100% de confidentialité sans envoyer vos contacts dans le cloud.',
    heroDownload: 'Télécharger l\'APK',
    heroSim: 'Essayer le simulateur',
    heroMeta: 'v2.2.0 • Android 10+ • 19 MB',
    phoneProtection: 'Protection',
    phoneOn: 'Activée',
    phoneQuietTitle: 'Mode silencieux actif',
    phoneQuietSub: '22:00 — 07:00 • Week-ends',
    phoneRejected: 'Rejetés',
    phoneMissed: 'Manqués',
    tagSpam: 'Spam',
    tagForeign: 'Étranger',
    tagCallback: 'Rappeler',
    phoneMom: 'Maman',
    featuresTitle: 'Avantages clés',
    featuresSub: 'Tout ce qu\'il faut pour la tranquillité — sans cloud, pub ni abonnement.',
    f1t: '100% confidentialité locale',
    f1d: 'Aucun serveur, aucune base cloud ni collecte du carnet d\'adresses. Les règles et journaux restent sur votre appareil.',
    f2t: 'Planning, mode conduite et commandes rapides',
    f2d: 'Planifiez les heures de silence et contrôlez la protection ou le mode conduite depuis le volet de notifications.',
    f3t: 'Les services d’urgence passent toujours',
    f3d: 'Les codes 101–104, 112, 911 et 999 sont toujours autorisés. C’est distinct du passage des appels répétés en mode silencieux.',
    f4t: 'Filtre des numéros courts et internationaux',
    f4d: 'Bloquez en option les codes courts/de service de 2–6 chiffres, sauf les contacts et urgences, ainsi que les filtres par pays et opérateur.',
    f5t: 'Aide au rappel et rappels',
    f5d: 'Rejet silencieux des appels selon scénario et rappels pratiques pour rappeler plus tard.',
    f6t: 'Gratuit et sans pub pour toujours',
    f6d: 'Aucun abonnement caché, bannière ni fonction payante insistante.',
    demoTitle: 'Appel test',
    demoSub: 'Voyez comment Call Gate traite un appel — ici même.',
    scMama: 'Maman (Liste blanche)',
    scUnknown: 'Numéro inconnu la nuit (1er appel)',
    scEmergency: 'Appel d\'urgence (3ᵉ fois en 5 min)',
    scForeign: 'Préfixe spam étranger',
    checkBtn: 'Vérifier la règle',
    verdictIdle: 'Choisissez un scénario ou saisissez un numéro',
    verdictIdleReason: 'Appuyez sur « Vérifier la règle » pour voir la décision de Call Gate.',
    verdictAllowed: 'Cet appel est autorisé',
    verdictBlocked: 'Cet appel a été rejeté',
    reasonMama: 'Numéro sur liste blanche : les appels des proches passent toujours.',
    reasonUnknownNight: 'Mode silencieux actif : numéro inconnu la nuit rejeté (1er appel).',
    reasonEmergency: 'Percée d\'urgence : 3ᵉ appel du même numéro en 5 minutes — autorisé.',
    reasonForeign: 'Préfixe pays/opérateur bloqué par le filtre pays.',
    reasonCustomAllowed: 'Le numéro ne correspond à aucune règle de blocage — autorisé.',
    reasonCustomBlocked: 'Rejeté selon les règles de silence/filtre.',
    howTitle: 'Démarrez en 3 étapes',
    step1t: 'Télécharger l\'APK',
    step1d: 'Installez Call Gate depuis la release et ouvrez l\'app.',
    step2t: 'Accorder le rôle de filtrage',
    step2d: 'Attribuez à Call Gate le rôle système de détection/filtrage des appels (CallScreeningService).',
    step3t: 'Choisir le mode silence',
    step3d: 'Configurez le planning de silence et les listes — puis profitez de la tranquillité.',
    tourTitle: 'Visite complète des fonctions de Call Gate',
    tourSub: 'Scénarios de vie réels, pas une liste sèche de fonctions.',
    t1t: 'Contrôle multiniveau des appels entrants',
    t1d: 'Liste blanche et noire, filtre des contacts inconnus et numéros masqués — vous décidez qui peut vous joindre.',
    t2t: 'Bouclier géo et opérateurs',
    t2d: 'Blocage instantané des préfixes internationaux indésirables et codes opérateurs d\'un seul interrupteur.',
    t3t: 'Planning de silence intelligent + Percée d\'urgence',
    t3d: 'Tranquillité la nuit et le week-end, mais le 3ᵉ appel du même numéro en 5 minutes perce le silence.',
    t4t: 'Aide au rappel et rappels',
    t4d: 'Rejet silencieux d\'un appel selon le scénario choisi avec rappel pour rappeler à l\'heure convenable.',
    t5t: 'Simulateur de règles et sauvegarde locale',
    t5d: 'Testez n\'importe quel numéro avant un vrai appel et exportez/importez les réglages dans un fichier — sans cloud.',
    t6t: 'Interface en 6 langues mondiales',
    t6d: 'Entièrement adapté en ukrainien, anglais, polonais, allemand, espagnol et français.',
    privacyTitle: 'La confidentialité avant tout',
    privacySub: 'Call Gate s\'exécute comme CallScreeningService système sans permission internet. Vos contacts, journaux d\'appels et règles ne quittent jamais l\'appareil.',
    pp1: 'Aucun accès réseau',
    pp2: 'Aucune collecte de carnet d\'adresses',
    pp3: 'Sauvegarde uniquement vers un fichier local',
    pp4: 'Sans pub ni abonnement',
    faqTitle: 'Questions fréquentes',
    q1: 'Mes contacts sont-ils envoyés à un serveur ?',
    a1: 'Non. Call Gate fonctionne entièrement hors ligne. Vos contacts, journaux d\'appels et règles ne quittent jamais l\'appareil.',
    q2: 'Pourquoi la percée d\'urgence se déclenche au 3ᵉ appel ?',
    a2: 'Les spammeurs font généralement 1 à 2 relances automatiques. Trois appels en 5 minutes d\'un même numéro signalent une vraie urgence, l\'appel est donc laissé passer.',
    q3: 'Fonctionne-t-il sans internet ?',
    a3: 'Oui, toutes les règles et le filtrage s\'exécutent localement sans aucune connexion.',
    q4: 'Quelles versions d\'Android sont prises en charge ?',
    a4: 'Android 10 et plus récents (API 29+).',
    q5: 'Comment sauvegarder mes réglages ?',
    a5: 'Exportez vos règles vers un fichier via les réglages et conservez-le localement. Restaurez en important le même fichier.',
    footerNote: 'Confidentialité locale. Sans cloud.',
    shareBtn: 'Partager la page',
    toastCopied: 'Lien copié !',
    toastFail: 'Impossible de copier le lien'
  }
  };

  const scenarios = {
    mama: { number: '+380 67 123 45 67', verdict: 'allowed', reason: 'reasonMama' },
    unknownNight: { number: '+380 99 000 00 00', verdict: 'blocked', reason: 'reasonUnknownNight' },
    emergency: { number: '+380 99 000 00 00', verdict: 'allowed', reason: 'reasonEmergency' },
    foreign: { number: '+44 20 7946 0958', verdict: 'blocked', reason: 'reasonForeign' }
  };

  const foreignPrefixes = ['+44', '+1', '+91', '+86', '+49', '+33'];

  function detectLang() {
    const stored = localStorage.getItem('cg_lang');
    if (stored && translations[stored]) return stored;
    const nav = (navigator.language || 'uk').toLowerCase();
    if (nav.startsWith('en')) return 'en';
    if (nav.startsWith('pl')) return 'pl';
    if (nav.startsWith('de')) return 'de';
    if (nav.startsWith('es')) return 'es';
    if (nav.startsWith('fr')) return 'fr';
    if (nav.startsWith('uk') || nav.startsWith('ru')) return 'uk';
    return 'uk';
  }

  let lang = detectLang();
  let activeScenario = 'mama';

  function t(key) { return (translations[lang] && translations[lang][key]) || key; }

  function applyLang() {
    document.documentElement.lang = lang;
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      el.textContent = t(key);
    });
    document.querySelectorAll('[data-i18n-html]').forEach(el => {
      const key = el.getAttribute('data-i18n-html');
      el.innerHTML = t(key);
    });
    document.querySelectorAll('[data-i18n-meta]').forEach(el => {
      const key = el.getAttribute('data-i18n-meta');
      el.setAttribute('content', t(key));
    });
    const ls = document.getElementById('langSelect');
    if (ls) ls.value = lang;
    document.title = t('pageTitle');
  }

  function setLang(l) {
    if (!translations[l]) return;
    lang = l;
    localStorage.setItem('cg_lang', l);
    applyLang();
  }

  const hamburger = document.getElementById('hamburger');
  const mobileMenu = document.getElementById('mobileMenu');
  if (hamburger) hamburger.addEventListener('click', () => mobileMenu.classList.toggle('open'));
  if (mobileMenu) mobileMenu.querySelectorAll('a').forEach(a => a.addEventListener('click', () => mobileMenu.classList.remove('open')));

  const langSelect = document.getElementById('langSelect');
  if (langSelect) langSelect.addEventListener('change', (e) => setLang(e.target.value));

  const scenarioBtns = document.querySelectorAll('.scenario-btn');
  const phoneInput = document.getElementById('phoneInput');
  scenarioBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      scenarioBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeScenario = btn.getAttribute('data-scenario');
      phoneInput.value = scenarios[activeScenario].number;
    });
  });

  if (phoneInput) phoneInput.addEventListener('input', () => {
    const sc = scenarios[activeScenario];
    if (sc && phoneInput.value.trim() !== sc.number) {
      activeScenario = null;
      scenarioBtns.forEach(b => b.classList.remove('active'));
    }
  });

  const verdict = document.getElementById('verdict');
  const verdictStatus = document.getElementById('verdictStatus');
  const verdictReason = document.getElementById('verdictReason');

  function evaluate() {
    let allowed, reasonKey;
    if (activeScenario && scenarios[activeScenario]) {
      const sc = scenarios[activeScenario];
      allowed = sc.verdict === 'allowed';
      reasonKey = sc.reason;
    } else {
      const num = (phoneInput.value || '').trim();
      const normalized = num.replace(/\s/g, '');
      if (normalized === '+380671234567') {
        allowed = true; reasonKey = 'reasonMama';
      } else if (foreignPrefixes.some(p => normalized.startsWith(p))) {
        allowed = false; reasonKey = 'reasonForeign';
      } else {
        allowed = false; reasonKey = 'reasonUnknownNight';
      }
    }
    verdict.classList.remove('allowed', 'blocked');
    verdict.classList.add(allowed ? 'allowed' : 'blocked');
    verdictStatus.textContent = allowed ? t('verdictAllowed') : t('verdictBlocked');
    verdictReason.textContent = t(reasonKey);
  }

  const checkBtn = document.getElementById('checkBtn');
  if (checkBtn) checkBtn.addEventListener('click', evaluate);

  document.querySelectorAll('.faq-q').forEach(q => {
    q.addEventListener('click', () => {
      const item = q.parentElement;
      item.classList.toggle('open');
    });
  });

  const shareBtn = document.getElementById('shareBtn');
  const toast = document.getElementById('toast');
  function showToast(msg) {
    toast.textContent = msg;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), 2400);
  }
  if (shareBtn) {
    shareBtn.addEventListener('click', async () => {
      const url = window.location.href;
      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(url);
          showToast(t('toastCopied'));
        } else {
          throw new Error('no clipboard');
        }
      } catch (e) {
        showToast(t('toastFail'));
      }
    });
  }

  applyLang();
  if (phoneInput) phoneInput.value = scenarios.mama.number;
})();
