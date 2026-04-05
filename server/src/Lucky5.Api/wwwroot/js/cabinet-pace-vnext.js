/**
 * cabinet-pace-vnext.js
 * OWNER: Codex Agent 2
 * PURPOSE: Count-up animations, win collection pacing, Lucky5 flash, jackpot fill.
 * LOADS AFTER: cabinet-stage-vnext.js
 * DO NOT EDIT: game.css, game.js, index.html, any .cs backend files
 *
 * Expose API on window.CabinetPace — game.js calls these after state transitions.
 * No game logic here — purely presentation timing and animation.
 */

'use strict';

window.CabinetPace = (function () {

    const _fmt = new Intl.NumberFormat('en-US', { maximumFractionDigits: 0 });

    /* ── countUp ─────────────────────────────────────────────────────────── */
    /**
     * Animate a numeric element from startValue to endValue over durationMs.
     * Uses requestAnimationFrame. Sets element.textContent.
     * @param {HTMLElement} element
     * @param {number} startValue
     * @param {number} endValue
     * @param {number} durationMs
     * @param {function} [onComplete]
     */
    function countUp(element, startValue, endValue, durationMs, onComplete) {
        if (!element) { if (onComplete) onComplete(); return; }
        if (startValue === endValue) {
            element.textContent = _fmt.format(endValue);
            if (onComplete) onComplete();
            return;
        }
        const start = performance.now();
        const range = endValue - startValue;

        function step(now) {
            const elapsed = now - start;
            const progress = Math.min(elapsed / durationMs, 1);
            // ease-out cubic
            const ease = 1 - Math.pow(1 - progress, 3);
            const current = Math.round(startValue + range * ease);
            element.textContent = _fmt.format(current);
            if (progress < 1) {
                requestAnimationFrame(step);
            } else {
                element.textContent = _fmt.format(endValue);
                if (onComplete) onComplete();
            }
        }

        requestAnimationFrame(step);
    }

    /* ── collectWin ──────────────────────────────────────────────────────── */
    /**
     * Show win amount instantly, then count credits up by winAmount.
     * Duration scales with amount: 1500ms (small) to 5000ms (large).
     * @param {number} winAmount
     * @param {number} currentCredits   — credits BEFORE the win is added
     * @param {number} newCredits       — credits AFTER collection
     * @param {function} [onComplete]
     */
    function collectWin(winAmount, currentCredits, newCredits, onComplete) {
        // Show win amount immediately
        const winEl = document.getElementById('win-amount-value');
        if (winEl) winEl.textContent = _fmt.format(winAmount);

        // Scale duration: 1500ms base, +200ms per 50k, capped at 5000ms
        const duration = Math.min(1500 + Math.floor(winAmount / 50000) * 200, 5000);

        // Brief pause then count credits up
        setTimeout(() => {
            const credEl = document.querySelector('#credits span');
            if (credEl) {
                countUp(credEl, currentCredits, newCredits, duration, onComplete);
            } else {
                if (onComplete) onComplete();
            }
        }, 350);
    }

    /* ── fillJackpot ─────────────────────────────────────────────────────── */
    /**
     * Count a jackpot meter from fromValue to toValue over 10-15 seconds.
     * @param {HTMLElement} jpCvalElement   — the .jp-cval span inside a .jp-counter
     * @param {number} fromValue
     * @param {number} toValue
     * @param {function} [onComplete]
     */
    function fillJackpot(jpCvalElement, fromValue, toValue, onComplete) {
        const delta = toValue - fromValue;
        // 10000ms base, +1000ms per 500k delta, capped at 15000ms
        const duration = Math.min(10000 + Math.floor(delta / 500000) * 1000, 15000);
        countUp(jpCvalElement, fromValue, toValue, duration, onComplete);
    }

    /* ── flashLucky5 ─────────────────────────────────────────────────────── */
    /**
     * Brief white/gold screen flash + banner flicker. Non-blocking.
     */
    function flashLucky5() {
        const flashEl = document.getElementById('lucky5-flash');
        if (flashEl) {
            flashEl.classList.remove('active');
            // force reflow
            void flashEl.offsetWidth;
            flashEl.classList.add('active');
            setTimeout(() => flashEl.classList.remove('active'), 1400);
        }

        // Also trigger stage glow/banner
        if (window.CabinetStage && window.CabinetStage.showLucky5Active) {
            window.CabinetStage.showLucky5Active();
        }
    }

    /* ── animateJackpotCounters ──────────────────────────────────────────── */
    /**
     * Incrementally update the live jackpot counter displays from SignalR/API data.
     * Short count-up (300ms) for live trickle updates.
     * @param {{ fourOfAKindA, fourOfAKindB, straightFlush, fullHouse }} jackpots
     * @param {{ fourOfAKindA, fourOfAKindB, straightFlush, fullHouse }} prevJackpots
     */
    function animateJackpotCounters(jackpots, prevJackpots) {
        if (!jackpots) return;
        const DURATION = 300;

        const targets = [
            { el: document.querySelector('#jp-counter-a .jp-cval'),      from: prevJackpots?.fourOfAKindA || 0, to: jackpots.fourOfAKindA },
            { el: document.querySelector('#jp-counter-b .jp-cval'),      from: prevJackpots?.fourOfAKindB || 0, to: jackpots.fourOfAKindB },
            { el: document.querySelector('#jp-counter-center .jp-cval'), from: prevJackpots?.straightFlush || 0, to: jackpots.straightFlush },
            { el: document.querySelector('#jp-counter-fh .jp-cval'),     from: prevJackpots?.fullHouse || 0,    to: jackpots.fullHouse },
        ];

        targets.forEach(({ el, from, to }) => {
            if (!el || from === to) return;
            countUp(el, Number(from), Number(to), DURATION);
        });
    }

    /* ── public API ──────────────────────────────────────────────────────── */

    return {
        countUp,
        collectWin,
        fillJackpot,
        flashLucky5,
        animateJackpotCounters,
    };

}());
