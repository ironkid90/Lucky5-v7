"use client";

import { useCallback, startTransition, useEffect, useRef, useState } from "react";

import {
    assignUserToAgent,
    cashoutDoubleUp,
    createAgent,
    deal,
    draw,
    getDefaultRules,
    getMachineSession,
    getMachineState,
    getMemberHistory,
    getProfile,
    guessDoubleUp,
    listAdminMachines,
    listAdminUsers,
    listAgents,
    listMachines,
    login,
    loadAgentCredit,
    searchAdminUsers,
    signup,
    switchDealer,
    switchFhRank,
    takeHalf,
    verifyOtp,
} from "@/lib/api";
import type {
    AdminMachine,
    AdminUser,
    AgentInfo,
    DealResult,
    DefaultRules,
    DoubleUpResult,
    DrawResult,
    JackpotInfo,
    MachineListing,
    MachineSession,
    MachineState,
    MemberProfile,
    PokerCard,
    WalletLedgerEntry,
} from "@/lib/types";
import {
    isTerminalDoubleUpStatus,
    mapDoubleUpResultToViewModel,
    type DoubleUpViewModel,
} from "@/models/DoubleUpViewModel";

const DEFAULT_USERNAME = "tester";
const DEFAULT_PASSWORD = "password";
const DEFAULT_OTP = "";

// APK clone rainbow colors — hand order matches APK paytable top-to-bottom.
const PAYTABLE_ROWS: Array<{ key: string; label: string; color: string }> = [
    { key: "RoyalFlush", label: "ROYAL FLUSH", color: "#ff4444" },
    { key: "StraightFlush", label: "STRAIGHT FLUSH", color: "#ff7700" },
    { key: "FourOfAKind", label: "4 OF A KIND", color: "#44ffcc" },
    { key: "FullHouse", label: "FULL HOUSE", color: "#ffff00" },
    { key: "Flush", label: "FLUSH", color: "#ff6666" },
    { key: "Straight", label: "STRAIGHT", color: "#44ff88" },
    { key: "ThreeOfAKind", label: "3 OF A KIND", color: "#44ddff" },
    { key: "TwoPair", label: "2 PAIR", color: "#ddddaa" },
];

type MessageTone = "ready" | "warning" | "danger";
type AdminPanelTab = "users" | "agents" | "machines";
type DoubleUpBoardSlot = {
    key: string;
    card: PokerCard | null;
    label: string;
    kind: "trail" | "dealer" | "active" | "challenger" | "empty";
    isLucky?: boolean;
};

const DOUBLE_UP_BOARD_SLOT_COUNT = 5;
const CARD_SLOT_COUNT = 5;
const CARD_SLOT_INDEXES = Array.from({ length: CARD_SLOT_COUNT }, (_, index) => index);
const CARD_REVEAL_STAGGER_MS = 110;
const CARD_REVEAL_ANIMATION_MS = 260;

function formatMoney(value: number) {
    return new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(value);
}

function formatPercent(value: number) {
    return `${(value * 100).toFixed(1)}%`;
}

function rankLabelFromValue(rank?: number | null) {
    const value = Number(rank ?? 2);
    if (value === 11) {
        return "J";
    }
    if (value === 12) {
        return "Q";
    }
    if (value === 13) {
        return "K";
    }
    if (value === 14) {
        return "A";
    }
    return String(value);
}

function cardSuitGlyph(suit: string) {
    switch (suit.toUpperCase()) {
        case "H":
            return "♥";
        case "D":
            return "♦";
        case "C":
            return "♣";
        default:
            return "♠";
    }
}

function cardSuitClass(suit: string) {
    switch (suit.toUpperCase()) {
        case "H":
            return "hearts";
        case "D":
            return "diamonds";
        case "C":
            return "clubs";
        default:
            return "spades";
    }
}

function toneForStatus(status: string): MessageTone {
    const normalized = status.toLowerCase();
    if (normalized.includes("lose")) {
        return "danger";
    }

    if (normalized.includes("machine")) {
        return "warning";
    }

    return "ready";
}

const LUCKY5_CARD_ASSET_ROOT = "/assets/lucky5/cards";
const LUCKY5_CARD_BACK_SRC = `${LUCKY5_CARD_ASSET_ROOT}/bside.svg`;

function normalizeCardCode(card: PokerCard): string {
    const rawCode = typeof card.code === "string" ? card.code : `${card.rank}${card.suit}`;
    return rawCode.trim().toUpperCase().replace(/[^0-9AJQKSHDC]/g, "");
}

// Custom Lucky5 cabinet deck assets: 52 faces plus bside/hold back.
function cardImgSrc(card: PokerCard): string {
    const code = normalizeCardCode(card);
    return `${LUCKY5_CARD_ASSET_ROOT}/${code}.svg`;
}

function sameCard(left?: PokerCard | null, right?: PokerCard | null) {
    return !!left && !!right && normalizeCardCode(left) === normalizeCardCode(right);
}

function doubleUpResultLabel(status: string) {
    const normalized = status.replace(/([a-z])([A-Z])/g, "$1 $2").toUpperCase();
    if (normalized.includes("LOSE")) {
        return "LOSE";
    }
    if (normalized.includes("SAFE")) {
        return "SAFE";
    }
    if (normalized.includes("WIN") || normalized.includes("LUCKY")) {
        return "WIN";
    }
    return "BIG / SMALL ?";
}

function buildDoubleUpBoardSlots(viewModel: DoubleUpViewModel | null): DoubleUpBoardSlot[] {
    if (!viewModel) {
        return Array.from({ length: DOUBLE_UP_BOARD_SLOT_COUNT }, (_, index) => ({
            key: `empty-${index}`,
            card: null,
            label: "",
            kind: "empty",
        }));
    }

    const dealerCard = viewModel.dealerCard;
    const revealCard = viewModel.challengerCard;
    const maxTrailCards = Math.max(
        0,
        DOUBLE_UP_BOARD_SLOT_COUNT - (dealerCard ? 1 : 0) - 1,
    );
    let trail = viewModel.cardTrail ?? [];

    if (dealerCard && trail.length > 0 && sameCard(trail[trail.length - 1], dealerCard)) {
        trail = trail.slice(0, -1);
    }

    const carryStep = Math.max(1, maxTrailCards - 1);
    let startIndex = 0;
    if (maxTrailCards > 0 && trail.length > maxTrailCards) {
        startIndex = Math.ceil((trail.length - maxTrailCards) / carryStep) * carryStep;
    }

    const slots: DoubleUpBoardSlot[] = trail
        .slice(startIndex, startIndex + maxTrailCards)
        .map((card, index) => ({
            key: `trail-${startIndex + index}-${normalizeCardCode(card)}`,
            card,
            label: "PLAYED",
            kind: "trail",
            isLucky: normalizeCardCode(card) === "5S",
        }));

    if (dealerCard && slots.length < DOUBLE_UP_BOARD_SLOT_COUNT) {
        slots.push({
            key: `dealer-${normalizeCardCode(dealerCard)}`,
            card: dealerCard,
            label: "DEALER",
            kind: "dealer",
            isLucky: normalizeCardCode(dealerCard) === "5S",
        });
    }

    if (slots.length < DOUBLE_UP_BOARD_SLOT_COUNT) {
        slots.push({
            key: revealCard ? `challenger-${normalizeCardCode(revealCard)}` : "active-reveal",
            card: revealCard ?? null,
            label: revealCard ? doubleUpResultLabel(viewModel.status) : "BIG / SMALL ?",
            kind: revealCard ? "challenger" : "active",
            isLucky: revealCard ? normalizeCardCode(revealCard) === "5S" : false,
        });
    }

    while (slots.length < DOUBLE_UP_BOARD_SLOT_COUNT) {
        slots.push({
            key: `empty-${slots.length}`,
            card: null,
            label: "",
            kind: "empty",
        });
    }

    return slots.slice(0, DOUBLE_UP_BOARD_SLOT_COUNT);
}

