'use strict';

window.CabinetTransition = (function () {
    const fps = () => Number(window.GAME_CONFIG?.cabinet?.fps || 60);
    const msPerFrame = () => 1000 / fps();

    const queue = [];
    let active = false;
    let currentTimer = null;
    let virtualClockMs = 0;

    function framesToMs(frames) {
        return Math.max(0, Math.round(Number(frames || 0) * msPerFrame()));
    }

    function _setLocked(locked) {
        if (!window.CabinetState) return;
        const snapshot = CabinetState.get();
        CabinetState.updatePresentation({
            locked: Boolean(locked),
            planDepth: Math.max(0, snapshot.presentation.planDepth + (locked ? 1 : -1))
        });
    }

    function _next() {
        if (queue.length === 0) {
            active = false;
            _setLocked(false);
            return;
        }

        active = true;
        _setLocked(true);
        const step = queue.shift();
        const durationMs = framesToMs(step.frames || 0);
        CabinetState.updatePresentation({
            lastTransition: step.name || null,
            lastAction: step.actionType || step.name || 'STEP'
        });

        try {
            if (typeof step.run === 'function') {
                step.run();
            }
        } catch (_) {
            // keep planner alive even if a visual step fails
        }

        currentTimer = setTimeout(() => {
            currentTimer = null;
            CabinetState.updatePresentation({
                frame: CabinetState.get().presentation.frame + Math.max(1, Number(step.frames || 0))
            });
            _next();
        }, durationMs);
    }

    function enqueue(steps) {
        const list = Array.isArray(steps) ? steps.filter(Boolean) : [steps].filter(Boolean);
        if (list.length === 0) return;
        queue.push(...list);
        if (!active && !currentTimer) {
            _next();
        }
    }

    function flush() {
        if (currentTimer) {
            clearTimeout(currentTimer);
            currentTimer = null;
        }
        queue.length = 0;
        active = false;
        _setLocked(false);
    }

    function advanceTime(ms) {
        const frames = Math.max(1, Math.round(Number(ms || 0) / msPerFrame()));
        virtualClockMs += Number(ms || 0);
        CabinetState.updatePresentation({
            frame: CabinetState.get().presentation.frame + frames
        });
        return {
            advancedMs: Number(ms || 0),
            advancedFrames: frames,
            virtualClockMs
        };
    }

    function dispatch(action) {
        if (!action || !action.type) return;
        CabinetState.updatePresentation({ lastAction: action.type });

        switch (action.type) {
            case 'RENDER_DEAL':
                enqueue([
                    {
                        name: 'deal-cards',
                        actionType: action.type,
                        frames: Math.max(1, Math.ceil((Number(action.cardCount || 5) * Number(action.staggerFrames || 6)) + Number(action.settleFrames || 12))),
                        run: function () {
                            if (window.CabinetAudio) CabinetAudio.queue('deal');
                            if (window.CabinetStage?.initCardSlots) {
                                CabinetStage.initCardSlots();
                            }
                            if (window.CabinetStage?.dealCards) {
                                CabinetStage.dealCards(action.cards || []);
                            }
                        }
                    }
                ]);
                break;
            case 'RENDER_DRAW':
                enqueue([
                    {
                        name: 'draw-cards',
                        actionType: action.type,
                        frames: Math.max(1, Number(action.frames || 18)),
                        run: function () {
                            if (window.CabinetAudio) CabinetAudio.queue('draw');
                            if (window.CabinetStage?.drawCards) {
                                CabinetStage.drawCards(action.cards || [], action.heldIndexes || []);
                            }
                        }
                    }
                ]);
                break;
            case 'RENDER_DOUBLEUP':
                enqueue([
                    {
                        name: 'doubleup-stage',
                        actionType: action.type,
                        frames: Math.max(1, Number(action.frames || 10)),
                        run: function () {
                            if (window.CabinetStage?.enterDoubleUp) {
                                CabinetStage.enterDoubleUp(action.dealerCard || null);
                            }
                            if (window.CabinetStage?.updateDoubleUpTrail) {
                                CabinetStage.updateDoubleUpTrail(action.trailCards || [], action.dealerCard || null, action.challengerCard || null, action.status || 'pending');
                            }
                            if (action.status === 'pending' && window.CabinetStage?.shuffleChallenger) {
                                CabinetStage.shuffleChallenger();
                            }
                        }
                    }
                ]);
                break;
            case 'COLLECT_WIN':
                enqueue([
                    {
                        name: 'collect-win',
                        actionType: action.type,
                        frames: Math.max(1, Number(action.frames || 24)),
                        run: function () {
                            if (window.CabinetAudio) CabinetAudio.queue('collect', { priority: 'low' });
                            if (window.CabinetPace?.collectWin) {
                                CabinetPace.collectWin(action.amount || 0, action.fromCredits || 0, action.toCredits || 0, action.onComplete);
                            } else if (typeof action.onComplete === 'function') {
                                action.onComplete();
                            }
                        }
                    }
                ]);
                break;
            case 'FILL_JACKPOT':
                enqueue([
                    {
                        name: 'jackpot-fill',
                        actionType: action.type,
                        frames: Math.max(1, Number(action.frames || 90)),
                        run: function () {
                            if (window.CabinetPace?.fillJackpot) {
                                CabinetPace.fillJackpot(action.element, action.fromValue || 0, action.toValue || 0, action.onComplete);
                            } else if (typeof action.onComplete === 'function') {
                                action.onComplete();
                            }
                        }
                    }
                ]);
                break;
            case 'FLASH_LUCKY5':
                enqueue([
                    {
                        name: 'lucky5-flash',
                        actionType: action.type,
                        frames: Math.max(1, Number(action.frames || 12)),
                        run: function () {
                            if (window.CabinetAudio) CabinetAudio.queue('lucky5', { priority: 'high' });
                            if (window.CabinetPace?.flashLucky5) {
                                CabinetPace.flashLucky5();
                            }
                        }
                    }
                ]);
                break;
            case 'MACHINE_CLOSED':
                enqueue([
                    {
                        name: 'machine-closed',
                        actionType: action.type,
                        frames: Math.max(1, Number(action.frames || 18)),
                        run: function () {
                            if (window.CabinetAudio) CabinetAudio.queue('machineClose', { priority: 'high' });
                            if (typeof action.onRun === 'function') action.onRun();
                        }
                    }
                ]);
                break;
            default:
                break;
        }
    }

    return {
        enqueue,
        dispatch,
        framesToMs,
        flush,
        advanceTime
    };
})();
