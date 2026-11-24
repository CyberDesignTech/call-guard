import { animate, stagger } from 'https://cdn.jsdelivr.net/npm/animejs@4.5.0/+esm';

const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

if (!reduceMotion.matches) {
  const pendingReveal = new Set();
  const animatedElements = new Set();
  const activeAnimations = new Set();
  let revealObserver;

  function showElements(elements) {
    for (const element of elements) {
      pendingReveal.delete(element);
      element.style.visibility = 'visible';
      element.style.opacity = '1';
    }
  }

  function animateSafely(elements, options, fallback = () => showElements(elements)) {
    const targets = Array.isArray(elements) ? elements : [elements];
    targets.forEach((element) => animatedElements.add(element));
    if (reduceMotion.matches) {
      fallback();
      return null;
    }

    let animation;
    try {
      const onComplete = options.onComplete;
      animation = animate(elements, {
        ...options,
        onComplete: (...args) => {
          if (!options.loop) activeAnimations.delete(animation);
          onComplete?.(...args);
        },
      });
      activeAnimations.add(animation);
      if (!options.loop) {
        const staggerPadding = typeof options.delay === 'function' ? targets.length * 100 : 0;
        window.setTimeout(() => activeAnimations.delete(animation), (options.duration ?? 700) + staggerPadding + 1000);
      }
      return animation;
    } catch {
      fallback();
      return null;
    }
  }

  function playEntrance(elements, { delay = 0, duration = 680 } = {}) {
    if (!elements.length) return;

    elements.forEach((element) => {
      element.style.opacity = '0';
      element.style.visibility = 'hidden';
    });
    elements.forEach((element) => { element.style.visibility = 'visible'; });

    let fallbackTimer;
    const animation = animateSafely(elements, {
      opacity: [0, 1],
      translateY: [16, 0],
      delay: delay ? stagger(delay) : 0,
      duration,
      ease: 'out(3)',
      onComplete: () => {
        window.clearTimeout(fallbackTimer);
        showElements(elements);
      },
    });

    if (animation) {
      fallbackTimer = window.setTimeout(() => showElements(elements), 2400);
    }
  }

  function revealGroup(elements) {
    if (!elements.length) return;
    elements.forEach((element) => { element.style.visibility = 'visible'; });

    let fallbackTimer;
    const animation = animateSafely(elements, {
      opacity: [0, 1],
      translateY: [18, 0],
      delay: stagger(85),
      duration: 680,
      ease: 'out(3)',
      onComplete: () => {
        window.clearTimeout(fallbackTimer);
        showElements(elements);
      },
    });

    if (animation) {
      // Reveal even if an animation is interrupted or the browser drops a frame.
      fallbackTimer = window.setTimeout(() => showElements(elements), 2200);
    }
  }

  function setupScrollReveals() {
    const groups = [
      ['.feature-grid', '.feature-card'],
      ['.guide-permissions-grid', '.guide-permission'],
      ['.guide-steps', '.guide-step'],
      ['.guide-details', '.guide-details details'],
      ['.support-panel', '.support-copy, .support-actions'],
    ].flatMap(([containerSelector, itemSelector]) => {
      const container = document.querySelector(containerSelector);
      const elements = container ? [...container.querySelectorAll(itemSelector)] : [];
      if (!elements.length) return [];

      elements.forEach((element) => {
        element.style.opacity = '0';
        element.style.visibility = 'hidden';
        pendingReveal.add(element);
      });
      return [{ container, elements }];
    });

    if (!groups.length) return;
    if (!('IntersectionObserver' in window)) {
      showElements([...pendingReveal]);
      return;
    }

    try {
      revealObserver = new IntersectionObserver((entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const group = groups.find(({ container }) => container === entry.target);
          if (!group) continue;
          revealObserver.unobserve(entry.target);
          revealGroup(group.elements);
        }
      }, { threshold: 0.08, rootMargin: '0px 0px -8% 0px' });

      groups.forEach(({ container }) => revealObserver.observe(container));
    } catch {
      revealObserver?.disconnect();
      showElements([...pendingReveal]);
    }
  }

  function setupHero() {
    const hero = document.querySelector('.hero');
    if (!hero) return;

    const intro = [
      hero.querySelector('.hero-badge'),
      ...hero.querySelectorAll('.hero h1 > span'),
      hero.querySelector('.hero-copy > p'),
      ...hero.querySelectorAll('.hero-actions .button'),
      hero.querySelector('.hero-copy .release-meta'),
    ].filter(Boolean);

    playEntrance(intro, { delay: 90, duration: 700 });

    const phone = hero.querySelector('.phone');
    if (phone) {
      animateSafely(phone, {
        translateY: [-5, 5],
        duration: 3800,
        ease: 'inOutSine',
        loop: true,
        alternate: true,
      });
    }

    hero.querySelectorAll('.floating-card').forEach((card, index) => {
      animateSafely(card, {
        translateY: index === 0 ? [-3, 3] : [3, -3],
        duration: 4400,
        ease: 'inOutSine',
        loop: true,
        alternate: true,
      });
    });
  }

  function setupMicroInteractions() {
    const hovered = new WeakSet();
    const buttons = document.querySelectorAll(
      '.hero-actions .button, .nav-download, .download-actions .button[href], .support-actions .button, .input-row .button',
    );

    buttons.forEach((button) => {
      button.addEventListener('pointerenter', () => {
        hovered.add(button);
        animateSafely(button, { scale: 1.025, translateY: -2, duration: 220, ease: 'out(3)' });
      });
      button.addEventListener('pointerleave', () => {
        hovered.delete(button);
        animateSafely(button, { scale: 1, translateY: 0, duration: 240, ease: 'out(3)' });
      });
      button.addEventListener('click', () => {
        animateSafely(button, {
          scale: 0.97,
          duration: 90,
          ease: 'in(2)',
          onComplete: () => animateSafely(button, {
            scale: hovered.has(button) ? 1.025 : 1,
            translateY: hovered.has(button) ? -2 : 0,
            duration: 420,
            ease: 'outElastic(1, .5)',
          }),
        });
      });
    });

    document.querySelectorAll('.feature-card').forEach((card) => {
      card.addEventListener('pointerenter', () => {
        animateSafely(card, { translateY: -5, duration: 240, ease: 'out(3)' });
      });
      card.addEventListener('pointerleave', () => {
        animateSafely(card, { translateY: 0, duration: 280, ease: 'out(3)' });
      });
    });
  }

  function setupSimulator() {
    const form = document.querySelector('#call-form');
    const result = document.querySelector('#call-result');
    if (!form || !result) return;

    const animateResult = () => animateSafely(result, {
      opacity: [0.82, 1],
      translateY: [5, 0],
      scale: [0.985, 1],
      duration: 430,
      ease: 'out(3)',
    });

    form.addEventListener('change', (event) => {
      const radio = event.target.closest('input[name="scenario"]');
      if (!radio) return;

      const label = radio.closest('.scenario')?.querySelector(':scope > span');
      if (label) {
        animateSafely(label, {
          scale: 0.97,
          duration: 100,
          ease: 'in(2)',
          onComplete: () => animateSafely(label, {
            scale: 1,
            duration: 360,
            ease: 'outElastic(1, .5)',
          }),
        });
      }
      animateResult();
    });

    form.addEventListener('submit', animateResult);
    form.querySelector('#phone-number')?.addEventListener('input', animateResult);
  }

  setupHero();
  setupScrollReveals();
  setupMicroInteractions();
  setupSimulator();

  reduceMotion.addEventListener('change', (event) => {
    if (!event.matches) return;
    revealObserver?.disconnect();
    activeAnimations.forEach((animation) => animation.pause());
    activeAnimations.clear();
    animatedElements.forEach((element) => {
      element.style.removeProperty('translate');
      element.style.removeProperty('scale');
    });
    showElements([...animatedElements]);
    showElements([...pendingReveal]);
  });
}
