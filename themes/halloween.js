// ============================================================
// Halloween skin — decorations and effects for index.html
// Runs only when <html data-skin="halloween">. It never touches cart, price or order logic:
// it only adds decorative elements and watches the page (MutationObserver) to know when to play them.
// ============================================================
(function () {
  if (document.documentElement.getAttribute('data-skin') !== 'halloween') return;

  const REDUCE = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ── Original SVG artwork ──
  const SVG = {
    bat: '<svg viewBox="0 0 60 30" aria-hidden="true"><path d="M30 8c-2-4-3-6-5-6 0 3-1 5-3 6C16 5 8 6 2 14c5-2 8-1 10 2 2-2 5-2 7 0 2-2 5-1 6 4 1-4 3-4 5-4s3 0 5 4c1-5 4-6 6-4 2-2 5-2 7 0 2-3 5-4 10-2-6-8-14-9-20-6-2-1-3-3-3-6-2 0-3 2-5 6z" fill="#1B1D2A"/><circle cx="27.5" cy="9" r="1.1" fill="#F6B23C"/><circle cx="32.5" cy="9" r="1.1" fill="#F6B23C"/></svg>',
    ghost: '<svg viewBox="0 0 40 48" aria-hidden="true"><path d="M5 44V20C5 10 11.5 4 20 4s15 6 15 16v24l-5-4-5 4-5-4-5 4-5-4z" fill="#F7F4EE" stroke="#14203B" stroke-width="2.5" stroke-linejoin="round"/><ellipse cx="14.5" cy="20" rx="2.6" ry="3.6" fill="#14203B"/><ellipse cx="25.5" cy="20" rx="2.6" ry="3.6" fill="#14203B"/><ellipse cx="20" cy="29" rx="2.6" ry="3.2" fill="#14203B"/></svg>',
    spider: '<svg viewBox="0 0 40 40" aria-hidden="true"><g stroke="#14203B" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M14 18 8 12 4 14M14 21H3M14 24l-6 4-3 5M16 27l-4 6v4M26 18l6-6 4 2M26 21h11M26 24l6 4 3 5M24 27l4 6v4"/></g><ellipse cx="20" cy="24" rx="8" ry="9" fill="#14203B"/><circle cx="20" cy="14" r="5" fill="#14203B"/><circle cx="18" cy="13" r="1.4" fill="#F7F4EE"/><circle cx="22" cy="13" r="1.4" fill="#F7F4EE"/><path d="M17 23h6M20 20v8" stroke="#F2862E" stroke-width="1.6" stroke-linecap="round"/></svg>',
    pumpkin: '<svg viewBox="0 0 60 56" aria-hidden="true"><path d="M28 14c0-5 1-8 4-10" stroke="#14203B" stroke-width="4" fill="none" stroke-linecap="round"/><ellipse cx="30" cy="34" rx="26" ry="20" fill="#F2862E" stroke="#14203B" stroke-width="2.5"/><path d="M15 28l7 5h-7zM45 28l-7 5h7zM17 41q13 8 26 0l-4 4-4-3-4 3-4-3-4 3-3-3z" fill="#14203B"/></svg>',
    // Cobweb anchored in the bottom-right corner (64,64)
    web: '<svg viewBox="0 0 64 64" fill="none" stroke="rgba(255,255,255,0.9)" stroke-width="1.2" stroke-linecap="round" aria-hidden="true"><path d="M64 64H0M64 64 8 30M64 64 32 4M64 64V0"/><path d="M48 64Q51 61 50 55.5Q54 53 56 49Q61 49 64 48M28.8 64Q35 56 33.2 45.3Q42 40 46.4 31Q57 32 64 28.8M9.6 64Q19 50 16.4 35.1Q30 27 36.8 13Q52 15 64 9.6"/></svg>'
  };

  function el(cls, html) {
    const d = document.createElement('div');
    d.className = cls;
    d.innerHTML = html;
    return d;
  }

  // ── 1. Bats over the hero artwork ──
  const heroArt = document.querySelector('.hero-art');
  if (heroArt && !REDUCE) {
    ['', ' b2', ' b3'].forEach(c => heroArt.appendChild(el('hw-bat' + c, SVG.bat)));
  }

  // ── 2. Slanted ticker band under the hero ──
  const hero = document.getElementById('hero');
  if (hero) {
    const words = 'TRICK OR TREAT <b>✦</b> HAPPY HALLOWEEN <b>✦</b> MATCHA POTION NIGHT <b>✦</b> 31.10 <b>✦</b> ';
    const wrap = el('hw-ticker-wrap', '<div class="hw-ticker"><div class="hw-ticker-track"><span>' + words + words + '</span><span>' + words + words + '</span></div></div>');
    wrap.setAttribute('aria-hidden', 'true');
    hero.insertAdjacentElement('afterend', wrap);
  }

  // ── 3. Menu cards: a ghost peeks over some cards, a spider hangs into some photos, cobwebs in corners ──
  // renderMenu() rebuilds the grid on every category change, so decorate whatever is there after each render.
  function decorateCards() {
    document.querySelectorAll('#menuGrid .menu-card').forEach((card, idx) => {
      if (card.dataset.hw) return;
      card.dataset.hw = '1';
      const photo = card.querySelector('.menu-img-wrap');
      if (idx % 4 === 1) {
        const g = el('hw-peek', SVG.ghost);
        g.style.setProperty('--hw-delay', -((idx * 1.3) % 5) + 's');   // cards don't peek in sync
        card.appendChild(g);
      }
      if (photo && idx % 5 === 3) photo.appendChild(el('hw-hang', '<i></i>' + SVG.spider));
      if (photo && idx % 6 === 0) photo.appendChild(el('hw-web', SVG.web));
    });
  }
  const grid = document.getElementById('menuGrid');
  if (grid) {
    new MutationObserver(decorateCards).observe(grid, { childList: true });
    decorateCards();
  }

  // ── 4. Spider drops onto the cart bar whenever the cup count goes up ──
  const barWrap  = document.getElementById('cartBarWrap');
  const barCount = document.getElementById('cartBarCount');
  if (barWrap && barCount && !REDUCE) {
    const drop = el('hw-drop', '<i></i>' + SVG.spider);
    barWrap.appendChild(drop);
    let last = parseInt(barCount.textContent, 10) || 0;
    new MutationObserver(() => {
      const now = parseInt(barCount.textContent, 10) || 0;
      if (now > last) {
        void drop.offsetWidth;   // the bar may have just un-hidden: settle the start position so the drop animates
        drop.classList.add('down');
        setTimeout(() => drop.classList.remove('down'), 1500);
      }
      last = now;
    }).observe(barCount, { childList: true, characterData: true, subtree: true });
  }

  // ── 5. Order placed: ghosts, bats and pumpkins float up once ──
  const confirmScreen = document.getElementById('confirmationScreen');
  if (confirmScreen && !REDUCE) {
    let shown = false;
    new MutationObserver(() => {
      const isShown = confirmScreen.classList.contains('show');
      if (isShown && !shown) floatBurst();
      shown = isShown;
    }).observe(confirmScreen, { attributes: true, attributeFilter: ['class'] });
  }
  function floatBurst() {
    const art = [SVG.ghost, SVG.bat, SVG.pumpkin];
    for (let i = 0; i < 8; i++) {
      const f = el('hw-float', art[i % 3]);
      f.style.left = (5 + Math.random() * 82) + 'vw';
      f.style.animationDelay = (i * 0.18) + 's';
      f.style.setProperty('--dx', (Math.random() * 80 - 40) + 'px');
      f.style.setProperty('--rot', (Math.random() * 40 - 20) + 'deg');
      document.body.appendChild(f);
      setTimeout(() => f.remove(), 4500);
    }
  }

  // ── 6. Tap sparks: six tiny stars per tap, removed after the animation ──
  if (!REDUCE) {
    const inks = ['#F2862E', '#F6B23C', '#F7F4EE', '#86BC50'];
    document.addEventListener('pointerdown', e => {
      for (let i = 0; i < 6; i++) {
        const s = document.createElement('span');
        const a = Math.PI * 2 * i / 6 + Math.random() * 0.4;
        const d = 22 + Math.random() * 16;
        s.className = 'hw-spark';
        s.style.left = (e.clientX - 6) + 'px';
        s.style.top  = (e.clientY - 6) + 'px';
        s.style.background = inks[i % inks.length];
        s.style.setProperty('--dx', Math.cos(a) * d + 'px');
        s.style.setProperty('--dy', Math.sin(a) * d + 'px');
        document.body.appendChild(s);
        setTimeout(() => s.remove(), 650);
      }
    }, { passive: true });
  }
})();
