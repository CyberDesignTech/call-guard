'use strict';

const privacyMessages = window.CowgateMessages;
const privacyLanguageSelect = document.querySelector('#privacy-language');
let privacyLanguage;
try {
  privacyLanguage = localStorage.getItem('cowgate-language');
} catch {
  privacyLanguage = null;
}

function setPrivacyLanguage(value) {
  const language = Object.hasOwn(privacyMessages, value) ? value : 'uk';
  document.documentElement.lang = language;
  privacyLanguageSelect.value = language;
  document.title = `CallGate — ${privacyMessages[language].privacyTitle}`;
  document.querySelector('meta[name="description"]').content = privacyMessages[language].privacyIntro;
  for (const element of document.querySelectorAll('[data-t]')) {
    element.textContent = privacyMessages[language][element.dataset.t] ?? privacyMessages.uk[element.dataset.t];
  }
  try {
    localStorage.setItem('cowgate-language', language);
  } catch {
    // Language persistence is optional for a standalone privacy page.
  }
}

privacyLanguageSelect.addEventListener('change', () => setPrivacyLanguage(privacyLanguageSelect.value));
setPrivacyLanguage(privacyLanguage ?? 'uk');
