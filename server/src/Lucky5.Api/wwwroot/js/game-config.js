/**
 * game-config.js  —  Lucky5 Variant Configuration
 * ═══════════════════════════════════════════════════════════════════════════
 * This is the SINGLE FILE you swap when creating a new arcade video poker
 * variant.  The engine (game.js) reads everything from GAME_CONFIG and must
 * never hard-code values that belong here.
 *
 * Sections:
 *   1. meta        — variant identity
 *   2. timing      — all animation / delay values in one place
 *   3. api         — backend endpoint paths (swap for a different backend)
 *   4. rules       — game logic constants (hands, jackpots, limits)
 *   5. doubleUp    — double-up page model
 *   6. assets      — card back, board image paths
 *   7. paytableMap — display names for hand ranks (UI only)
 */

/* global GAME_CONFIG */
const GAME_CONFIG = Object.freeze({

    // ── 1. META ─────────────────────────────────────────────────────────────
    meta: Object.freeze({
        variantId:   'lucky5-video-poker',
        variantName: 'Lucky 5',
        handSize:    5,       // cards in a hand (change to 3 for 3-card variants)
    }),

    // ── 2. TIMING ────────────────────────────────────────────────────────────
    // All durations are in milliseconds.
    // Adjust these to change the overall rhythm of the game without touching
    // any rendering or state logic.
    timing: Object.freeze({
        // Main-hand deal animation
        dealBaseMs:           60,   // delay before the first card starts dropping
        dealStaggerMs:        80,   // extra delay per subsequent card (left → right)
        dealAnimDurationMs:   220,  // CSS transition length for the drop itself

        // Double-up: shuffle animation
        shuffleFrameMs:       250,  // how often the shuffle swaps to a random card

        // Double-up: reveal sequence
        duRevealDelayMs:      150,  // wait after server responds before showing challenger card
        duWinHoldMs:          700,  // show WIN message this long before advancing the trail
        duStaggerPerCardMs:   80,   // stagger between cards on a fresh DU page

        // Win collection / drain-to-credits
        countUpMinMs:         3000,
        countUpMaxMs:         8000,
        creditTickMs:         120,  // toggle interval for the credit-ticking flash class

        // Jackpot fill animation (for jackpot-level wins)
        jackpotFillMinMs:     10000,
        jackpotFillMaxMs:     15000,

        // Lucky5 safe / machine-closed payout drain
        drainDelayMs:         1200, // wait before starting the drain animation

        // Double-up exit delays
        exitDuLoseMs:         1000, // delay before exiting DU after a loss
        exitDuCatchMs:        1500, // delay before exiting DU after a network error

        // Lucky5 flash presentation
        lucky5FlashDurationMs: 600,   // CSS animation duration
        lucky5ActiveScreenMs:  1600,  // how long .lucky5-active stays on the game screen

        // Draw animation (re-dealing only non-held cards)
        drawRevealStartMs:     60,    // delay before first replaced card starts dropping
        // draw card stagger reuses dealStaggerMs (same physics as deal)

        // Post-draw flow
        drawResultDelayMs:     500,   // delay after draw cards settle before showing result/DU
        winToDuPromptMs:       500,   // delay before auto-launching DU after a win
        postLossIdleTitleMs:   2000,  // delay before idle title shows after a loss

        // Take-half continue delay
        takeHalfContinueMs:    800,   // delay before re-offering DU after taking half
    }),

    // ── 3. API ───────────────────────────────────────────────────────────────
    // All backend endpoint strings live here.
    // Swap this section to point the engine at a different server or route prefix.
    api: Object.freeze({
        // Auth
        login:            '/api/auth/login',
        profile:          '/api/Auth/GetUserById',
        wallet:           '/api/Auth/wallet',
        memberHistory:    '/api/Auth/MemberHistory',

        // Lobby / machines
        machines:         '/api/Game/games/machines',
        defaultRules:     '/api/Game/defaultRules',

        // Machine session
        machineSession:   (id) => `/api/Game/machine/${id}/session`,
        machineState:     (id) => `/api/Game/machine/${id}/state`,
        machineRound:     (id) => `/api/Game/machine/${id}/active-round`,
        machineCashIn:    (id) => `/api/Game/machine/${id}/cash-in`,
        machineCashOut:   (id) => `/api/Game/machine/${id}/cash-out`,
        machineReset:     (id) => `/api/Game/machine/${id}/reset`,

        // Core game actions
        deal:             '/api/Game/cards/deal',
        draw:             '/api/Game/cards/draw',

        // Jackpot
        jackpotRank:      '/api/Game/jackpot/rank',

        // Double-up
        duStart:          '/api/Game/double-up/start',
        duGuess:          '/api/Game/double-up/guess',
        duCashout:        '/api/Game/double-up/cashout',
        duTakeHalf:       '/api/Game/double-up/take-half',
        duSwitch:         '/api/Game/double-up/switch',

        // Admin
        adminUsers:       '/api/Admin/users',
        adminUserSearch:  (q) => `/api/Admin/users/search?q=${encodeURIComponent(q)}`,
        adminCredit:      '/api/Admin/users/credit',
        adminMachines:    '/api/Admin/machines',
    }),

    // ── 4. RULES ─────────────────────────────────────────────────────────────
    // Variant-specific game logic.  These must stay in sync with the backend
    // EngineConfig / CleanRoom defaults.
    rules: Object.freeze({
        // The Lucky5 special card — triggers no-lose double-up
        luckyCard:          '5S',

        // Machine credit ceiling before auto-cashout
        machineCreditLimit: 40_000_000,

        // Which hand ranks carry jackpot counters
        jackpotHands: Object.freeze(['FourOfAKind', 'FullHouse', 'StraightFlush']),

        // Jackpot seed / reset values — must mirror server EngineConfig defaults
        jackpotReset: Object.freeze({
            FullHouse:     90_000,
            FourOfAKind:   140_000,
            StraightFlush: 850_000,
        }),

        // Full-house rank selector: rank number → card-code suffix
        // (e.g. 14 = Ace → 'A', used to show the FH selector card)
        rankNames: Object.freeze({
            2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 7:'7', 8:'8', 9:'9',
            10:'10', 11:'J', 12:'Q', 13:'K', 14:'A',
        }),
    }),

    // ── 5. DOUBLE-UP PAGE MODEL ──────────────────────────────────────────────
    // Controls how the DU history trail is paginated.
    // Change maxTrailPerPage to 3 for a 4-slot variant, etc.
    doubleUp: Object.freeze({
        maxTrailPerPage: 4,    // trail cards visible per page (+ 1 active slot = 5 total)
        // carryStep = maxTrailPerPage - 1; last card of page N is first card of page N+1
    }),

    // ── 6. ASSETS ────────────────────────────────────────────────────────────
    assets: Object.freeze({
        cardBack:   '/assets/images/cards/bside.png',
        boardImage: '/assets/images/board.png',
        pressSound: '/assets/sounds/press.mp3',
    }),

    // ── 7. PAYTABLE DISPLAY MAP ──────────────────────────────────────────────
    // Maps backend hand-rank enum values to cabinet label text.
    // Override for a variant with different hand names.
    paytableMap: Object.freeze({
        RoyalFlush:    'ROYAL FLUSH',
        StraightFlush: 'STRAIGHT FLUSH',
        FourOfAKind:   '4 OF A KIND',
        FullHouse:     'FULL HOUSE',
        Flush:         'FLUSH',
        Straight:      'STRAIGHT',
        ThreeOfAKind:  '3 OF A KIND',
        TwoPair:       '2 PAIR',
        Nothing:       'NO WIN',
    }),
});