function PlayingCard({ card, label, held, revealing, shuffling, onClick }: {
    card?: PokerCard | null;
    label?: string;
    held?: boolean;
    revealing?: boolean;
    shuffling?: boolean;
    onClick?: () => void;
}) {
    return (
        <div
            className={`playing-card-apk${held ? " held" : ""}${revealing ? " revealing" : ""}${shuffling ? " shuffling" : ""}${onClick ? " clickable" : ""}`}
            onClick={onClick}
            role={onClick ? "button" : undefined}
            tabIndex={onClick ? 0 : undefined}
            onKeyDown={onClick ? (e) => e.key === "Enter" && onClick() : undefined}
        >
            {held && <div className="hold-badge-apk">HOLD</div>}
            {card
                ? <img src={cardImgSrc(card)} alt={`${card.rank}${card.suit}`} className="card-img" />
                : <img src={LUCKY5_CARD_BACK_SRC} alt="Lucky5 card back" className="card-img card-back-apk" />
            }
            {label && <div className="card-label-apk">{label}</div>}
        </div>
    );
}

function DoubleUpBoard({ viewModel }: { viewModel: DoubleUpViewModel | null }) {
    const slots = buildDoubleUpBoardSlots(viewModel);
    const luckyCopyActive = viewModel?.isLucky5Active || viewModel?.isNoLoseActive;

    return (
        <div className="apk-du-panel">
            <div className="apk-du-board">
                {slots.map((slot, index) => {
                    const isActiveShuffle = slot.kind === "active" && !slot.card;

                    return (
                        <div
                            key={`${slot.key}-${index}`}
                            className={`apk-du-slot apk-du-slot--${slot.kind}${slot.isLucky ? " apk-du-slot--lucky" : ""}`}
                        >
                            <PlayingCard
                                card={slot.card}
                                label={slot.label}
                                revealing={slot.kind === "challenger"}
                                shuffling={isActiveShuffle}
                            />
                        </div>
                    );
                })}
            </div>
            <div className="apk-du-copy-row">
                <span className="apk-du-copy">HI LO GAMBLE</span>
                <span className="apk-du-copy">ACE COUNTS</span>
                <span className="apk-du-copy">HI OR LO</span>
                <span className={`apk-du-copy${luckyCopyActive ? " apk-du-copy--lucky" : ""}`}>5 ♠ NEVER LOSE</span>
                <span className="apk-du-copy">WHEN BUYING</span>
            </div>
        </div>
    );
}

// ── PaytablePanel ────────────────────────────────────────────────────────────
function PaytablePanel({
    payouts,
    activeHand,
    jackpotFh,
    stake,
}: {
    payouts: Record<string, number>;
    activeHand?: string | null;
    jackpotFh?: number;
    stake: number | string;
}) {
    const stakeValue = Math.max(0, Number(stake) || 0);

    return (
        <div className="apk-paytable">
            {PAYTABLE_ROWS.map(({ key, label, color }) => {
                const multiplier = payouts[key];
                const display = key === "FullHouse" && jackpotFh
                    ? formatMoney(jackpotFh)
                    : multiplier !== undefined
                        ? formatMoney(multiplier * stakeValue)
                        : "0";
                const isActive = activeHand === key;
                return (
                    <div
                        key={key}
                        className={`apk-pay-row${isActive ? " apk-pay-row--active" : ""}`}
                        style={{ color }}
                    >
                        <span className="apk-hand-name">{label}</span>
                        <span className="apk-pay-amount">{display}</span>
                    </div>
                );
            })}
        </div>
    );
}

// ── CreditStakeBar ───────────────────────────────────────────────────────────
function CreditStakeBar({ credit, stake }: { credit: number; stake: number | string }) {
    return (
        <div className="apk-credit-stake">
            <div className="apk-credit-label">CREDIT</div>
            <div className="apk-credit-value">{formatMoney(credit)}</div>
            <div className="apk-stake-label">STAKE</div>
            <div className="apk-stake-value">{typeof stake === "number" ? formatMoney(stake) : stake}</div>
        </div>
    );
}

// ── MachineInfoBlock ─────────────────────────────────────────────────────────
function MachineInfoBlock({
    machineName,
    jackpots,
    fourOfAKindA,
    fourOfAKindB,
    bonusText,
    machineSerial,
    kentStreak,
    fullHouseRank,
}: {
    machineName?: string | null;
    jackpots?: MachineState["jackpots"] | null;
    fourOfAKindA: number;
    fourOfAKindB: number;
    bonusText?: string | null;
    machineSerial?: string | null;
    kentStreak?: number | null;
    fullHouseRank?: number | null;
}) {
    return (
        <div className="apk-machine-info">
            <div className="apk-identity-row">
                <span className="apk-mi-label">SERIE</span>
                <span className="apk-mi-sep"> - </span>
                <span className="apk-mi-val">{machineName ?? ""}</span>
                {machineSerial && (
                    <>
                        <span className="apk-mi-label" style={{ marginLeft: 12 }}>S/N</span>
                        <span className="apk-mi-sep"> - </span>
                        <span className="apk-mi-val">{machineSerial}</span>
                    </>
                )}
                <span className="apk-mi-label" style={{ marginLeft: 12 }}>KENT /3</span>
                <span className="apk-mi-sep"> . </span>
                <span className="apk-mi-val">{kentStreak ?? 0}</span>
            </div>
            <div className="apk-jp-counters">
                <div className="apk-jp apk-jp-side">
                    <span className="apk-jp-tag">× </span>
                    <span className="apk-jp-val">{jackpots ? formatMoney(fourOfAKindA) : "--"}</span>
                </div>
                <div className="apk-jp apk-jp-center">
                    <span className="apk-jp-val">{jackpots ? formatMoney(jackpots.straightFlush) : "--"}</span>
                </div>
                <div className="apk-jp apk-jp-side">
                    <span className="apk-jp-val">{jackpots ? formatMoney(fourOfAKindB) : "--"}</span>
                </div>
            </div>
            <div className="apk-jp-fh-row">
                <span className="apk-jp-fh-label">{rankLabelFromValue(fullHouseRank)}</span>
                <span className="apk-jp-fh-val">{jackpots ? formatMoney(jackpots.fullHouse) : "--"}</span>
            </div>
            {bonusText && <div className="apk-bonus-bar">{bonusText}</div>}
        </div>
    );
}

