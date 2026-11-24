'use strict';

const messages = window.CowgateMessages;
const html = document.documentElement;
const languageSelect = document.querySelector('#language');
const form = document.querySelector('#call-form');
const input = document.querySelector('#phone-number');
const radios = [...form.querySelectorAll('input[name="scenario"]')];
const result = document.querySelector('#call-result');
const resultTitle = document.querySelector('#result-title');
const resultBody = document.querySelector('#result-body');
const resultIcon = result.querySelector('use');
const navigation = document.querySelector('#site-nav');
const menu = document.querySelector('.menu-toggle');
const share = document.querySelector('#share');
const notice = document.querySelector('#notice');

const examples = {
  allowlist: '+1 202 555 0142',
  night: '+1 202 555 0171',
  repeat: '+1 202 555 0171',
  foreign: '+44 20 7946 0958',
};
const demoAllowlistNumber = '12025550142';
const emergencyNumbers = new Set(['101', '102', '103', '104', '112', '911', '999']);
const resultIcons = { idle: 'phone', allowed: 'check', blocked: 'phone-off', invalid: 'close' };
let currentResult = { state: 'idle', title: 'resultIdleTitle', body: 'resultIdleBody' };
let language = 'uk';
let noticeTimer;

html.classList.add('js');

function translate(key) {
  return messages[language][key] ?? messages.uk[key];
}

function displayResult() {
  const { state, title, body } = currentResult;
  result.dataset.status = state;
  resultTitle.textContent = translate(title);
  resultBody.textContent = translate(body);
  resultIcon.setAttribute('href', `#i-${resultIcons[state]}`);
  input.setAttribute('aria-invalid', String(state === 'invalid'));
}

function setLanguage(value) {
  language = Object.hasOwn(messages, value) ? value : 'uk';
  languageSelect.value = language;
  html.lang = language;
  document.title = translate('pageTitle');
  document.querySelector('meta[name="description"]').content = translate('pageDescription');
  for (const element of document.querySelectorAll('[data-t]')) {
    element.textContent = translate(element.dataset.t);
  }
  for (const element of document.querySelectorAll('[data-a]')) {
    element.setAttribute('aria-label', translate(element.dataset.a));
  }
  displayResult();
}

function checkNumber(number, scenario) {
  const value = number.trim();
  const digits = value.replace(/\D/g, '');
  const normalized = value.startsWith('00') ? digits.slice(2) : digits;

  if (!/^\+?[\d\s().-]+$/.test(value) || normalized.length < 2 || normalized.length > 15) {
    return { state: 'invalid', title: 'resultInvalidTitle', body: 'resultInvalidBody' };
  }
  if (emergencyNumbers.has(normalized)) {
    return { state: 'allowed', title: 'resultAllowed', body: 'reasonEmergency' };
  }
  if (normalized === demoAllowlistNumber) {
    return { state: 'allowed', title: 'resultAllowed', body: 'reasonAllowlist' };
  }
  if (normalized.length > 6 && normalized.startsWith('44')) {
    return { state: 'blocked', title: 'resultBlocked', body: 'reasonForeign' };
  }
  if (scenario === 'night') {
    return { state: 'blocked', title: 'resultBlocked', body: 'reasonNight' };
  }
  if (scenario === 'repeat') {
    return { state: 'allowed', title: 'resultAllowed', body: 'reasonRepeat' };
  }
  return { state: 'allowed', title: 'resultAllowed', body: 'reasonDefault' };
}

function runSimulation() {
  const selected = radios.find((radio) => radio.checked)?.value;
  currentResult = checkNumber(input.value, selected);
  displayResult();
  if (currentResult.state === 'invalid') input.focus();
}

for (const radio of radios) {
  radio.addEventListener('change', () => {
    input.value = examples[radio.value];
    runSimulation();
  });
}
input.addEventListener('input', () => {
  for (const radio of radios) radio.checked = false;
  currentResult = { state: 'idle', title: 'resultIdleTitle', body: 'resultIdleBody' };
  displayResult();
});
form.addEventListener('submit', (event) => {
  event.preventDefault();
  runSimulation();
});

function setMenu(open) {
  navigation.classList.toggle('is-open', open);
  menu.setAttribute('aria-expanded', String(open));
}

menu.addEventListener('click', () => setMenu(menu.getAttribute('aria-expanded') !== 'true'));
navigation.addEventListener('click', (event) => {
  if (event.target.closest('a')) setMenu(false);
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && menu.getAttribute('aria-expanded') === 'true') {
    setMenu(false);
    menu.focus();
  }
});

languageSelect.addEventListener('change', () => {
  setLanguage(languageSelect.value);
  try {
    localStorage.setItem('cowgate-language', language);
  } catch {
    // Browser storage is optional for a standalone copy of the site.
  }
});

function showNotice(key) {
  window.clearTimeout(noticeTimer);
  notice.textContent = translate(key);
  notice.hidden = false;
  noticeTimer = window.setTimeout(() => { notice.hidden = true; }, 3200);
}

if (/^https?:$/.test(window.location.protocol) && (navigator.share || navigator.clipboard)) {
  share.hidden = false;
  share.addEventListener('click', async () => {
    const url = new URL(window.location.href);
    url.hash = '';
    try {
      if (navigator.share) {
        await navigator.share({ title: document.title, url: url.href });
      } else {
        await navigator.clipboard.writeText(url.href);
        showNotice('shareCopied');
      }
    } catch (error) {
      if (error.name !== 'AbortError') showNotice('shareError');
    }
  });
}

let savedLanguage;
try {
  savedLanguage = localStorage.getItem('cowgate-language');
} catch {
  // Ukrainian remains available when browser storage is disabled.
}
setLanguage(savedLanguage ?? 'uk');
