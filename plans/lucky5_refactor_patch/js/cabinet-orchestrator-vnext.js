'use strict';

window.CabinetOrchestrator = (function () {
    const originals = {};
    let installed = false;

    function _fmt(value) {
        return Math.floor(Number(value || 0)).toLocaleString();
    }

    function _safeText(el, text) {
        if (el) el.textContent = text;
    }

    function _renderImmediateCards(cardData, heldIndexes) {
        const area = document.getElementById('card-area');
        if (!area) return;

        if (window.CabinetStage?.initCardSlots) {
            CabinetStage.initCardSlots();
        } else {
            area.innerHTML = '';
        }

        (cardData || []).forEach((card, index) => {
            const slot = area.querySelector(`.card-slot[data-slot="${index}"]`);
            const img = slot?.querySelector('.card-face img');
            if (img) {
                img.src = card && card.code ? `/assets/images/cards/${card.code}.png` : (window.GAME_CONFIG?.assets?.cardBack || '/assets/images/cards/bside.png');
            }
            const held = Array.isArray(heldIndexes) ? heldIndexes.includes(index) : false;
            if (window.CabinetStage?.setHold) {
                CabinetStage.setHold(index, held);
            }
        });
    }

    function _syncAndSelect() {
        const snapshot = CabinetState.syncFromRuntime();
        return {
            snapshot,
            rules: CabinetState.selectors(snapshot)
        };
    }

    function _applyButtonStatesFromSelectors() {
        const { rules } = _syncAndSelect();
        const holdBtns = document.querySelectorAll('.cab-hold');
        const betBtn = document.getElementById('btn-bet');
        const dealBtn = document.getElementById('btn-deal');
        const cancelBtn = document.getElementById('btn-cancel');
        const bigBtn = document.getElementById('btn-big');
        const smallBtn = document.getElementById('btn-small');
        const takeScoreBtn = document.getElementById('btn-take-score');
        const takeHalfBtn = document.getElementById('btn-take-half');

        if (betBtn) betBtn.disabled = !rules.canBet;
        if (dealBtn) dealBtn.disabled = !rules.canDeal;
        if (cancelBtn) cancelBtn.disabled = !(CabinetState.get().machine.gameState === 'hold') || CabinetState.get().presentation.locked;
        if (bigBtn) bigBtn.disabled = !rules.canGuess;
        if (smallBtn) smallBtn.disabled = !rules.canGuess;
        if (takeScoreBtn) takeScoreBtn.disabled = !rules.canTakeScore;
        if (takeHalfBtn) takeHalfBtn.disabled = !rules.canTakeHalf;
        holdBtns.forEach((btn, index) => {
            btn.disabled = !rules.canHold(index);
        });
    }

    function _patch(name, replacement) {
        if (typeof window[name] === 'function' || typeof globalThis[name] === 'function') {
            const current = globalThis[name];
            originals[name] = current;
            globalThis[name] = replacement(current);
        }
    }

    function _installGeometry() {
        const layout = window.GAME_CONFIG?.cabinet?.layout || CabinetState.DEFAULT_LAYOUT;
        CabinetState.updateLayout(layout);
        const root = document.documentElement;
        root.style.setProperty('--cabinet-width', `${layout.width}px`);
        root.style.setProperty('--cabinet-height', `${layout.height}px`);

        function resize() {
            const width = layout.width;
            const height = layout.height;
            const scale = Math.min(window.innerWidth / width, window.innerHeight / height);
            root.style.setProperty('--cabinet-scale', String(scale));
            CabinetState.updatePresentation({ viewportScale: scale });
        }

        resize();
        window.addEventListener('resize', resize);
    }

    function _installDebugHooks() {
        window.render_game_to_text = function renderGameToText() {
            const snapshot = CabinetState.get();
            return JSON.stringify({
                coordinateSystem: 'origin top-left; +x right; +y down; base layout 720x1280',
                machine: snapshot.machine,
                presentation: snapshot.presentation,
                selectors: CabinetState.selectors(snapshot)
            });
        };

        window.advanceTime = function advanceTime(ms) {
            return CabinetTransition.advanceTime(ms);
        };
    }

    function _installInputGuards() {
        document.addEventListener('pointerdown', function (event) {
            const btn = event.target.closest('.cab-btn, .menu-panel-btn, .menu-panel-close');
            if (!btn) return;
            if (CabinetState.get().presentation.locked && !btn.closest('#menu-panel')) {
                event.preventDefault();
                event.stopPropagation();
                if (window.CabinetAudio) CabinetAudio.queue('invalid', { priority: 'high' });
            }
        }, true);
    }

    function install() {
        if (installed) return;
        installed = true;

        if (!window.CabinetState || !window.CabinetTransition) return;

        CabinetState.syncFromRuntime();
        CabinetAudio?.preload?.();
        _installGeometry();
        _installDebugHooks();
        _installInputGuards();

        _patch('playPress', function () {
            return function patchedPlayPress() {
                CabinetAudio?.queue('press');
            };
        });

        _patch('showMessage', function (legacy) {
            return function patchedShowMessage(text, type) {
                const result = legacy.call(this, text, type);
                CabinetState.updateMachine({ message: text || '', messageType: type || '' });
                return result;
            };
        });

        _patch('updateCredits', function (legacy) {
            return function patchedUpdateCredits() {
                const result = legacy.call(this);
                CabinetState.syncFromRuntime();
                return result;
            };
        });

        _patch('updateStakeDisplay', function (legacy) {
            return function patchedUpdateStakeDisplay() {
                const result = legacy.call(this);
                CabinetState.syncFromRuntime();
                return result;
            };
        });

        _patch('updateWinIndicator', function (legacy) {
            return function patchedUpdateWinIndicator(amount) {
                const result = legacy.call(this, amount);
                CabinetState.updateMachine({ winAmount: Number(amount || 0) });
                return result;
            };
        });

        _patch('setButtonStates', function () {
            return function patchedSetButtonStates() {
                _applyButtonStatesFromSelectors();
            };
        });

        _patch('renderCards', function (legacy) {
            return function patchedRenderCards(cardData, animate) {
                CabinetState.updateMachine({
                    cards: Array.isArray(cardData) ? cardData : [],
                    holdIndexes: typeof holdIndexes !== 'undefined' ? Array.from(holdIndexes || []) : []
                });

                if (animate) {
                    CabinetTransition.dispatch({
                        type: 'RENDER_DEAL',
                        cards: cardData,
                        cardCount: Array.isArray(cardData) ? cardData.length : 5,
                        staggerFrames: Math.max(1, Math.round((Number(window.GAME_CONFIG?.timing?.dealStaggerMs || 80) / 1000) * 60)),
                        settleFrames: Math.max(1, Math.round((Number(window.GAME_CONFIG?.timing?.dealAnimDurationMs || 220) / 1000) * 60))
                    });
                    return;
                }

                _renderImmediateCards(cardData, typeof holdIndexes !== 'undefined' ? Array.from(holdIndexes || []) : []);
                if (typeof legacy === 'function') {
                    // keep legacy DOM side-effects for click handlers / fallback classes
                    try { legacy.call(this, cardData, false); } catch (_) {}
                }
            };
        });

        _patch('renderDoubleUpCards', function (legacy) {
            return function patchedRenderDoubleUpCards(dealerCard, showShuffle, challengerCard) {
                CabinetState.updateMachine({
                    duDealerCard: dealerCard || null,
                    duCardTrail: typeof duCardTrail !== 'undefined' ? duCardTrail : []
                });

                CabinetTransition.dispatch({
                    type: 'RENDER_DOUBLEUP',
                    dealerCard: dealerCard || null,
                    challengerCard: challengerCard || null,
                    trailCards: Array.isArray(duCardTrail) ? duCardTrail.map((entry) => entry.card || entry) : [],
                    status: challengerCard ? 'resolved' : 'pending',
                    frames: showShuffle ? 10 : 6
                });

                if (typeof legacy === 'function') {
                    try { legacy.call(this, dealerCard, showShuffle, challengerCard); } catch (_) {}
                }
            };
        });

        _patch('triggerLucky5Flash', function (legacy) {
            return function patchedTriggerLucky5Flash() {
                CabinetState.updatePresentation({ lucky5Active: true });
                CabinetTransition.dispatch({ type: 'FLASH_LUCKY5', frames: 12 });
                if (typeof legacy === 'function') {
                    try { legacy.call(this); } catch (_) {}
                }
            };
        });

        _patch('animateJackpotFill', function (legacy) {
            return function patchedAnimateJackpotFill(amount, startBalance, handName) {
                const counterSelector = handName === 'FullHouse'
                    ? '#jp-counter-fh .jp-cval'
                    : handName === 'StraightFlush'
                        ? '#jp-counter-center .jp-cval'
                        : (typeof active4kSlot !== 'undefined' && active4kSlot === 1)
                            ? '#jp-counter-b .jp-cval'
                            : '#jp-counter-a .jp-cval';
                const element = document.querySelector(counterSelector);

                return new Promise((resolve) => {
                    CabinetTransition.dispatch({
                        type: 'FILL_JACKPOT',
                        element,
                        fromValue: Number(amount || 0),
                        toValue: Number(window.GAME_CONFIG?.rules?.jackpotReset?.[handName] || 0),
                        frames: Math.max(60, Math.round((Number(window.GAME_CONFIG?.timing?.jackpotFillMinMs || 10000) / 1000) * 60)),
                        onComplete: resolve
                    });
                    if (typeof legacy === 'function') {
                        try { legacy.call(this, amount, startBalance, handName).catch(() => resolve()); } catch (_) {}
                    }
                });
            };
        });

        _patch('animateDrainToCredits', function (legacy) {
            return function patchedAnimateDrainToCredits(amount, startBalance) {
                return new Promise((resolve) => {
                    CabinetTransition.dispatch({
                        type: 'COLLECT_WIN',
                        amount: Number(amount || 0),
                        fromCredits: Number(startBalance || 0),
                        toCredits: Number(startBalance || 0) + Number(amount || 0),
                        frames: Math.max(24, Math.round((Number(window.GAME_CONFIG?.timing?.countUpMinMs || 3000) / 1000) * 60)),
                        onComplete: function () {
                            CabinetState.syncFromRuntime();
                            resolve();
                        }
                    });
                    if (typeof legacy === 'function') {
                        try { legacy.call(this, amount, startBalance).catch(() => resolve()); } catch (_) {}
                    }
                });
            };
        });

        _patch('fetchMachineSession', function (legacy) {
            return async function patchedFetchMachineSession() {
                const result = await legacy.call(this);
                CabinetState.syncFromRuntime({
                    machineCanCashOut: Boolean(result?.canCashOut),
                    machineSessionClosed: Boolean(result?.isMachineClosed),
                    machineCashOutThreshold: Number(result?.cashOutThreshold || 0)
                });
                return result;
            };
        });

        _patch('restoreRoundFromSnapshot', function (legacy) {
            return function patchedRestoreRoundFromSnapshot(snapshot) {
                const result = legacy.call(this, snapshot);
                CabinetState.syncFromRuntime();
                return result;
            };
        });

        _patch('showLobby', function (legacy) {
            return async function patchedShowLobby() {
                const result = await legacy.call(this);
                CabinetState.syncFromRuntime({ screen: 'lobby' });
                return result;
            };
        });

        _patch('showWallet', function (legacy) {
            return function patchedShowWallet() {
                const result = legacy.call(this);
                CabinetState.syncFromRuntime({ screen: 'wallet' });
                return result;
            };
        });

        _patch('showAdmin', function (legacy) {
            return function patchedShowAdmin() {
                const result = legacy.call(this);
                CabinetState.syncFromRuntime({ screen: 'admin' });
                return result;
            };
        });

        _patch('openGame', function (legacy) {
            return function patchedOpenGame(gameId, selectedMachineId) {
                const result = legacy.call(this, gameId, selectedMachineId);
                CabinetState.syncFromRuntime({ screen: 'game', machineId: selectedMachineId || machineId || 0 });
                return result;
            };
        });

        CabinetState.subscribe(function () {
            _applyButtonStatesFromSelectors();

            const snapshot = CabinetState.get();
            const bonus = document.getElementById('bonus-text');
            if (bonus && snapshot.machine.message && snapshot.machine.gameState === 'doubleup') {
                bonus.dataset.dispatchState = snapshot.machine.gameState;
            }

            const creditsSpan = document.querySelector('#credits span');
            if (creditsSpan) _safeText(creditsSpan, _fmt(snapshot.machine.balance));
            const stakeSpan = document.querySelector('#stake-display span');
            if (stakeSpan) _safeText(stakeSpan, _fmt(snapshot.machine.currentBet));
        });
    }

    return {
        install,
        originals
    };
})();

document.addEventListener('DOMContentLoaded', function () {
    if (window.CabinetOrchestrator) {
        window.CabinetOrchestrator.install();
    }
});