export function Lucky5Cabinet() {
    const [username, setUsername] = useState(DEFAULT_USERNAME);
    const [password, setPassword] = useState(DEFAULT_PASSWORD);
    const [otpCode, setOtpCode] = useState(DEFAULT_OTP);
    const [profile, setProfile] = useState<MemberProfile | null>(null);
    const [accessToken, setAccessToken] = useState<string | null>(null);
    const [machines, setMachines] = useState<MachineListing[]>([]);
    const [machineId, setMachineId] = useState<number | null>(null);
    const [machineState, setMachineState] = useState<MachineState | null>(null);
    const [machineSession, setMachineSession] = useState<MachineSession | null>(null);
    const [rules, setRules] = useState<DefaultRules | null>(null);
    const [history, setHistory] = useState<WalletLedgerEntry[]>([]);
    const [adminTab, setAdminTab] = useState<AdminPanelTab>("agents");
    const [adminUsers, setAdminUsers] = useState<AdminUser[]>([]);
    const [adminMachines, setAdminMachines] = useState<AdminMachine[]>([]);
    const [agents, setAgents] = useState<AgentInfo[]>([]);
    const [adminSearch, setAdminSearch] = useState("");
    const [adminSearchQuery, setAdminSearchQuery] = useState("");
    const [agentName, setAgentName] = useState("");
    const [agentCode, setAgentCode] = useState("");
    const [agentPhone, setAgentPhone] = useState("");
    const [agentCredit, setAgentCredit] = useState("100000");
    const [selectedAgentId, setSelectedAgentId] = useState<number | null>(null);
    const [selectedUserId, setSelectedUserId] = useState("");
    const [betAmount, setBetAmount] = useState("5000");
    const [holdIndexes, setHoldIndexes] = useState<number[]>([]);
    const [dealResult, setDealResult] = useState<DealResult | null>(null);
    const [drawResult, setDrawResult] = useState<DrawResult | null>(null);
    const [doubleUpResult, setDoubleUpResult] = useState<DoubleUpResult | null>(null);
    const [message, setMessage] = useState("Boot the cabinet, then choose a machine.");
    const [messageTone, setMessageTone] = useState<MessageTone>("ready");
    const [busy, setBusy] = useState(false);
    const [hasPressedBetThisSession, setHasPressedBetThisSession] = useState(false);
    const [isFhPickerOpen, setIsFhPickerOpen] = useState(false);
    const [idleFhCard, setIdleFhCard] = useState<PokerCard | null>(null);
    const [drainAmount, setDrainAmount] = useState(0);
    const [isDraining, setIsDraining] = useState(false);
    const [visibleCardIndexes, setVisibleCardIndexes] = useState<number[]>([]);
    const [revealingCardIndexes, setRevealingCardIndexes] = useState<number[]>([]);
    const revealTimeouts = useRef<number[]>([]);

    const MACHINE_CREDIT_LIMIT = 40000000;

    const selectedMachine = machines.find((machine) => machine.id === machineId) ?? null;
    const activeCards = drawResult?.cards ?? dealResult?.cards ?? [];
    const openRoundId = dealResult?.roundId ?? null;
    const hasWin = (drawResult?.winAmount ?? 0) > 0;
    const doubleUpViewModel = mapDoubleUpResultToViewModel(doubleUpResult);
    const doubleUpAmount = doubleUpViewModel?.currentAmount ?? drawResult?.winAmount ?? 0;
    const isInDoubleUp = doubleUpViewModel !== null && !doubleUpViewModel.isTerminal;
    const canEnterDoubleUp = hasWin && !!drawResult && !isInDoubleUp;
    const canGuessBigSmall = isInDoubleUp ? !!doubleUpViewModel?.canGuess : canEnterDoubleUp;
    const isAdmin = profile?.role?.toLowerCase() === "admin";
    const selectedAgent = agents.find((agent) => agent.id === selectedAgentId) ?? null;
    const visibleCardIndexSet = new Set(visibleCardIndexes);
    const revealingCardIndexSet = new Set(revealingCardIndexes);
    const activeCardCount = Math.min(activeCards.length, CARD_SLOT_COUNT);
    const isCardRevealRunning = !isInDoubleUp
        && activeCardCount > 0
        && (visibleCardIndexes.length < activeCardCount || revealingCardIndexes.length > 0);

    const clearRevealTimeouts = useCallback(() => {
        for (const timeoutId of revealTimeouts.current) {
            window.clearTimeout(timeoutId);
        }
        revealTimeouts.current = [];
    }, []);

    const resetCardReveal = useCallback(() => {
        clearRevealTimeouts();
        setVisibleCardIndexes([]);
        setRevealingCardIndexes([]);
    }, [clearRevealTimeouts]);

    const playCardReveal = useCallback((slots: number[], initialVisible: number[] = []) => {
        clearRevealTimeouts();

        const normalizedInitial = Array.from(new Set(
            initialVisible.filter((index) => index >= 0 && index < CARD_SLOT_COUNT),
        )).sort((left, right) => left - right);
        const normalizedInitialSet = new Set(normalizedInitial);
        const revealSlots = Array.from(new Set(
            slots.filter((index) =>
                index >= 0
                && index < CARD_SLOT_COUNT
                && !normalizedInitialSet.has(index),
            ),
        )).sort((left, right) => left - right);

        setVisibleCardIndexes(normalizedInitial);
        setRevealingCardIndexes([]);

        for (const [step, index] of revealSlots.entries()) {
            const revealTimeout = window.setTimeout(() => {
                setVisibleCardIndexes((current) =>
                    current.includes(index)
                        ? current
                        : [...current, index].sort((left, right) => left - right),
                );
                setRevealingCardIndexes((current) =>
                    current.includes(index) ? current : [...current, index],
                );

                const settleTimeout = window.setTimeout(() => {
                    setRevealingCardIndexes((current) => current.filter((value) => value !== index));
                }, CARD_REVEAL_ANIMATION_MS);
                revealTimeouts.current.push(settleTimeout);
            }, step * CARD_REVEAL_STAGGER_MS);
            revealTimeouts.current.push(revealTimeout);
        }
    }, [clearRevealTimeouts]);

    useEffect(() => () => {
        clearRevealTimeouts();
    }, [clearRevealTimeouts]);

    function clearActiveRoundState() {
        setDealResult(null);
        setDrawResult(null);
        setHoldIndexes([]);
        resetCardReveal();
    }
    const isMachineClosed = machineSession?.isMachineClosed ?? false;

    const payoutRows = Object.entries(rules?.payoutMultipliers ?? {}).sort(
        (left, right) => Number(right[1]) - Number(left[1]),
    );

    const refreshBootstrap = useCallback(async () => {
        if (!accessToken) {
            return;
        }

        const [nextProfile, nextMachines, nextRules, nextHistory] = await Promise.all([
            getProfile(accessToken),
            listMachines(accessToken),
            getDefaultRules(),
            getMemberHistory(accessToken),
        ]);

        setProfile(nextProfile);
        setMachines(nextMachines);
        setRules(nextRules);
        setHistory(nextHistory);

        if (!machineId && nextMachines.length > 0) {
            startTransition(() => {
                setMachineId(nextMachines[0].id);
                setBetAmount(String(nextMachines[0].minBet));
            });
        }
    }, [accessToken, machineId]);

    const refreshHistory = useCallback(async () => {
        if (!accessToken) {
            return;
        }

        setHistory(await getMemberHistory(accessToken));
    }, [accessToken]);

    const refreshMachineState = useCallback(async () => {
        if (!accessToken || !machineId) {
            return;
        }

        setMachineState(await getMachineState(machineId, accessToken));
    }, [accessToken, machineId]);

    const refreshMachineSession = useCallback(async () => {
        if (!accessToken || !machineId) {
            return;
        }

        setMachineSession(await getMachineSession(machineId, accessToken));
    }, [accessToken, machineId]);

    const refreshAdminPanel = useCallback(async () => {
        if (!accessToken || !isAdmin) {
            return;
        }

        if (adminTab === "users") {
            const query = adminSearchQuery.trim();
            setAdminUsers(query ? await searchAdminUsers(query, accessToken) : await listAdminUsers(accessToken));
            return;
        }

        if (adminTab === "agents") {
            const nextAgents = await listAgents(accessToken);
            setAgents(nextAgents);
            if (!selectedAgentId && nextAgents.length > 0) {
                setSelectedAgentId(nextAgents[0].id);
            }
            return;
        }

        setAdminMachines(await listAdminMachines(accessToken));
    }, [accessToken, adminSearchQuery, adminTab, isAdmin, selectedAgentId]);

    useEffect(() => {
        if (!accessToken) {
            return;
        }

        void refreshBootstrap();
    }, [accessToken, refreshBootstrap]);

    useEffect(() => {
        if (!accessToken || !machineId) {
            return;
        }

        void refreshMachineState();
        void refreshMachineSession();
        const timer = window.setInterval(() => {
            void refreshMachineState();
            void refreshMachineSession();
        }, 5000);
        return () => window.clearInterval(timer);
    }, [accessToken, machineId, refreshMachineState, refreshMachineSession]);

    useEffect(() => {
        if (!isAdmin) {
            return;
        }

        void refreshAdminPanel();
    }, [isAdmin, refreshAdminPanel]);

    async function runAction(action: () => Promise<void>) {
        setBusy(true);
        try {
            await action();
        } catch (error) {
            setMessage(error instanceof Error ? error.message : "Unexpected Lucky5 failure.");
            setMessageTone("danger");
        } finally {
            setBusy(false);
        }
    }

    function syncWallet(walletBalance: number) {
        setProfile((current) => (current ? { ...current, walletBalance } : current));
    }

    async function handleBoot() {
        await runAction(async () => {
            try {
                const signupResult = await signup(username, password, "+96101000000");
                const previewCode = signupResult.otp?.previewCode?.trim();
                if (previewCode) {
                    setOtpCode(previewCode);
                }
            } catch {
                // Existing user is acceptable.
            }

            try {
                await verifyOtp(username, otpCode);
            } catch {
                // Already-verified users are fine.
            }

            const authenticated = await login(username, password);
            setAccessToken(authenticated.tokens.accessToken);
            setProfile(authenticated.profile);
            setMessage("Cabinet synced. Pick a machine and press DEAL.");
            setMessageTone("ready");
        });
    }

    async function handleMachineSelection(machine: MachineListing) {
        startTransition(() => {
            setMachineId(machine.id);
            setBetAmount(String(machine.minBet));
            setDealResult(null);
            setDrawResult(null);
            setDoubleUpResult(null);
            setHoldIndexes([]);
            resetCardReveal();
        });

        setMessage(`${machine.name} linked. Set your wager and deal.`);
        setMessageTone("ready");

        if (accessToken) {
            await runAction(async () => {
                setMachineState(await getMachineState(machine.id, accessToken));
            });
        }
    }

    async function handleDealOrDraw() {
        if (isCardRevealRunning) {
            return;
        }

        if (!accessToken || !machineId) {
            setMessage("Boot the cabinet and select a machine first.");
            setMessageTone("warning");
            return;
        }

        if (dealResult && !drawResult) {
            await runAction(async () => {
                const heldSlots = [...holdIndexes].sort((a, b) => a - b);
                const result = await draw(
                    dealResult.roundId,
                    heldSlots,
                    accessToken,
                );
                setDrawResult(result);
                setDoubleUpResult(null);
                playCardReveal(CARD_SLOT_INDEXES.filter((index) => !heldSlots.includes(index)), heldSlots);
                syncWallet(result.walletBalanceAfterRound);
                setMessage(
                    result.winAmount > 0
                        ? `${result.handRank} paid ${formatMoney(result.winAmount)}. Take score or press BIG/SMALL.`
                        : `${result.handRank}. Round settled, ready for the next deal.`,
                );
                setMessageTone(result.winAmount > 0 ? "ready" : "warning");
                await Promise.all([refreshHistory(), refreshMachineState()]);
            });
            return;
        }

        await runAction(async () => {
            const result = await deal(machineId, Number(betAmount || "5000"), accessToken);
            setDealResult(result);
            setDrawResult(null);
            setDoubleUpResult(null);
            setHoldIndexes([]);
            playCardReveal(CARD_SLOT_INDEXES);
            syncWallet(result.walletBalanceAfterBet);
            setMessage("Choose the cards to HOLD, then press DRAW.");
            setMessageTone("ready");
            await Promise.all([refreshHistory(), refreshMachineState()]);
        });
    }

    async function handleSwitch() {
        if (isCardRevealRunning) {
            return;
        }

        if (!accessToken || !openRoundId) {
            return;
        }

        await runAction(async () => {
            const result = await switchDealer(openRoundId, accessToken);
            setDoubleUpResult(result);
            syncWallet(result.walletBalance);
            setMessage(`Dealer switched. Status: ${result.status}.`);
            setMessageTone(toneForStatus(result.status));
            await Promise.all([refreshHistory(), refreshMachineState()]);
        });
    }

    function handleBetPress() {
        if (isInDoubleUp) {
            if (doubleUpViewModel?.canSwitch) {
                void handleSwitch();
            }
            return;
        }

        setHasPressedBetThisSession(true);
        const next = selectedMachine
            ? Math.min(Number(betAmount) + (selectedMachine.minBet), selectedMachine.maxBet)
            : Number(betAmount);
        setBetAmount(String(next));
    }

    async function handleGuess(guess: "big" | "small") {
        if (isCardRevealRunning || !accessToken) {
            return;
        }

        if (!isInDoubleUp) {
            if (!drawResult || !hasWin) {
                return;
            }

            await runAction(async () => {
                const result = await guessDoubleUp(drawResult.roundId, guess, accessToken);
                setDoubleUpResult(result);
                syncWallet(result.walletBalance);
                setMessage(`${guess.toUpperCase()} resolved: ${result.status}. Current amount ${formatMoney(result.currentAmount)}.`);
                setMessageTone(toneForStatus(result.status));
                if (isTerminalDoubleUpStatus(result.status)) {
                    clearActiveRoundState();
                }
                await Promise.all([refreshHistory(), refreshMachineState()]);
            });
            return;
        }

        const roundId = doubleUpResult?.roundId ?? openRoundId;
        if (!roundId || !doubleUpViewModel?.canGuess) {
            return;
        }

        await runAction(async () => {
            const result = await guessDoubleUp(roundId, guess, accessToken);
            setDoubleUpResult(result);
            syncWallet(result.walletBalance);
            setMessage(`${guess.toUpperCase()} resolved: ${result.status}. Current amount ${formatMoney(result.currentAmount)}.`);
            setMessageTone(toneForStatus(result.status));
            if (isTerminalDoubleUpStatus(result.status)) {
                clearActiveRoundState();
            }
            await Promise.all([refreshHistory(), refreshMachineState()]);
        });
    }

    async function handleCashout() {
        if (isCardRevealRunning) {
            return;
        }

        if (!accessToken || !openRoundId) {
            return;
        }

        const amountToDrain = doubleUpAmount;

        await runAction(async () => {
            const result = await cashoutDoubleUp(openRoundId, accessToken);
            setDoubleUpResult(result);

            // Coupled drain animation: paytable → credit counter
            setIsDraining(true);
            setDrainAmount(amountToDrain);

            // Determine animation duration based on win tier
            const isJackpot = result.status === "Jackpot" || result.status === "RoyalFlush";
            const duration = isJackpot ? 5000 : 2000; // 5s for jackpots, 2s for regular

            const startTime = performance.now();
            const animate = (currentTime: number) => {
                const elapsed = currentTime - startTime;
                const progress = Math.min(elapsed / duration, 1);

                setDrainAmount(Math.max(0, amountToDrain * (1 - progress)));

                if (progress < 1) {
                    requestAnimationFrame(animate);
                } else {
                    setIsDraining(false);
                    syncWallet(result.walletBalance);
                    setMessage(`Score taken: ${formatMoney(result.currentAmount)}.`);
                    setMessageTone("ready");
                    clearActiveRoundState();
                    void Promise.all([refreshHistory(), refreshMachineState()]);
                }
            };

            requestAnimationFrame(animate);
        });
    }

    async function handleTakeHalf() {
        if (isCardRevealRunning) {
            return;
        }

        if (!accessToken || !openRoundId) {
            return;
        }

        await runAction(async () => {
            const result = await takeHalf(openRoundId, accessToken);
            setDoubleUpResult(result);
            syncWallet(result.walletBalance);
            setMessage(`Half banked. ${formatMoney(result.currentAmount)} stays in play.`);
            setMessageTone("warning");
            if (isTerminalDoubleUpStatus(result.status)) {
                clearActiveRoundState();
            }
            await Promise.all([refreshHistory(), refreshMachineState()]);
        });
    }

    async function handleAdminSearch() {
        setAdminTab("users");
        setAdminSearchQuery(adminSearch.trim());
        if (adminTab === "users" && adminSearch.trim() === adminSearchQuery.trim()) {
            await runAction(refreshAdminPanel);
        }
    }

    async function handleCreateAgent() {
        if (!accessToken || !isAdmin) {
            return;
        }

        const name = agentName.trim();
        const code = agentCode.trim().toUpperCase();
        const phoneNumber = agentPhone.trim() || "N/A";
        if (!name || !code) {
            setMessage("Agent name and code are required.");
            setMessageTone("warning");
            return;
        }

        await runAction(async () => {
            const agent = await createAgent({ name, code, phoneNumber }, accessToken);
            setAgents((current) => [agent, ...current.filter((row) => row.id !== agent.id)]);
            setSelectedAgentId(agent.id);
            setAgentName("");
            setAgentCode("");
            setAgentPhone("");
            setMessage(`Agent ${agent.code} created.`);
            setMessageTone("ready");
        });
    }

    async function handleLoadAgentCredit() {
        if (!accessToken || !selectedAgentId) {
            return;
        }

        const amount = Number(agentCredit);
        if (!Number.isFinite(amount) || amount <= 0) {
            setMessage("Enter a positive agent credit amount.");
            setMessageTone("warning");
            return;
        }

        await runAction(async () => {
            const agent = await loadAgentCredit(selectedAgentId, amount, accessToken);
            setAgents((current) => current.map((row) => (row.id === agent.id ? agent : row)));
            setMessage(`Loaded ${formatMoney(amount)} to agent ${agent.code}.`);
            setMessageTone("ready");
        });
    }

    async function handleAssignUserToAgent(userId: string) {
        if (!accessToken || !selectedAgentId) {
            setMessage("Select an agent before assigning a user.");
            setMessageTone("warning");
            return;
        }

        await runAction(async () => {
            await assignUserToAgent(selectedAgentId, userId, accessToken);
            setSelectedUserId(userId);
            setMessage(`User assigned to ${selectedAgent?.code ?? "agent"}.`);
            setMessageTone("ready");
        });
    }

    function toggleHold(index: number) {
        if (isCardRevealRunning) {
            return;
        }

        // FH-rank picker: HOLD[0] opens picker when idle + bet-pressed
        if (index === 0 && !dealResult && !drawResult && !isInDoubleUp && hasPressedBetThisSession) {
            setIsFhPickerOpen(true);
            return;
        }

        if (!dealResult || drawResult) {
            return;
        }

        setHoldIndexes((current) =>
            current.includes(index)
                ? current.filter((value) => value !== index)
                : [...current, index].sort((a, b) => a - b),
        );
    }

    async function handleSwitchFhRank(rank: number) {
        if (!accessToken || !machineId) {
            return;
        }

        await runAction(async () => {
            const result = await switchFhRank(machineId, rank, accessToken);
            await refreshMachineState();
            setMessage(`Full House rank switched to ${rank}.`);
            setMessageTone("ready");
        });
        setIsFhPickerOpen(false);
    }

    const jackpotSnapshot = machineState?.jackpots;
    const fourOfAKindA = Number(
        (jackpotSnapshot as unknown as Record<string, number | undefined> | undefined)?.fourOfAKindA ?? 0,
    );
    const fourOfAKindB = Number(
        (jackpotSnapshot as unknown as Record<string, number | undefined> | undefined)?.fourOfAKindB ?? 0,
    );

    const bonusText = "4 OF A KIND   WINS BONUS";

    // Rotating idle FH face-up card in the middle slot (zero-based index 2) when not in a round.
    useEffect(() => {
        if (dealResult || drawResult || isInDoubleUp) {
            setIdleFhCard(null);
            return;
        }

        // Generate a random FH card based on current jackpot rank
        const currentRank = jackpotSnapshot?.fullHouseRank ?? 2;
        const suits = ["H", "D", "C", "S"];
        const randomSuit = suits[Math.floor(Math.random() * suits.length)];
        const rankLabel = rankLabelFromValue(currentRank);

        setIdleFhCard({ rank: rankLabel, suit: randomSuit, code: `${rankLabel}${randomSuit}` });

        // Rotate every 3 seconds
        const rotationTimer = window.setInterval(() => {
            const newSuit = suits[Math.floor(Math.random() * suits.length)];
            setIdleFhCard({ rank: rankLabel, suit: newSuit, code: `${rankLabel}${newSuit}` });
        }, 3000);

        return () => window.clearInterval(rotationTimer);
    }, [dealResult, drawResult, isInDoubleUp, jackpotSnapshot?.fullHouseRank]);

    return (
        <div className="cabinet-shell">
            <section className="cabinet">
                <div className="screen">

                    {/* ── Top band: paytable (left 62%) + credit/stake (right 38%) ── */}
                    <div className="apk-top-band">
                        <PaytablePanel
                            payouts={rules?.payoutMultipliers ?? {}}
                            activeHand={drawResult?.handRank ?? null}
                            jackpotFh={jackpotSnapshot?.fullHouse}
                            stake={betAmount || "5000"}
                        />
                        <CreditStakeBar
                            credit={profile?.walletBalance ?? 0}
                            stake={betAmount || "5000"}
                        />
                    </div>

                    {/* ── Label band ── */}
                    {isInDoubleUp && (
                        <div className="apk-label-band apk-du-label">DOUBLE UP</div>
                    )}

                    {/* ── Card stage ── */}
                    <div className="apk-card-stage">
                        {isInDoubleUp ? (
                            <DoubleUpBoard viewModel={doubleUpViewModel} />
                        ) : (
                            /* Normal 5-card row with hold-click */
                            <div className="apk-card-row">
                                {Array.from({ length: CARD_SLOT_COUNT }, (_, index) => {
                                    // Idle FH face-up card in the middle slot (zero-based index 2) when not in a round.
                                    const isIdleSlot = index === 2 && !dealResult && !drawResult && !isInDoubleUp;
                                    const cardToDisplay = isIdleSlot
                                        ? idleFhCard
                                        : visibleCardIndexSet.has(index)
                                            ? (activeCards[index] ?? null)
                                            : null;
                                    return (
                                        <PlayingCard
                                            key={`card-${index}`}
                                            card={cardToDisplay}
                                            held={holdIndexes.includes(index)}
                                            revealing={revealingCardIndexSet.has(index)}
                                            onClick={isCardRevealRunning ? undefined : () => toggleHold(index)}
                                        />
                                    );
                                })}
                            </div>
                        )}
                    </div>

                    {/* ── Win amount display ── */}
                    {(drawResult?.winAmount ?? 0) > 0 && (
                        <div className="apk-win-amount">
                            {isDraining ? formatMoney(drainAmount) : formatMoney(doubleUpAmount)}
                        </div>
                    )}

                    {/* ── Machine info block ── */}
                    <MachineInfoBlock
                        machineName={selectedMachine?.name}
                        jackpots={jackpotSnapshot}
                        fourOfAKindA={fourOfAKindA}
                        fourOfAKindB={fourOfAKindB}
                        bonusText={bonusText}
                        machineSerial={jackpotSnapshot?.machineSerial}
                        kentStreak={jackpotSnapshot?.kentStreak}
                        fullHouseRank={jackpotSnapshot?.fullHouseRank}
                    />

                    {/* ── Control deck ── */}
                    <div className="apk-control-deck">
                        {!profile ? (
                            /* Auth panel when not logged in */
                            <div className="auth-panel">
                                <div className="section-title">Boot the cabinet</div>
                                <div className="auth-hint">
                                    Sign up if needed, verify the issued OTP, then log in.
                                </div>
                                <div className="auth-grid">
                                    <label>
                                        Username
                                        <input value={username} onChange={(event) => setUsername(event.target.value)} />
                                    </label>
                                    <label>
                                        Password
                                        <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} />
                                    </label>
                                    <label>
                                        OTP
                                        <input value={otpCode} onChange={(event) => setOtpCode(event.target.value)} />
                                    </label>
                                </div>
                                <button className="auth-button" type="button" onClick={() => void handleBoot()} disabled={busy}>
                                    {busy ? "BOOTING" : "SIGN UP / LOGIN"}
                                </button>
                            </div>
                        ) : (
                            <>
                                {/* Row 1 — HOLD buttons */}
                                <div className="apk-hold-row">
                                    {Array.from({ length: CARD_SLOT_COUNT }, (_, index) => (
                                        <button
                                            key={index}
                                            className={`apk-hold-btn${holdIndexes.includes(index) ? " active" : ""}`}
                                            type="button"
                                            onClick={() => toggleHold(index)}
                                            disabled={!dealResult || !!drawResult || busy || isInDoubleUp || isCardRevealRunning}
                                        >
                                            {index === 0 && !dealResult && !drawResult && !isInDoubleUp && hasPressedBetThisSession ? "FH" : "HOLD"}
                                        </button>
                                    ))}
                                </div>

                                {/* Row 2 — BIG | SMALL | CANCEL HOLD | DEAL/DRAW | BET */}
                                <div className="apk-action-row">
                                    <button
                                        className="apk-btn apk-btn-big"
                                        type="button"
                                        onClick={() => void handleGuess("big")}
                                        disabled={busy || isCardRevealRunning || !canGuessBigSmall}
                                    >
                                        BIG
                                    </button>
                                    <button
                                        className="apk-btn apk-btn-small"
                                        type="button"
                                        onClick={() => void handleGuess("small")}
                                        disabled={busy || isCardRevealRunning || !canGuessBigSmall}
                                    >
                                        SMALL
                                    </button>
                                    <button
                                        className="apk-btn apk-btn-cancel"
                                        type="button"
                                        onClick={() => {
                                            setHoldIndexes([]);
                                        }}
                                        disabled={busy || !dealResult || !!drawResult || isInDoubleUp || isCardRevealRunning}
                                    >
                                        CANCEL<br />HOLD
                                    </button>
                                    <button
                                        className="apk-btn apk-btn-deal"
                                        type="button"
                                        onClick={() => void handleDealOrDraw()}
                                        disabled={busy || !machineId || isInDoubleUp || isCardRevealRunning}
                                    >
                                        {busy ? "WAIT" : dealResult && !drawResult ? "DRAW" : "DEAL"}<br />
                                        {dealResult && !drawResult ? "" : "DRAW"}
                                    </button>
                                    <button
                                        className="apk-btn apk-btn-bet"
                                        type="button"
                                        onClick={() => void handleBetPress()}
                                        disabled={
                                            busy
                                            || (isInDoubleUp
                                                ? !doubleUpViewModel?.canSwitch
                                                : !!dealResult)
                                        }
                                    >
                                        BET
                                    </button>
                                </div>

                                {/* Row 3 — TAKE HALF | MENU (machine select) | TAKE SCORE */}
                                <div className="apk-bottom-row">
                                    <button
                                        className="apk-btn apk-btn-take-half"
                                        type="button"
                                        onClick={() => void handleTakeHalf()}
                                        disabled={busy || isCardRevealRunning || !openRoundId || (!hasWin && !doubleUpResult)}
                                    >
                                        TAKE<br />HALF
                                    </button>

                                    {/* MENU — machine selector overlay */}
                                    <div className="apk-menu-wrap">
                                        <div className="apk-menu-btn-label">MENU</div>
                                        <div className="apk-menu-popup">
                                            {machines.map((machine) => (
                                                <button
                                                    key={machine.id}
                                                    className={`machine-button${machine.id === machineId ? " active" : ""}`}
                                                    type="button"
                                                    onClick={() => void handleMachineSelection(machine)}
                                                    disabled={!machine.isOpen || busy}
                                                >
                                                    <strong>{machine.name}</strong>
                                                    <small>{formatMoney(machine.minBet)} – {formatMoney(machine.maxBet)}</small>
                                                </button>
                                            ))}
                                            <button
                                                className="machine-button"
                                                type="button"
                                                disabled={!machineId || busy}
                                                onClick={() => {
                                                    setMachineId(null);
                                                    setDealResult(null);
                                                    setDrawResult(null);
                                                    setDoubleUpResult(null);
                                                    setMessage("Returned to lobby. Pick a machine.");
                                                    setMessageTone("ready");
                                                }}
                                            >
                                                <strong>BACK TO LOBBY</strong>
                                            </button>
                                        </div>
                                    </div>

                                    <button
                                        className="apk-btn apk-btn-take-score"
                                        type="button"
                                        onClick={() => void handleCashout()}
                                        disabled={busy || isCardRevealRunning || !openRoundId || (!hasWin && !doubleUpResult)}
                                    >
                                        TAKE<br />SCORE
                                    </button>
                                </div>

                                {/* Double-up status mirrors the original deck: BIG/SMALL enter, BET switches. */}
                                {(hasWin || isInDoubleUp) && (
                                    <div className="apk-du-status-row">
                                        <div className="apk-du-info" aria-live="polite">
                                            <div className="apk-du-status">
                                                {isInDoubleUp ? doubleUpViewModel?.status ?? "DOUBLE-UP" : "DOUBLE-UP READY"}
                                            </div>
                                            <div className="apk-du-amount">
                                                {formatMoney(doubleUpAmount)}
                                            </div>
                                            {isInDoubleUp && (doubleUpViewModel?.switchesRemaining ?? 0) > 0 && (
                                                <div className="apk-du-switches">
                                                    BET SW: {doubleUpViewModel!.switchesRemaining}
                                                </div>
                                            )}
                                            {!isInDoubleUp && hasWin && (
                                                <div className="apk-du-switches">BIG / SMALL</div>
                                            )}
                                        </div>
                                    </div>
                                )}

                                {/* Message bar */}
                                <div className={`apk-message-bar apk-message-${messageTone}`}>{message}</div>
                            </>
                        )}
                    </div>
                </div>
            </section>

            {/* ── Machine-closed overlay ── */}
            {isMachineClosed && (
                <div className="apk-machine-closed-overlay">
                    <div className="apk-machine-closed-content">
                        <div className="apk-machine-closed-title">MACHINE CLOSED</div>
                        <div className="apk-machine-closed-subtitle">
                            Credits reached {formatMoney(MACHINE_CREDIT_LIMIT)}
                        </div>
                    </div>
                </div>
            )}

            {/* ── FH-rank picker modal ── */}
            {isFhPickerOpen && (
                <div className="apk-fh-picker-overlay">
                    <div className="apk-fh-picker-modal">
                        <div className="apk-fh-picker-title">SELECT FULL HOUSE RANK</div>
                        <div className="apk-fh-picker-ranks">
                            {Array.from({ length: 13 }, (_, i) => {
                                const rank = i + 2;
                                const rankLabel = rankLabelFromValue(rank);
                                const currentRank = jackpotSnapshot?.fullHouseRank ?? 2;
                                return (
                                    <button
                                        key={rank}
                                        className={`apk-fh-rank-btn${rank === currentRank ? " active" : ""}`}
                                        type="button"
                                        onClick={() => void handleSwitchFhRank(rank)}
                                        disabled={busy}
                                    >
                                        {rankLabel}
                                    </button>
                                );
                            })}
                        </div>
                        <button
                            className="apk-fh-picker-close"
                            type="button"
                            onClick={() => setIsFhPickerOpen(false)}
                            disabled={busy}
                        >
                            CANCEL
                        </button>
                    </div>
                </div>
            )}

            {/* ── Side column: telemetry + history ── */}
            <aside className="side-column">
                {isAdmin && (
                    <section className="admin-agent-panel">
                        <div className="admin-panel-head">
                            <div>
                                <div className="section-title">Admin / agent</div>
                                <div className="section-subtitle">{profile?.username} · {profile?.role}</div>
                            </div>
                            <button
                                className="admin-mini-button"
                                type="button"
                                onClick={() => void runAction(refreshAdminPanel)}
                                disabled={busy}
                            >
                                REFRESH
                            </button>
                        </div>

                        <div className="admin-tabs" role="tablist" aria-label="Admin menu">
                            {(["agents", "users", "machines"] as AdminPanelTab[]).map((tab) => (
                                <button
                                    key={tab}
                                    className={`admin-tab${adminTab === tab ? " active" : ""}`}
                                    type="button"
                                    onClick={() => setAdminTab(tab)}
                                >
                                    {tab}
                                </button>
                            ))}
                        </div>

                        {adminTab === "agents" && (
                            <div className="admin-stack">
                                <div className="admin-form-grid">
                                    <input
                                        aria-label="Agent name"
                                        placeholder="AGENT NAME"
                                        value={agentName}
                                        onChange={(event) => setAgentName(event.target.value)}
                                    />
                                    <input
                                        aria-label="Agent code"
                                        placeholder="CODE"
                                        value={agentCode}
                                        onChange={(event) => setAgentCode(event.target.value)}
                                    />
                                    <input
                                        aria-label="Agent phone"
                                        placeholder="PHONE"
                                        value={agentPhone}
                                        onChange={(event) => setAgentPhone(event.target.value)}
                                    />
                                </div>
                                <button
                                    className="admin-command"
                                    type="button"
                                    onClick={() => void handleCreateAgent()}
                                    disabled={busy}
                                >
                                    CREATE AGENT
                                </button>
                                <div className="admin-load-row">
                                    <select
                                        aria-label="Selected agent"
                                        value={selectedAgentId ?? ""}
                                        onChange={(event) => setSelectedAgentId(event.target.value ? Number(event.target.value) : null)}
                                    >
                                        <option value="">SELECT AGENT</option>
                                        {agents.map((agent) => (
                                            <option key={agent.id} value={agent.id}>
                                                {agent.code} · {agent.name}
                                            </option>
                                        ))}
                                    </select>
                                    <input
                                        aria-label="Agent credit"
                                        inputMode="numeric"
                                        value={agentCredit}
                                        onChange={(event) => setAgentCredit(event.target.value)}
                                    />
                                    <button
                                        className="admin-mini-button"
                                        type="button"
                                        onClick={() => void handleLoadAgentCredit()}
                                        disabled={busy || !selectedAgentId}
                                    >
                                        LOAD
                                    </button>
                                </div>
                                <div className="admin-list">
                                    {agents.length === 0 && <div className="hint">No agents loaded.</div>}
                                    {agents.slice(0, 6).map((agent) => (
                                        <button
                                            key={agent.id}
                                            className={`admin-list-row admin-list-row-button${selectedAgentId === agent.id ? " active" : ""}`}
                                            type="button"
                                            onClick={() => setSelectedAgentId(agent.id)}
                                        >
                                            <span>
                                                <strong>{agent.code}</strong>
                                                <small>{agent.name} · {agent.phoneNumber || "no phone"}</small>
                                            </span>
                                            <em>{formatMoney(agent.creditPool)}</em>
                                        </button>
                                    ))}
                                </div>
                            </div>
                        )}

                        {adminTab === "users" && (
                            <div className="admin-stack">
                                <div className="admin-search-row">
                                    <input
                                        aria-label="User search"
                                        placeholder="SEARCH USER"
                                        value={adminSearch}
                                        onChange={(event) => setAdminSearch(event.target.value)}
                                        onKeyDown={(event) => {
                                            if (event.key === "Enter") {
                                                void handleAdminSearch();
                                            }
                                        }}
                                    />
                                    <button
                                        className="admin-mini-button"
                                        type="button"
                                        onClick={() => void handleAdminSearch()}
                                        disabled={busy}
                                    >
                                        SEARCH
                                    </button>
                                    <button
                                        className="admin-mini-button"
                                        type="button"
                                        onClick={() => {
                                            setAdminSearch("");
                                            setAdminSearchQuery("");
                                        }}
                                        disabled={busy}
                                    >
                                        ALL
                                    </button>
                                </div>
                                <div className="admin-list">
                                    {adminUsers.length === 0 && <div className="hint">No users loaded.</div>}
                                    {adminUsers.slice(0, 7).map((user) => (
                                        <div
                                            key={user.userId}
                                            className={`admin-list-row admin-user-row${selectedUserId === user.userId ? " active" : ""}`}
                                        >
                                            <span>
                                                <strong>{user.username}</strong>
                                                <small>{user.role} · {user.phoneNumber || "no phone"}</small>
                                            </span>
                                            <em>{formatMoney(user.walletBalance)}</em>
                                            <button
                                                className="admin-mini-button"
                                                type="button"
                                                onClick={() => void handleAssignUserToAgent(user.userId)}
                                                disabled={busy || !selectedAgentId}
                                            >
                                                ASSIGN
                                            </button>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}

                        {adminTab === "machines" && (
                            <div className="admin-list">
                                {adminMachines.length === 0 && <div className="hint">No machines loaded.</div>}
                                {adminMachines.slice(0, 6).map((machine) => (
                                    <div className="admin-list-row admin-machine-row" key={machine.machineId}>
                                        <span>
                                            <strong>{machine.name}</strong>
                                            <small>
                                                {machine.phase} · {machine.activePlayers} players · {machine.activeRounds} rounds
                                            </small>
                                        </span>
                                        <em>{formatPercent(machine.observedRtp)}</em>
                                        <small>{machine.isOpen ? "OPEN" : "CLOSED"}</small>
                                    </div>
                                ))}
                            </div>
                        )}
                    </section>
                )}

                <section className="diagnostics diagnostics-secondary">
                    <div className="section-title">Machine telemetry</div>
                    <div className="section-subtitle">Operational backend state.</div>
                    <div className="diagnostic-grid">
                        <div className="diagnostic-card">
                            <span>Observed RTP</span>
                            <strong>{machineState ? formatPercent(machineState.observedRtp) : "--"}</strong>
                        </div>
                        <div className="diagnostic-card">
                            <span>Target RTP</span>
                            <strong>{machineState ? formatPercent(machineState.targetRtp) : "--"}</strong>
                        </div>
                        <div className="diagnostic-card">
                            <span>Phase</span>
                            <strong>{machineState?.phase ?? "--"}</strong>
                        </div>
                        <div className="diagnostic-card">
                            <span>Active rounds</span>
                            <strong>{machineState?.activeRounds ?? 0}</strong>
                        </div>
                        <div className="diagnostic-card">
                            <span>Loss streak</span>
                            <strong>{machineState?.consecutiveLosses ?? 0}</strong>
                        </div>
                        <div className="diagnostic-card">
                            <span>Cooldown</span>
                            <strong>{machineState?.cooldownRemaining ?? 0}</strong>
                        </div>
                        <div className="diagnostic-card">
                            <span>Full house pot</span>
                            <strong>{machineState ? formatMoney(machineState.jackpots.fullHouse) : "--"}</strong>
                        </div>
                        <div className="diagnostic-card">
                            <span>Straight flush</span>
                            <strong>{machineState ? formatMoney(machineState.jackpots.straightFlush) : "--"}</strong>
                        </div>
                    </div>
                </section>

                <section className="history-panel">
                    <div className="section-title">Wallet trail</div>
                    <div className="history-list">
                        {history.length === 0 ? <div className="hint">No wallet activity yet.</div> : null}
                        {history.slice(0, 8).map((entry) => (
                            <div className="history-item" key={entry.id}>
                                <strong>{entry.type}</strong>
                                <span>{entry.reference.slice(0, 8)}</span>
                                <strong className={`history-amount ${entry.amount >= 0 ? "positive" : "negative"}`}>
                                    {entry.amount >= 0 ? "+" : ""}
                                    {formatMoney(entry.amount)}
                                </strong>
                            </div>
                        ))}
                    </div>
                </section>
            </aside>
        </div>
    );
}
