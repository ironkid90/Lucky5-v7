/**
 * cabinet-stage-vnext.js
 * OWNER: Codex Agent 2
 * PURPOSE: Card stage choreography, hold-lamp state, button press assets, double-up viewport.
 * LOADS AFTER: game.js
 * DO NOT EDIT: game.css, game.js, index.html, any .cs backend files
 *
 * Expose API on window.CabinetStage — game.js calls these at key state transitions.
 * Read game.js globals (cards, holdIndexes, gameState, duCardTrail, duDealerCard,
 * ALL_CARD_CODES, preloadedImages) but never write to them.
 *
 * Asset paths (images are in /assets/images/ root):
 *   Card PNGs:   /assets/images/cards/{rank}{suit}.png  e.g. AH.png, 5S.png, 10C.png
 *   Card back:   /assets/images/cards/bside.png
 *   Hold off:    /assets/images/hold_off.png
 *   Hold on:     /assets/images/hold_on.png
 *   Big:         /assets/images/big.png / big_on.png
 *   Small:       /assets/images/small.png / small_on.png
 *   Cancel hold: /assets/images/cancel_hold.png / cancel_hold_on.png
 *   Deal draw:   /assets/images/deal_draw.png / deal_draw_on.png
 *   Bet:         /assets/images/bet.png / bet_on.png
 *   Take half:   /assets/images/take_half.png / take_half_on.png
 *   Take score:  /assets/images/take_score.png / take_score_on.png
 *
 * DOM contract (all IDs frozen in index.html after Phase 0.4):
 *   #card-area                 — card stage container
 *   .card-slot[data-slot=0..4] — individual card columns
 *   .card-face img             — card image inside each slot
 *   .hold-badge                — HOLD text label on card
 *   #hold-row .cab-hold[data-index=0..4] — hold buttons
 *   #btn-big, #btn-small, #btn-cancel, #btn-deal, #btn-bet
 *   #btn-take-half, #btn-take-score
 *   #lucky5-flash, #lucky5-banner
 *   #game-message, #bonus-text
 *   #win-amount-value, #win-slot-tag
 */

'use strict';

