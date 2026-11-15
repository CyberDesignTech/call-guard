(function () {
  'use strict';

  const translations = {
    uk: {
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
      heroMeta: 'v1.6.2 • Android 10+ • 19 MB',
      phoneProtection: 'Захист',
      phoneOn: 'Увімкнено',
      phoneQuietTitle: 'Тихий режим активний',
      phoneQuietSub: '22:00 — 07:00 • Вихідні',
      phoneRejected: 'Відхилені',
      phoneMissed: 'Пропущені',
      tagSpam: 'Спам',
      tagForeign: 'Закордон',
      tagCallback: 'Передзвонити',
      featuresTitle: 'Ключові переваги',
      featuresSub: 'Все, що потрібно для спокою — без хмари, реклами та підписок.',
      f1t: '100% локальна приватність',
      f1d: 'Жодних хмарних баз, збору адресної книги чи аналітики. Усі правила живуть лише на вашому пристрої.',
      f2t: 'Розумний розклад тиші',
      f2d: 'Автоматичне ввімкнення тиші вночі, у вихідні або під час відпочинку.',
      f3t: 'Екстрений прорив (3-й дзвінок за 5 хв)',
      f3d: 'Відсіює подвійні автодозвони спамерів, але пропускає близьких у справді терміновій ситуації.',
      f4t: 'Фільтр країн та операторів',
      f4d: 'Блокування небажаних міжнародних префіксів та мобільних кодів одним перемикачем.',
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
      privacyTitle: 'Приватність понад усе',
      privacySub: 'Call Gate не надсилає ваші контакти, журнали дзвінків чи правила на сервер. Усе працює офлайн, прямо на пристрої.',
      faqTitle: 'Часті запитання',
      q1: 'Чи передаються мої контакти на сервер?',
      a1: 'Ні. Call Gate працює повністю офлайн. Ваші контакти, журнали дзвінків і правила ніколи не залишають пристрій.',
      q2: 'Чому екстрений прорив спрацьовує саме з 3-го дзвінка?',
      a2: 'Спамери зазвичай роблять 1–2 автодозвони. Три дзвінки за 5 хвилин від одного номера — ознака реальної термінової ситуації, тому виклик пропускається.',
      q3: 'Чи працює без інтернету?',
      a3: 'Так, усі правила та фільтрація працюють локально без жодного з\'єднання.',
      q4: 'На яких версіях Android працює застосунок?',
      a4: 'Android 10 і новіші (API 29+).',
      footerNote: 'Локальна приватність. Жодної хмари.',
      shareBtn: 'Поділитися сторінкою',
      toastCopied: 'Посилання скопійовано!',
      toastFail: 'Не вдалося скопіювати посилання'
    },
    en: {
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
      heroMeta: 'v1.6.2 • Android 10+ • 19 MB',
      phoneProtection: 'Protection',
      phoneOn: 'On',
      phoneQuietTitle: 'Quiet mode active',
      phoneQuietSub: '22:00 — 07:00 • Weekends',
      phoneRejected: 'Rejected',
      phoneMissed: 'Missed',
      tagSpam: 'Spam',
      tagForeign: 'Foreign',
      tagCallback: 'Call back',
      featuresTitle: 'Key advantages',
      featuresSub: 'Everything you need for peace of mind — no cloud, no ads, no subscriptions.',
      f1t: '100% local privacy',
      f1d: 'No cloud databases, no address book collection, no analytics. All rules live only on your device.',
      f2t: 'Smart quiet schedule',
      f2d: 'Automatically enable silence at night, on weekends, or during rest.',
      f3t: 'Emergency breakthrough (3rd call in 5 min)',
      f3d: 'Filters out double auto-redials from spammers, but lets loved ones through in a real emergency.',
      f4t: 'Country & operator filter',
      f4d: 'Block unwanted international prefixes and mobile codes with one toggle.',
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
      privacyTitle: 'Privacy above all',
      privacySub: 'Call Gate never sends your contacts, call logs, or rules to a server. Everything runs offline, on your device.',
      faqTitle: 'Frequently asked questions',
      q1: 'Are my contacts sent to a server?',
      a1: 'No. Call Gate works fully offline. Your contacts, call logs, and rules never leave the device.',
      q2: 'Why does emergency breakthrough trigger on the 3rd call?',
      a2: 'Spammers usually make 1–2 auto-redials. Three calls within 5 minutes from one number signals a real emergency, so the call is let through.',
      q3: 'Does it work without internet?',
      a3: 'Yes, all rules and filtering run locally without any connection.',
      q4: 'Which Android versions are supported?',
      a4: 'Android 10 and newer (API 29+).',
      footerNote: 'Local privacy. No cloud.',
      shareBtn: 'Share page',
      toastCopied: 'Link copied!',
      toastFail: 'Could not copy link'
    }
  };

  const scenarios = {
    mama: { number: '+380 67 123 45 67', verdict: 'allowed', reason: 'reasonMama' },
    unknownNight: { number: '+380 99 000 00 00', verdict: 'blocked', reason: 'reasonUnknownNight' },
    emergency: { number: '+380 99 000 00 00', verdict: 'allowed', reason: 'reasonEmergency' },
    foreign: { number: '+44 20 7946 0958', verdict: 'blocked', reason: 'reasonForeign' }
  };

  const foreignPrefixes = ['+44', '+1', '+91', '+86', '+49', '+33'];

  let lang = localStorage.getItem('cg_lang') || 'uk';
  let activeScenario = 'mama';

  function t(key) { return (translations[lang] && translations[lang][key]) || key; }

  function applyLang() {
    document.documentElement.lang = lang === 'uk' ? 'uk' : 'en';
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.getAttribute('data-i18n');
      el.textContent = t(key);
    });
    document.querySelectorAll('[data-i18n-html]').forEach(el => {
      const key = el.getAttribute('data-i18n-html');
      el.innerHTML = t(key);
    });
    document.querySelectorAll('.lang-switch button').forEach(b => {
      b.classList.toggle('active', b.getAttribute('data-lang') === lang);
    });
  }

  function setLang(l) {
    lang = l;
    localStorage.setItem('cg_lang', l);
    applyLang();
    // reset verdict display text if idle? keep
  }

  // Mobile menu
  const hamburger = document.getElementById('hamburger');
  const mobileMenu = document.getElementById('mobileMenu');
  if (hamburger) hamburger.addEventListener('click', () => mobileMenu.classList.toggle('open'));
  mobileMenu && mobileMenu.querySelectorAll('a').forEach(a => a.addEventListener('click', () => mobileMenu.classList.remove('open')));

  // lang buttons
  document.querySelectorAll('.lang-switch button').forEach(b => {
    b.addEventListener('click', () => setLang(b.getAttribute('data-lang')));
  });

  // Scenarios
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

  phoneInput && phoneInput.addEventListener('input', () => {
    // if user edits, deactivate scenario
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
      if (normalized === '+380671234567' || /мама/i.test(num)) {
        allowed = true; reasonKey = 'reasonMama';
      } else if (foreignPrefixes.some(p => normalized.startsWith(p))) {
        allowed = false; reasonKey = 'reasonForeign';
      } else {
        // default: unknown at night
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

  // FAQ accordion
  document.querySelectorAll('.faq-q').forEach(q => {
    q.addEventListener('click', () => {
      const item = q.parentElement;
      item.classList.toggle('open');
    });
  });

  // Share
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

  // init
  applyLang();
  // set initial scenario input
  phoneInput.value = scenarios.mama.number;
})();