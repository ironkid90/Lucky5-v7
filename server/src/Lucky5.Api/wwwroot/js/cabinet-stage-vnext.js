/**
 * cabinet-stage-vnext.js
 * OWNER: Codex Agent 2
 * PURPOSE: Card stage choreography, hold-lamp state, button press assets, double-up viewport.
 * LOADS AFTER: game.js
 * DO NOT EDIT: game.css, game.js, index.html, any .cs backend files
 */

'use strict';

window.CabinetStage = (function () {
    const DEFAULT_MAX_TRAIL_PER_PAGE = 4;

    function _resolveConfig(overrides) {
        const cfg = (typeof GAME_CONFIG !== 'undefined') ? GAME_CONFIG : null;
        const timing = cfg && cfg.timing ? cfg.timing : {};
        const assets = cfg && cfg.assets ? cfg.assets : {};

        const next = {
            cardBack: assets.cardBack || '/assets/images/cards/bside.png',
            dealStaggerMs: Number(timing.dealStaggerMs) || 100,
            dealDurationMs: Number(timing.dealAnimDurationMs) || 120,
            drawOutMs: 60,
            drawInMs: 80,
            drawStaggerMs: 40,
            shuffleFrameMs: Number(timing.shuffleFrameMs) || 80,
            lucky5ActiveMs: Number(timing.lucky5ActiveScreenMs) || 700
        };

        if (overrides && typeof overrides === 'object') {
            Object.assign(next, overrides);
        }

        return next;
    }

    let _config = _resolveConfig();
    let _shuffleInterval = null;
    let _isDoubleUpMode = false;
    let _lucky5Timer = null;
    let _duTrailCards = [];
    let _duDealerCard = null;

    function _asCard(input) {
        if (!input) return null;

        if (typeof input === 'string') {
            const code = String(input).toUpperCase();
            return {
                code,
                rank: code.slice(0, -1),
                suit: code.slice(-1)
            };
        }

        if (input.code) {
            const code = String(input.code).toUpperCase();
            return {
                code,
                rank: input.rank || code.slice(0, -1),
                suit: input.suit || code.slice(-1)
            };
        }

        if (input.rank && input.suit) {
            return {
                code: `${input.rank}${input.suit}`.toUpperCase(),
                rank: input.rank,
                suit: input.suit
            };
        }

        return null;
    }

    function _cardSrc(code) {
        return `/assets/images/cards/${code}.png`;
    }

    function _allCardCodes() {
        return Array.isArray(window.ALL_CARD_CODES) && window.ALL_CARD_CODES.length > 0
            ? window.ALL_CARD_CODES
            : [];
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

    function _duSlot(index) {
        return document.querySelector(`.du-card-slot[data-du-slot="${index}"]`);
    }

    function _duFrame(slotEl) {
        return slotEl ? slotEl.querySelector('.du-card-frame') : null;
    }

    function _duImg(slotEl) {
        return slotEl ? slotEl.querySelector('img') : null;
    }

    function _duLabel(slotEl) {
        return slotEl ? slotEl.querySelector('.du-card-label') : null;
    }

    function _stopShuffle() {
        if (_shuffleInterval) {
            clearInterval(_shuffleInterval);
            _shuffleInterval = null;
        }

        document.querySelectorAll('.du-card-slot.du-shuffling').forEach(slotEl => {
            slotEl.classList.remove('du-shuffling');
        });
    }

    function _ensureMainSlots() {
        const area = document.getElementById('card-area');
        if (!area) return false;

        if (_isDoubleUpMode || area.querySelectorAll('.card-slot').length !== 5) {
            initCardSlots();
        }

        return true;
    }

    function _resetMainSlot(slotEl) {
        if (!slotEl) return;

        slotEl.classList.remove('held', 'lucky5-active');
        slotEl.style.transition = 'none';
        slotEl.style.transform = 'translateY(0)';
        slotEl.style.opacity = '1';

        const face = slotEl.querySelector('.card-face');
        if (face) {
            face.style.transition = 'none';
            face.style.opacity = '1';
        }
    }

    function _ensureDoubleUpSlots() {
        const area = document.getElementById('card-area');
        if (!area) return false;

        area.classList.add('du-mode');
        if (!_isDoubleUpMode || area.querySelectorAll('.du-card-slot').length !== 5) {
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
                img.src = _config.cardBack;
                img.alt = 'Card back';

                frame.appendChild(img);
                slot.appendChild(label);
                slot.appendChild(frame);
                area.appendChild(slot);
            }
        }

        _isDoubleUpMode = true;
        return true;
    }

    function _clearDoubleUpSlots() {
        for (let i = 0; i < 5; i++) {
            const slotEl = _duSlot(i);
            const frame = _duFrame(slotEl);
            const label = _duLabel(slotEl);
            const img = _duImg(slotEl);

            if (!slotEl || !frame || !label || !img) continue;

            slotEl.classList.remove('du-trail-card', 'du-shuffling');
            frame.classList.remove('dealer-card', 'lucky5-glow');
            label.textContent = '';
            img.src = _config.cardBack;
            img.alt = 'Card back';
        }
    }

    function _getVisibleDoubleUpWindow(trailCards, dealerCard) {
        const normalizedTrail = Array.isArray(trailCards)
            ? trailCards.map(_asCard).filter(Boolean)
            : [];
        const normalizedDealer = _asCard(dealerCard);

        const maxTrailPerPage = Math.max(1, Number(window.GAME_CONFIG?.doubleUp?.maxTrailPerPage) || DEFAULT_MAX_TRAIL_PER_PAGE);
        const carryStep = Math.max(1, maxTrailPerPage - 1);

        let startIndex = 0;
        if (normalizedTrail.length > maxTrailPerPage) {
            const overshoot = normalizedTrail.length - maxTrailPerPage;
            const pages = Math.ceil(overshoot / carryStep);
            startIndex = pages * carryStep;
        }

        const visibleTrail = normalizedTrail.slice(startIndex);
        const sequence = visibleTrail.slice();
        let dealerIndex = -1;

        if (normalizedDealer) {
            dealerIndex = Math.min(visibleTrail.length, 4);
            sequence.push(normalizedDealer);
        }

        return {
            sequence: sequence.slice(0, 5),
            dealerIndex,
            revealIndex: Math.min(sequence.length, 4)
        };
    }

    function _statusLabel(status) {
        switch (String(status || '').toLowerCase()) {
            case 'win':
                return 'WIN';
            case 'lose':
                return 'LOSE';
            case 'push':
                return 'SAFE';
            default:
                return '';
        }
    }

    function _renderDoubleUpSequence(sequence, dealerIndex, revealIndex, status) {
        if (!_ensureDoubleUpSlots()) return;

        _clearDoubleUpSlots();

        for (let i = 0; i < 5; i++) {
            const slotEl = _duSlot(i);
            const frame = _duFrame(slotEl);
            const label = _duLabel(slotEl);
            const img = _duImg(slotEl);
            const card = sequence[i] || null;

            if (!slotEl || !frame || !label || !img) continue;

            if (card) {
                img.src = _cardSrc(card.code);
                img.alt = card.code;
            }

            if (card && i < dealerIndex) {
                slotEl.classList.add('du-trail-card');
                label.textContent = 'PLAYED';
            }

            if (card && i === dealerIndex) {
                frame.classList.add('dealer-card');
                label.textContent = 'DEALER';
            }

            if (!card && revealIndex === i) {
                label.textContent = 'BIG / SMALL ?';
            }

            if (card && revealIndex == null && i === dealerIndex + 1 && status) {
                label.textContent = status;
            }

            if (card && card.code === '5S') {
                frame.classList.add('lucky5-glow');
            }
        }
    }

    function _beginSequentialShuffle(trailCards, dealerCard) {
        _stopShuffle();

        const view = _getVisibleDoubleUpWindow(trailCards, dealerCard);
        _renderDoubleUpSequence(view.sequence, view.dealerIndex, view.revealIndex, '');

        const slotEl = _duSlot(view.revealIndex);
        const img = _duImg(slotEl);
        const codes = _allCardCodes();

        if (!slotEl || !img || codes.length === 0) {
            return;
        }

        slotEl.classList.add('du-shuffling');

        const frameMs = Math.max(60, Number(_config.shuffleFrameMs) || 80);
        let cursor = 0;
        _shuffleInterval = setInterval(() => {
            const code = codes[cursor % codes.length];
            cursor++;
            img.src = _cardSrc(code);
            img.alt = `${code} shuffle`;
        }, frameMs);
    }

    function configure(overrides) {
        _config = _resolveConfig(overrides);
        return getConfig();
    }

    function getConfig() {
        return {
            cardBack: _config.cardBack,
            dealStaggerMs: _config.dealStaggerMs,
            dealDurationMs: _config.dealDurationMs,
            drawOutMs: _config.drawOutMs,
            drawInMs: _config.drawInMs,
            drawStaggerMs: _config.drawStaggerMs,
            shuffleFrameMs: _config.shuffleFrameMs,
            lucky5ActiveMs: _config.lucky5ActiveMs
        };
    }

    function initCardSlots() {
        const area = document.getElementById('card-area');
        if (!area) return;

        _stopShuffle();
        area.classList.remove('du-mode');
        area.innerHTML = '';

        for (let i = 0; i < 5; i++) {
            const slot = document.createElement('div');
            slot.className = 'card-slot';
            slot.dataset.slot = i;

            const face = document.createElement('div');
            face.className = 'card-face';

            const img = document.createElement('img');
            img.src = _config.cardBack;
            img.alt = 'Card back';

            face.appendChild(img);

            const badge = document.createElement('div');
            badge.className = 'hold-badge';
            badge.textContent = 'HOLD';

            slot.appendChild(face);
            slot.appendChild(badge);
            area.appendChild(slot);
        }

        _duTrailCards = [];
        _duDealerCard = null;
        _isDoubleUpMode = false;
    }

    function dealCards(cardArray, onComplete) {
        if (!_ensureMainSlots()) return;

        _stopShuffle();
        clearAllHolds();

        const cards = Array.isArray(cardArray) ? cardArray.map(_asCard) : [];
        const stagger = Math.max(40, Number(_config.dealStaggerMs) || 100);
        const duration = Math.max(80, Number(_config.dealDurationMs) || 120);

        cards.forEach((card, i) => {
            const slotEl = _slot(i);
            const img = _cardImg(slotEl);
            if (!slotEl || !img) return;

            _resetMainSlot(slotEl);
            img.src = card && card.code ? _cardSrc(card.code) : _config.cardBack;
            img.alt = card && card.code ? card.code : 'Card back';
            slotEl.style.transform = 'translateY(-60px)';
        });

        requestAnimationFrame(() => {
            cards.forEach((card, i) => {
                setTimeout(() => {
                    const slotEl = _slot(i);
                    if (!slotEl) return;

                    slotEl.style.transition = `transform ${duration}ms ease-out`;
                    slotEl.style.transform = 'translateY(0)';

                    if (i === cards.length - 1 && onComplete) {
                        setTimeout(onComplete, duration + 40);
                    }
                }, i * stagger);
            });
        });
    }

    function drawCards(newCardArray, heldIndexes, onComplete) {
        if (!_ensureMainSlots()) return;

        _stopShuffle();

        const held = new Set(Array.isArray(heldIndexes) ? heldIndexes : Array.from(heldIndexes || []));
        const cards = Array.isArray(newCardArray) ? newCardArray.map(_asCard) : [];
        let pending = 0;

        const outMs = Math.max(40, Number(_config.drawOutMs) || 60);
        const inMs = Math.max(60, Number(_config.drawInMs) || 80);
        const staggerMs = Math.max(20, Number(_config.drawStaggerMs) || 40);

        cards.forEach((card, i) => {
            const slotEl = _slot(i);
            const img = _cardImg(slotEl);
            const face = slotEl ? slotEl.querySelector('.card-face') : null;

            if (!slotEl || !img) return;

            if (held.has(i)) {
                slotEl.classList.add('held');
                if (card && card.code) {
                    img.src = _cardSrc(card.code);
                    img.alt = card.code;
                }
                if (face) {
                    face.style.transition = 'none';
                    face.style.opacity = '1';
                }
                return;
            }

            pending++;
            slotEl.classList.remove('held');

            setTimeout(() => {
                if (face) {
                    face.style.transition = `opacity ${outMs}ms ease-in`;
                    face.style.opacity = '0';
                }

                setTimeout(() => {
                    img.src = card && card.code ? _cardSrc(card.code) : _config.cardBack;
                    img.alt = card && card.code ? card.code : 'Card back';

                    if (face) {
                        face.style.transition = `opacity ${inMs}ms ease-out`;
                        face.style.opacity = '1';
                    }

                    pending--;
                    if (pending === 0 && onComplete) {
                        onComplete();
                    }
                }, outMs);
            }, i * staggerMs);
        });

        if (pending === 0 && onComplete) {
            onComplete();
        }
    }

    function setHold(slotIndex, isHeld) {
        const slotEl = _slot(slotIndex);
        if (slotEl) slotEl.classList.toggle('held', isHeld);

        const btn = _holdBtn(slotIndex);
        if (btn) {
            btn.classList.toggle('active', isHeld);
            btn.style.backgroundImage = isHeld
                ? "url('/assets/images/hold_on.png')"
                : "url('/assets/images/hold_off.png')";
            btn.setAttribute('aria-label', isHeld ? 'HOLD ON' : 'HOLD OFF');
            btn.title = isHeld ? 'HOLD' : '';
        }
    }

    function clearAllHolds() {
        for (let i = 0; i < 5; i++) {
            setHold(i, false);
        }
    }

    function initButtonAssets() {
        const BTN_ASSETS = {
            'btn-big': ['big.png', 'big_on.png'],
            'btn-small': ['small.png', 'small_on.png'],
            'btn-cancel': ['cancel_hold.png', 'cancel_hold_on.png'],
            'btn-deal': ['deal_draw.png', 'deal_draw_on.png'],
            'btn-bet': ['bet.png', 'bet_on.png'],
            'btn-take-half': ['take_half.png', 'take_half_on.png'],
            'btn-take-score': ['take_score.png', 'take_score_on.png']
        };

        Object.entries(BTN_ASSETS).forEach(([id, [off, on]]) => {
            const btn = document.getElementById(id);
            if (!btn || btn.dataset.assetsBound === '1') return;

            const offUrl = `url('/assets/images/${off}')`;
            const onUrl = `url('/assets/images/${on}')`;
            btn.style.backgroundImage = offUrl;

            const press = () => { btn.style.backgroundImage = onUrl; };
            const release = () => { btn.style.backgroundImage = offUrl; };

            btn.addEventListener('mousedown', press);
            btn.addEventListener('touchstart', press, { passive: true });
            btn.addEventListener('mouseup', release);
            btn.addEventListener('touchend', release, { passive: true });
            btn.addEventListener('touchcancel', release, { passive: true });
            btn.addEventListener('mouseleave', release);
            btn.dataset.assetsBound = '1';
        });

        document.querySelectorAll('#hold-row .cab-hold').forEach(btn => {
            if (btn.dataset.assetsBound === '1') return;

            const syncVisual = () => {
                const held = btn.classList.contains('active');
                btn.style.backgroundImage = held
                    ? "url('/assets/images/hold_on.png')"
                    : "url('/assets/images/hold_off.png')";
                btn.setAttribute('aria-label', held ? 'HOLD ON' : 'HOLD OFF');
                btn.title = held ? 'HOLD' : '';
            };

            btn.addEventListener('mousedown', () => {
                btn.style.backgroundImage = "url('/assets/images/hold_on.png')";
            });
            btn.addEventListener('mouseup', syncVisual);
            btn.addEventListener('mouseleave', syncVisual);
            btn.addEventListener('touchstart', () => {
                btn.style.backgroundImage = "url('/assets/images/hold_on.png')";
            }, { passive: true });
            btn.addEventListener('touchend', syncVisual, { passive: true });
            btn.addEventListener('touchcancel', syncVisual, { passive: true });

            syncVisual();
            btn.dataset.assetsBound = '1';
        });
    }

    function enterDoubleUp(dealerCard) {
        _duTrailCards = [];
        _duDealerCard = _asCard(dealerCard);
        _beginSequentialShuffle(_duTrailCards, _duDealerCard);
    }

    function updateDoubleUpTrail(trailCards, dealerCard, challengerCard, status) {
        _duTrailCards = Array.isArray(trailCards)
            ? trailCards.map(_asCard).filter(Boolean)
            : [];
        _duDealerCard = _asCard(dealerCard);

        if (!challengerCard) {
            _beginSequentialShuffle(_duTrailCards, _duDealerCard);
            return;
        }

        _stopShuffle();

        const challenger = _asCard(challengerCard);
        const view = _getVisibleDoubleUpWindow(_duTrailCards, _duDealerCard);
        const sequence = view.sequence.slice(0, view.revealIndex);
        sequence[view.revealIndex] = challenger;

        _renderDoubleUpSequence(sequence, view.dealerIndex, null, _statusLabel(status));

        if (challenger && challenger.code === '5S') {
            showLucky5Active();
        }
    }

    function shuffleChallenger() {
        _beginSequentialShuffle(_duTrailCards, _duDealerCard);
    }

    function exitDoubleUp() {
        _stopShuffle();
        _isDoubleUpMode = false;
        _duTrailCards = [];
        _duDealerCard = null;

        const area = document.getElementById('card-area');
        if (area) area.classList.remove('du-mode');

        initCardSlots();
    }

    function showLucky5Active() {
        const banner = document.getElementById('lucky5-banner');
        if (banner) {
            banner.classList.add('active');
            if (_lucky5Timer) clearTimeout(_lucky5Timer);
            _lucky5Timer = setTimeout(() => {
                banner.classList.remove('active');
                _lucky5Timer = null;
            }, Math.max(200, Number(_config.lucky5ActiveMs) || 700));
        }

        document.querySelectorAll('.card-slot, .du-card-slot').forEach(slotEl => {
            slotEl.classList.add('lucky5-active');
            setTimeout(() => slotEl.classList.remove('lucky5-active'), Math.max(200, Number(_config.lucky5ActiveMs) || 700));
        });
    }

    return {
        configure,
        getConfig,
        initCardSlots,
        dealCards,
        drawCards,
        setHold,
        clearAllHolds,
        initButtonAssets,
        enterDoubleUp,
        updateDoubleUpTrail,
        shuffleChallenger,
        exitDoubleUp,
        showLucky5Active
    };
}());