window.CabinetStage = (function () {

    // Use variant config if available, otherwise fall back to known defaults.
    const _cfg  = (typeof GAME_CONFIG !== 'undefined') ? GAME_CONFIG : null;
    const CARD_BACK = _cfg ? _cfg.assets.cardBack : '/assets/images/cards/bside.png';
    const SHUFFLE_MS = _cfg ? _cfg.timing.shuffleFrameMs : 120;
    let _shuffleInterval = null;
    let _isDoubleUpMode = false;

    /* ── helpers ─────────────────────────────────────────────────────────── */

    function _cardSrc(code) {
        return `/assets/images/cards/${code}.png`;
    }

    function _slot(index) {
        return document.querySelector(`.card-slot[data-slot="${index}"]`);
    }

    function _cardImg(slotEl) {
        return slotEl ? slotEl.querySelector('.card-face img') : null;
    }

    function _holdBtn(index) {
        return document.querySelector(`#hold-row .cab-hold[data-index="${index}"]`);
    }

    /* ── initCardSlots ───────────────────────────────────────────────────── */
    /**
     * Build five fixed .card-slot elements inside #card-area.
     * Called once on page load after assets are ready.
     */
    function initCardSlots() {
        const area = document.getElementById('card-area');
        if (!area) return;
        area.innerHTML = '';
        for (let i = 0; i < 5; i++) {
            const slot = document.createElement('div');
            slot.className = 'card-slot';
            slot.dataset.slot = i;

            const face = document.createElement('div');
            face.className = 'card-face';

            const img = document.createElement('img');
            img.src = CARD_BACK;
            img.alt = '';

            face.appendChild(img);

            const badge = document.createElement('div');
            badge.className = 'hold-badge';
            badge.textContent = 'HOLD';

            slot.appendChild(face);
            slot.appendChild(badge);
            area.appendChild(slot);
        }
        _isDoubleUpMode = false;
    }

    /* ── dealCards ───────────────────────────────────────────────────────── */
    /**
     * Animate 5 cards into slots left-to-right with stagger.
     * @param {Array<{rank:string, suit:string, code:string}>} cardArray
     * @param {function} [onComplete]
     */
    function dealCards(cardArray, onComplete) {
        clearAllHolds();
        const stagger = 110; // ms between each card
        cardArray.forEach((card, i) => {
            setTimeout(() => {
                const slotEl = _slot(i);
                if (!slotEl) return;
                const img = _cardImg(slotEl);
                if (!img) return;
                // reset position
                slotEl.classList.remove('deal-in-done', 'deal-in');
                slotEl.style.opacity = '0';
                slotEl.style.transform = 'translateY(-60px)';
                // set image
                img.src = _cardSrc(card.code);
                // animate in
                requestAnimationFrame(() => {
                    requestAnimationFrame(() => {
                        slotEl.style.transition = 'opacity 0.18s ease-out, transform 0.22s ease-out';
                        slotEl.style.opacity = '1';
                        slotEl.style.transform = 'translateY(0)';
                    });
                });
                if (i === cardArray.length - 1 && onComplete) {
                    setTimeout(onComplete, 250);
                }
            }, i * stagger);
        });
    }

    /* ── drawCards ───────────────────────────────────────────────────────── */
    /**
     * Replace non-held cards with new cards using a brief flip.
     * @param {Array<{rank:string, suit:string, code:string}>} newCardArray
     * @param {Set|Array<number>} heldIndexes
     * @param {function} [onComplete]
     */
    function drawCards(newCardArray, heldIndexes, onComplete) {
        const held = new Set(heldIndexes);
        let pending = 0;

        newCardArray.forEach((card, i) => {
            if (held.has(i)) return; // held — no change
            pending++;
            const slotEl = _slot(i);
            if (!slotEl) return;
            const face = slotEl.querySelector('.card-face');
            const img = _cardImg(slotEl);
            if (!img) return;

            // flip out
            setTimeout(() => {
                if (face) {
                    face.style.transition = 'opacity 0.07s ease-in';
                    face.style.opacity = '0';
                }
                setTimeout(() => {
                    img.src = _cardSrc(card.code);
                    if (face) {
                        face.style.transition = 'opacity 0.1s ease-out';
                        face.style.opacity = '1';
                    }
                    pending--;
                    if (pending === 0 && onComplete) onComplete();
                }, 75);
            }, i * 40);
        });

        if (pending === 0 && onComplete) onComplete();
    }

    /* ── setHold ─────────────────────────────────────────────────────────── */
    /**
     * Toggle hold state on a card slot and its hold button.
     * @param {number} slotIndex
     * @param {boolean} isHeld
     */
    function setHold(slotIndex, isHeld) {
        const slotEl = _slot(slotIndex);
        if (slotEl) slotEl.classList.toggle('held', isHeld);

        const btn = _holdBtn(slotIndex);
        if (btn) {
            btn.classList.toggle('active', isHeld);
            btn.style.backgroundImage = isHeld
                ? "url('/assets/images/hold_on.png')"
                : "url('/assets/images/hold_off.png')";
        }
    }

    /* ── clearAllHolds ───────────────────────────────────────────────────── */
    function clearAllHolds() {
        for (let i = 0; i < 5; i++) setHold(i, false);
    }

    /* ── initButtonAssets ────────────────────────────────────────────────── */
    /**
     * Wire pressed/released asset swaps for all cabinet buttons.
     * Purely cosmetic — does not add game logic.
     */
    function initButtonAssets() {
        const BTN_ASSETS = {
            'btn-big':        ['big.png', 'big_on.png'],
            'btn-small':      ['small.png', 'small_on.png'],
            'btn-cancel':     ['cancel_hold.png', 'cancel_hold_on.png'],
            'btn-deal':       ['deal_draw.png', 'deal_draw_on.png'],
            'btn-bet':        ['bet.png', 'bet_on.png'],
            'btn-take-half':  ['take_half.png', 'take_half_on.png'],
            'btn-take-score': ['take_score.png', 'take_score_on.png'],
        };

        Object.entries(BTN_ASSETS).forEach(([id, [off, on]]) => {
            const btn = document.getElementById(id);
            if (!btn) return;
            const offUrl = `url('/assets/images/${off}')`;
            const onUrl  = `url('/assets/images/${on}')`;
            btn.style.backgroundImage = offUrl;
            const press   = () => { btn.style.backgroundImage = onUrl; };
            const release = () => { btn.style.backgroundImage = offUrl; };
            btn.addEventListener('mousedown',   press);
            btn.addEventListener('touchstart',  press,   { passive: true });
            btn.addEventListener('mouseup',     release);
            btn.addEventListener('touchend',    release, { passive: true });
            btn.addEventListener('mouseleave',  release);
        });

        // Hold buttons
        document.querySelectorAll('#hold-row .cab-hold').forEach(btn => {
            const isActive = () => btn.classList.contains('active');
            btn.addEventListener('mousedown',  () => {
                btn.style.backgroundImage = "url('/assets/images/hold_on.png')";
            });
            btn.addEventListener('mouseup',    () => {
                if (!isActive()) btn.style.backgroundImage = "url('/assets/images/hold_off.png')";
            });
            btn.addEventListener('mouseleave', () => {
                if (!isActive()) btn.style.backgroundImage = "url('/assets/images/hold_off.png')";
            });
        });
    }

    /* ── enterDoubleUp ───────────────────────────────────────────────────── */
    /**
     * Repurpose #card-area for double-up trail viewport.
     * Layout: slots 0-2 = trail | slot 3 = dealer | slot 4 = challenger
     * @param {{ rank:string, suit:string, code:string }} dealerCard
     */
    function enterDoubleUp(dealerCard) {
        const area = document.getElementById('card-area');
        if (!area) return;
        _stopShuffle();
        area.classList.add('du-mode');
        _isDoubleUpMode = true;

        // Rebuild as du-card-slot elements
        area.innerHTML = '';
        for (let i = 0; i < 5; i++) {
            const slot = document.createElement('div');
            slot.className = 'du-card-slot';
            slot.dataset.duSlot = i;

            const label = document.createElement('div');
            label.className = 'du-card-label';

            const frame = document.createElement('div');
            frame.className = 'du-card-frame';

            const img = document.createElement('img');
            img.src = CARD_BACK;
            img.alt = '';

            frame.appendChild(img);
            slot.appendChild(label);
            slot.appendChild(frame);
            area.appendChild(slot);
        }

        // Show dealer in slot 3
        const dealerSlot = _duSlot(3);
        if (dealerSlot && dealerCard) {
            _duSlot(3).querySelector('img').src = _cardSrc(dealerCard.code);
            _duSlot(3).querySelector('.du-card-frame').classList.add('dealer-card');
        }

        // Start shuffle in slot 4
        _startShuffle(4);
    }

    /* ── updateDoubleUpTrail ─────────────────────────────────────────────── */
    /**
     * @param {Array<{code:string}>} trailCards   — up to 3 previous cards (slots 0-2)
     * @param {{ code:string }}      dealerCard    — always in slot 3
     * @param {{ code:string }|null} challengerCard — null = keep shuffling; set = reveal
     * @param {string}               status        — 'win'|'lose'|'push'|'pending'|...
     */
    function updateDoubleUpTrail(trailCards, dealerCard, challengerCard, status) {
        // Trail cards in slots 0-2
        (trailCards || []).slice(0, 3).forEach((card, i) => {
            const slotEl = _duSlot(i);
            if (!slotEl || !card) return;
            slotEl.querySelector('img').src = _cardSrc(card.code);
            slotEl.classList.add('du-trail-card');
        });

        // Dealer in slot 3
        const dealerSlot = _duSlot(3);
        if (dealerSlot && dealerCard) {
            dealerSlot.querySelector('img').src = _cardSrc(dealerCard.code);
            dealerSlot.querySelector('.du-card-frame').classList.add('dealer-card');
        }

        // Challenger in slot 4
        const challSlot = _duSlot(4);
        if (challSlot) {
            if (challengerCard) {
                _stopShuffle();
                challSlot.classList.remove('du-shuffling');
                const challImg = challSlot.querySelector('img');
                challImg.src = _cardSrc(challengerCard.code);

                // Set BIG / SMALL label
                const label = challSlot.querySelector('.du-card-label');
                if (label) {
                    if (status === 'win')  label.textContent = 'BIG';
                    else if (status === 'lose') label.textContent = 'SMALL';
                    else label.textContent = '';
                }

                // Lucky5 glow on 5S
                if (challengerCard.code === '5S') {
                    challSlot.querySelector('.du-card-frame').classList.add('lucky5-glow');
                }
            } else {
                // Keep shuffling
                if (!challSlot.classList.contains('du-shuffling')) {
                    _startShuffle(4);
                }
            }
        }
    }

    /* ── exitDoubleUp ────────────────────────────────────────────────────── */
    function exitDoubleUp() {
        _stopShuffle();
        _isDoubleUpMode = false;
        const area = document.getElementById('card-area');
        if (area) area.classList.remove('du-mode');
        initCardSlots();
    }

    /* ── showLucky5Active ────────────────────────────────────────────────── */
    function showLucky5Active() {
        const banner = document.getElementById('lucky5-banner');
        if (banner) {
            banner.classList.add('active');
            if (window.lucky5FlashResetTimer) clearTimeout(window.lucky5FlashResetTimer);
            window.lucky5FlashResetTimer = setTimeout(() => {
                banner.classList.remove('active');
            }, 700);
        }
        // Glow on all card slots
        document.querySelectorAll('.card-slot').forEach(s => {
            s.classList.add('lucky5-active');
            setTimeout(() => s.classList.remove('lucky5-active'), 700);
        });
    }

    /* ── internal: double-up slot helpers ───────────────────────────────── */

    function _duSlot(index) {
        return document.querySelector(`.du-card-slot[data-du-slot="${index}"]`);
    }

    function _startShuffle(slotIndex) {
        _stopShuffle();
        const slotEl = _duSlot(slotIndex);
        if (!slotEl) return;
        slotEl.classList.add('du-shuffling');
        const img = slotEl.querySelector('img');
        if (!img) return;
        const allCodes = window.ALL_CARD_CODES || [];
        _shuffleInterval = setInterval(() => {
            if (allCodes.length > 0) {
                const code = allCodes[Math.floor(Math.random() * allCodes.length)];
                img.src = `/assets/images/cards/${code}.png`;
            }
        }, SHUFFLE_MS);
    }

    function _stopShuffle() {
        if (_shuffleInterval) {
            clearInterval(_shuffleInterval);
            _shuffleInterval = null;
        }
    }

    /* ── public API ──────────────────────────────────────────────────────── */

    return {
        initCardSlots,
        dealCards,
        drawCards,
        setHold,
        clearAllHolds,
        initButtonAssets,
        enterDoubleUp,
        updateDoubleUpTrail,
        exitDoubleUp,
        showLucky5Active,
    };

}());
