(function () {
  function formatNumber(value) {
    return new Intl.NumberFormat('en-US').format(Math.max(0, Math.round(Number(value) || 0)));
  }

  function parseValue(input) {
    if (typeof input === 'number') return input;
    const raw = String(input == null ? '' : input).replace(/[^0-9.-]/g, '');
    return Number(raw || 0);
  }

  function countUp(element, startValue, endValue, durationMs, onComplete) {
    if (!element) return;
    const start = performance.now();
    const from = Number(startValue) || 0;
    const to = Number(endValue) || 0;
    const duration = Math.max(16, Number(durationMs) || 300);

    function frame(now) {
      const progress = Math.min(1, (now - start) / duration);
      const value = from + ((to - from) * progress);
      element.textContent = formatNumber(value);
      if (progress < 1) {
        window.requestAnimationFrame(frame);
      } else if (typeof onComplete === 'function') {
        onComplete();
      }
    }

    window.requestAnimationFrame(frame);
  }

  function collectWin(winAmount, currentCredits, onComplete) {
    const winEl = document.getElementById('win-amount-value');
    const creditsEl = document.querySelector('#credits span, #credits');
    const baseCredits = parseValue(creditsEl ? creditsEl.textContent : 0);
    const amount = Number(winAmount) || 0;
    const targetCredits = Number(currentCredits) || (baseCredits + amount);
    if (winEl) winEl.textContent = formatNumber(amount);
    const duration = Math.max(1500, Math.min(5000, 1500 + (amount / 40000)));
    window.setTimeout(() => {
      countUp(creditsEl, baseCredits, targetCredits, duration, onComplete);
    }, 400);
  }

  function fillJackpot(jpElement, fromValue, toValue, onComplete) {
    const delta = Math.abs((Number(toValue) || 0) - (Number(fromValue) || 0));
    const duration = Math.max(10000, Math.min(15000, 10000 + (delta / 5000)));
    countUp(jpElement, fromValue, toValue, duration, onComplete);
  }

  function flashLucky5() {
    const flash = document.getElementById('lucky5-flash');
    const banner = document.getElementById('lucky5-banner');
    if (flash) {
      flash.classList.remove('flash-active');
      void flash.offsetWidth;
      flash.classList.add('flash-active');
    }
    if (banner) {
      banner.classList.add('active');
      banner.classList.add('banner-flicker');
      window.setTimeout(() => banner.classList.remove('banner-flicker'), 700);
    }
  }

  window.CabinetPace = {
    countUp,
    collectWin,
    fillJackpot,
    flashLucky5,
    formatNumber,
  };
})();

SimplyCodes
