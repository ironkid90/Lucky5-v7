"use client";

import { useCallback, startTransition, useEffect, useRef, useState } from "react";

import {
    getActiveRound,
    adjustAdminUserWallet,
    applyRechargeBonus,
    assignUserToAgent,
    cashInMachine,
    cashOutMachine,
    cashoutDoubleUp,
    createAgent,
    deal,
    draw,
    listAdminAudit,
    listCabinetDevices,
    getAdminDashboard,
    getAdminMachineDetail,
    getAdminUserDetail,
    getDefaultRules,
    getMachineSession,
    getMachineState,
    getMemberHistory,
    getPlayerLobby,
    getProfile,
    guessDoubleUp,
    listAdminMachines,
    listAdminUsers,
    listAgents,
    listMachines,
    login,
    loadAgentCredit,
    resetAdminMachine,
    revokeCabinetDevice,
    searchAdminUsers,
    setAdminMachineDoorState,
    signup,
    switchDealer,
    switchFhRank,
    takeHalf,
    provisionCabinetDevice,
    verifyOtp,
} from "@/lib/api";
import type {
    ActiveRoundState,
    AdminAuditEntry,
    AdminDashboard,
    AdminMachine,
    AdminMachineDetail,
    AdminUser,
    AdminUserDetail,
    AgentInfo,
    CabinetDevice,
    CabinetDeviceProvisioning,
    DealResult,
    DefaultRules,
    DoubleUpResult,
    DrawResult,
    JackpotInfo,
    MachineListing,
    MachineSession,
    MachineState,
    MemberProfile,
    PlayerLobby,
    PlayerLobbyMachine,
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
    { key: "RoyalFlush", label: "ROYAL FLUSH", color: "#f7de59" },
    { key: "StraightFlush", label: "STRAIGHT FLUSH", color: "#ff5a67" },
    { key: "FourOfAKind", label: "4 OF A KIND", color: "#4be471" },
    { key: "FullHouse", label: "FULL HOUSE", color: "#f6f6f6" },
    { key: "Flush", label: "FLUSH", color: "#f4a532" },
    { key: "Straight", label: "STRAIGHT", color: "#5ca8ff" },
    { key: "ThreeOfAKind", label: "3 OF A KIND", color: "#ffc34f" },
    { key: "TwoPair", label: "2 PAIR", color: "#59d8ff" },
];

type MessageTone = "ready" | "warning" | "danger";
type AdminPanelTab = "overview" | "users" | "agents" | "machines" | "devices" | "audit";
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
const CARD_REVEAL_STAGGER_MS = 100;
const CARD_REVEAL_ANIMATION_MS = 210;
const IDLE_FH_REVEAL_DELAY_MS = 60_000;
const CABINET_STORAGE_KEY = "GetStorage";

type PersistedCabinetStorage = {
    userData?: {
        AccessToken?: string;
        User?: MemberProfile | null;
    };
    cabinet?: {
        machineId?: number | null;
        betAmount?: string;
        adminTab?: AdminPanelTab;
        selectedAgentId?: number | null;
        selectedUserId?: string;
        selectedDeviceId?: string;
    };
};

function formatMoney(value: number) {
    return new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(value);
}

function formatPercent(value: number) {
    return `${(value * 100).toFixed(1)}%`;
}

function formatDateTime(value?: string | null) {
    if (!value) {
        return "—";
    }

    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
        return value;
    }

    return parsed.toLocaleString();
}

function loadPersistedCabinetStorage(): PersistedCabinetStorage | null {
    if (typeof window === "undefined") {
        return null;
    }

    try {
        const raw = window.localStorage.getItem(CABINET_STORAGE_KEY);
        if (!raw) {
            return null;
        }

        const parsed = JSON.parse(raw) as PersistedCabinetStorage;
        return typeof parsed === "object" && parsed !== null ? parsed : null;
    } catch {
        return null;
    }
}

function savePersistedCabinetStorage(next: PersistedCabinetStorage) {
    if (typeof window === "undefined") {
        return;
    }

    window.localStorage.setItem(CABINET_STORAGE_KEY, JSON.stringify(next));
}

function clearPersistedCabinetStorage() {
    if (typeof window === "undefined") {
        return;
    }

    window.localStorage.removeItem(CABINET_STORAGE_KEY);
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
    const status = viewModel.status.toLowerCase();
    const dealerSwitchOnly = !!dealerCard
        && !revealCard
        && (status.includes("switch") || status.includes("lucky5"));
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

    if (!dealerSwitchOnly && slots.length < DOUBLE_UP_BOARD_SLOT_COUNT) {
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
    activeWinAmount = 0,
}: {
    payouts: Record<string, number>;
    activeHand?: string | null;
    jackpotFh?: number;
    stake: number | string;
    activeWinAmount?: number;
}) {
    const stakeValue = Math.max(0, Number(stake) || 0);

    return (
        <div className="apk-paytable">
            {PAYTABLE_ROWS.map(({ key, label, color }) => {
                const multiplier = payouts[key];
                const isActive = activeHand === key;
                const display = key === "FullHouse" && jackpotFh
                    ? formatMoney(jackpotFh)
                    : isActive && activeWinAmount > 0
                        ? formatMoney(activeWinAmount)
                    : multiplier !== undefined
                        ? formatMoney(multiplier * stakeValue)
                        : "0";
                return (
                    <div
                        key={key}
                        className={`apk-pay-row${isActive ? " apk-pay-row--active" : ""}`}
                        style={{ color }}
                    >
                        <span className={`apk-hand-name${isActive ? " apk-hand-name--active" : ""}`}>{label}</span>
                        <span className="apk-pay-amount">{display}</span>
                    </div>
                );
            })}
        </div>
    );
}

// ── CreditBar ───────────────────────────────────────────────────────────────
function CreditBar({ credit }: { credit: number }) {
    return (
        <div className="apk-credit-stake">
            <div className="apk-credit-only">
                <div className="apk-credit-label">CREDIT</div>
                <div className="apk-credit-value">{formatMoney(credit)}</div>
            </div>
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
    const machineSeries = machineName?.match(/\d+/)?.[0] ?? machineName ?? "—";

    return (
        <div className="apk-machine-info">
            <div className="apk-identity-row">
                <div className="apk-identity-copy">
                    <div className="apk-identity-line">
                        <span className="apk-mi-label">SERIE</span>
                        <span className="apk-mi-sep"> - </span>
                        <span className="apk-mi-val">{machineSeries}</span>
                    </div>
                    <div className="apk-identity-line">
                        <span className="apk-mi-label">KENT /3</span>
                        <span className="apk-mi-sep"> - </span>
                        <span className="apk-mi-val">{kentStreak ?? 0}</span>
                    </div>
                </div>
                {machineSerial && <div className="apk-serial-chip">S/N: {machineSerial}</div>}
            </div>
            <div className="apk-jp-fh-row">
                <span className="apk-jp-fh-label">{rankLabelFromValue(fullHouseRank)}</span>
                <span className="apk-jp-fh-val">{jackpots ? formatMoney(jackpots.fullHouse) : "--"}</span>
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
    const [lobby, setLobby] = useState<PlayerLobby | null>(null);
    const [machines, setMachines] = useState<MachineListing[]>([]);
    const [machineId, setMachineId] = useState<number | null>(null);
    const [machineState, setMachineState] = useState<MachineState | null>(null);
    const [machineSession, setMachineSession] = useState<MachineSession | null>(null);
    const [rules, setRules] = useState<DefaultRules | null>(null);
    const [history, setHistory] = useState<WalletLedgerEntry[]>([]);
    const [adminTab, setAdminTab] = useState<AdminPanelTab>("overview");
    const [adminDashboard, setAdminDashboard] = useState<AdminDashboard | null>(null);
    const [adminUsers, setAdminUsers] = useState<AdminUser[]>([]);
    const [adminMachines, setAdminMachines] = useState<AdminMachine[]>([]);
    const [adminAudit, setAdminAudit] = useState<AdminAuditEntry[]>([]);
    const [adminUserDetail, setAdminUserDetail] = useState<AdminUserDetail | null>(null);
    const [adminMachineDetail, setAdminMachineDetail] = useState<AdminMachineDetail | null>(null);
    const [cabinetDevices, setCabinetDevices] = useState<CabinetDevice[]>([]);
    const [deviceProvisioning, setDeviceProvisioning] = useState<CabinetDeviceProvisioning | null>(null);
    const [agents, setAgents] = useState<AgentInfo[]>([]);
    const [adminSearch, setAdminSearch] = useState("");
    const [adminSearchQuery, setAdminSearchQuery] = useState("");
    const [agentName, setAgentName] = useState("");
    const [agentCode, setAgentCode] = useState("");
    const [agentPhone, setAgentPhone] = useState("");
    const [agentCredit, setAgentCredit] = useState("100000");
    const [walletToolAmount, setWalletToolAmount] = useState("100000");
    const [walletToolReason, setWalletToolReason] = useState("operator adjustment");
    const [rechargeAmount, setRechargeAmount] = useState("500000");
    const [selectedAgentId, setSelectedAgentId] = useState<number | null>(null);
    const [selectedUserId, setSelectedUserId] = useState("");
    const [selectedDeviceId, setSelectedDeviceId] = useState("");
    const [deviceDisplayName, setDeviceDisplayName] = useState("");
    const [deviceSerialNumber, setDeviceSerialNumber] = useState("");
    const [deviceMachineId, setDeviceMachineId] = useState("");
    const [deviceRevokeReason, setDeviceRevokeReason] = useState("operator revoked");
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
    const selectedLobbyMachine = lobby?.machines.find((machine) => machine.id === machineId) ?? null;
    const lobbyMachineCards = lobby?.machines ?? machines.map((machine) => ({
        ...machine,
        jackpots: null,
        observedRtp: 0,
        phase: "Neutral",
        roundCount: 0,
        session: null,
        activeRound: null,
    } as unknown as PlayerLobbyMachine));
    const activeCards = drawResult?.cards ?? dealResult?.cards ?? [];
    const openRoundId = dealResult?.roundId ?? null;
    const hasWin = (drawResult?.winAmount ?? 0) > 0;
    const doubleUpViewModel = mapDoubleUpResultToViewModel(doubleUpResult);
    const doubleUpAmount = doubleUpViewModel?.currentAmount ?? drawResult?.winAmount ?? 0;
    const displayedWinAmount = isDraining ? drainAmount : doubleUpAmount;
    const cabinetCredit = machineSession?.machineCredits
        ?? selectedLobbyMachine?.session?.machineCredits
        ?? profile?.credit
        ?? 0;
    const isInDoubleUp = doubleUpViewModel !== null && !doubleUpViewModel.isTerminal;
    const canEnterDoubleUp = hasWin && !!drawResult && !isInDoubleUp;
    const canGuessBigSmall = isInDoubleUp ? !!doubleUpViewModel?.canGuess : canEnterDoubleUp;
    const isAdmin = profile?.role?.toLowerCase() === "admin";
    const selectedAgent = agents.find((agent) => agent.id === selectedAgentId) ?? null;
    const selectedDevice = cabinetDevices.find((device) => device.deviceId === selectedDeviceId) ?? null;
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

    function showRecoveredCards(cardCount: number) {
        clearRevealTimeouts();
        setVisibleCardIndexes(CARD_SLOT_INDEXES.slice(0, Math.min(cardCount, CARD_SLOT_COUNT)));
        setRevealingCardIndexes([]);
    }

    function hydrateActiveRound(
        activeRound: ActiveRoundState | null,
        nextSession: MachineSession | null,
        nextMachineState: MachineState | null,
    ) {
        if (!activeRound) {
            clearActiveRoundState();
            setDoubleUpResult(null);
            return;
        }

        const walletBalance = nextSession?.walletBalance ?? profile?.walletBalance ?? 0;
        const jackpots = nextMachineState?.jackpots ?? null;

        setBetAmount(String(activeRound.betAmount));
        setDealResult({
            roundId: activeRound.roundId,
            cards: activeRound.cards,
            betAmount: activeRound.betAmount,
            walletBalanceAfterBet: walletBalance,
            jackpots,
            advisedHolds: activeRound.phase === "Dealt" ? activeRound.heldIndexes : [],
        });

        if (activeRound.phase === "Dealt") {
            setHoldIndexes([...activeRound.heldIndexes]);
            setDrawResult(null);
            setDoubleUpResult(null);
            showRecoveredCards(activeRound.cards.length);
            setMessage("Recovered an in-progress hand. Choose holds and press DRAW.");
            setMessageTone("warning");
            return;
        }

        setHoldIndexes([]);
        setDrawResult({
            roundId: activeRound.roundId,
            cards: activeRound.resultCards.length > 0 ? activeRound.resultCards : activeRound.cards,
            handRank: activeRound.handRank,
            winAmount: activeRound.pendingWinAmount,
            walletBalanceAfterRound: walletBalance,
            jackpotWon: 0,
            jackpots,
            doubleUpAvailable: activeRound.doubleUpAvailable,
        });
        showRecoveredCards((activeRound.resultCards.length > 0 ? activeRound.resultCards : activeRound.cards).length);

        if (activeRound.phase === "DoubleUp" && activeRound.doubleUpSession) {
            setDoubleUpResult({
                roundId: activeRound.roundId,
                status: "Recovered",
                currentAmount: activeRound.doubleUpSession.currentAmount,
                walletBalance,
                dealerCard: activeRound.doubleUpSession.dealerCard,
                challengerCard: null,
                cardTrail: activeRound.doubleUpSession.cardTrail ?? [],
                switchesRemaining: activeRound.doubleUpSession.switchesRemaining,
                isNoLoseActive: activeRound.doubleUpSession.isNoLoseActive,
                isLucky5Active: activeRound.doubleUpSession.isLucky5Active,
                luckyMultiplier: activeRound.doubleUpSession.luckyMultiplier,
                noise: null,
            });
            setMessage("Recovered an active double-up sequence.");
            setMessageTone("warning");
            return;
        }

        setDoubleUpResult(null);
        setMessage(
            activeRound.pendingWinAmount > 0
                ? `${activeRound.handRank} is waiting. Take score or press BIG/SMALL.`
                : "Recovered the last round state.",
        );
        setMessageTone(activeRound.pendingWinAmount > 0 ? "warning" : "ready");
    }

    const payoutRows = Object.entries(rules?.payoutMultipliers ?? {}).sort(
        (left, right) => Number(right[1]) - Number(left[1]),
    );

    const refreshLobby = useCallback(async () => {
        if (!accessToken) {
            return null;
        }

        const nextLobby = await getPlayerLobby(accessToken);
        setLobby(nextLobby);
        setMachines(nextLobby.machines.map((machine) => ({
            id: machine.id,
            name: machine.name,
            isOpen: machine.isOpen,
            minBet: machine.minBet,
            maxBet: machine.maxBet,
        })));
        setProfile((current) => current ? { ...current, walletBalance: nextLobby.walletBalance, credit: nextLobby.credit } : current);
        return nextLobby;
    }, [accessToken]);

    const refreshBootstrap = useCallback(async () => {
        if (!accessToken) {
            return;
        }

        const [nextProfile, nextLobby, nextRules, nextHistory] = await Promise.all([
            getProfile(accessToken),
            getPlayerLobby(accessToken),
            getDefaultRules(),
            getMemberHistory(accessToken),
        ]);

        setProfile({ ...nextProfile, walletBalance: nextLobby.walletBalance, credit: nextLobby.credit });
        setLobby(nextLobby);
        setMachines(nextLobby.machines.map((machine) => ({
            id: machine.id,
            name: machine.name,
            isOpen: machine.isOpen,
            minBet: machine.minBet,
            maxBet: machine.maxBet,
        })));
        setRules(nextRules);
        setHistory(nextHistory);
    }, [accessToken]);

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

    const loadMachineContext = useCallback(async (machineIdToLoad: number) => {
        if (!accessToken) {
            return;
        }

        const [nextMachineState, nextSession, nextActiveRound] = await Promise.all([
            getMachineState(machineIdToLoad, accessToken),
            getMachineSession(machineIdToLoad, accessToken),
            getActiveRound(machineIdToLoad, accessToken),
        ]);

        setMachineState(nextMachineState);
        setMachineSession(nextSession);
        syncWallet(nextSession.walletBalance);
        hydrateActiveRound(nextActiveRound, nextSession, nextMachineState);
    }, [accessToken, profile]);

    async function refreshSelectedSessionSnapshot() {
        if (!accessToken || !machineId) {
            return null;
        }

        const nextSession = await getMachineSession(machineId, accessToken);
        setMachineSession(nextSession);
        syncWallet(nextSession.walletBalance);
        return nextSession;
    }

    const refreshAdminPanel = useCallback(async () => {
        if (!accessToken || !isAdmin) {
            return;
        }

        setAdminDashboard(await getAdminDashboard(accessToken));

        if (adminTab === "overview") {
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

        if (adminTab === "devices") {
            const [nextMachines, nextDevices] = await Promise.all([
                listAdminMachines(accessToken),
                listCabinetDevices(accessToken),
            ]);
            setAdminMachines(nextMachines);
            setCabinetDevices(nextDevices);
            if (!deviceMachineId && nextMachines.length > 0) {
                setDeviceMachineId(String(nextMachines[0].machineId));
            }
            if (!selectedDeviceId && nextDevices.length > 0) {
                setSelectedDeviceId(nextDevices[0].deviceId);
            }
            return;
        }

        if (adminTab === "audit") {
            setAdminAudit(await listAdminAudit(accessToken, 30));
            return;
        }

        setAdminMachines(await listAdminMachines(accessToken));
    }, [accessToken, adminSearchQuery, adminTab, deviceMachineId, isAdmin, selectedAgentId, selectedDeviceId]);

    useEffect(() => {
        const persisted = loadPersistedCabinetStorage();
        if (!persisted) {
            return;
        }

        const persistedToken = persisted.userData?.AccessToken?.trim();
        if (persistedToken) {
            setAccessToken(persistedToken);
        }

        if (persisted.userData?.User) {
            setProfile(persisted.userData.User);
        }

        const nextCabinet = persisted.cabinet;
        if (typeof nextCabinet?.machineId === "number") {
            setMachineId(nextCabinet.machineId);
        }
        if (nextCabinet?.betAmount) {
            setBetAmount(nextCabinet.betAmount);
        }
        if (nextCabinet?.adminTab) {
            setAdminTab(nextCabinet.adminTab);
        }
        if (typeof nextCabinet?.selectedAgentId === "number") {
            setSelectedAgentId(nextCabinet.selectedAgentId);
        }
        if (nextCabinet?.selectedUserId) {
            setSelectedUserId(nextCabinet.selectedUserId);
        }
        if (nextCabinet?.selectedDeviceId) {
            setSelectedDeviceId(nextCabinet.selectedDeviceId);
        }
    }, []);

    useEffect(() => {
        if (!accessToken && !profile && !machineId) {
            clearPersistedCabinetStorage();
            return;
        }

        savePersistedCabinetStorage({
            userData: {
                AccessToken: accessToken ?? undefined,
                User: profile,
            },
            cabinet: {
                machineId,
                betAmount,
                adminTab,
                selectedAgentId,
                selectedUserId,
                selectedDeviceId,
            },
        });
    }, [accessToken, adminTab, betAmount, machineId, profile, selectedAgentId, selectedDeviceId, selectedUserId]);

    useEffect(() => {
        if (!accessToken) {
            return;
        }

        void (async () => {
            try {
                await refreshBootstrap();
            } catch {
                setAccessToken(null);
                setProfile(null);
                setMachineId(null);
                setMachineState(null);
                setMachineSession(null);
                clearActiveRoundState();
                setDoubleUpResult(null);
                clearPersistedCabinetStorage();
                setMessage("Saved session expired. Boot the cabinet again.");
                setMessageTone("warning");
            }
        })();
    }, [accessToken, refreshBootstrap]);

    useEffect(() => {
        if (!accessToken || !machineId) {
            return;
        }

        void loadMachineContext(machineId);
        const timer = window.setInterval(() => {
            void refreshMachineState();
            void refreshMachineSession();
        }, 5000);
        return () => window.clearInterval(timer);
    }, [accessToken, loadMachineContext, machineId, refreshMachineState, refreshMachineSession]);

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
            setMachineId(null);
            setMessage("Cabinet synced. Choose a lobby machine, cash in, then deal.");
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
                await loadMachineContext(machine.id);
                await refreshLobby();
            });
        }
    }

    async function handleCashIn(amount: number) {
        if (!accessToken || !machineId) {
            setMessage("Select a machine before cashing in.");
            setMessageTone("warning");
            return;
        }

        await runAction(async () => {
            const session = await cashInMachine(machineId, amount, accessToken);
            setMachineSession(session);
            syncWallet(session.walletBalance);
            setMessage(`Cashed in ${formatMoney(amount)} to ${selectedMachine?.name ?? "machine"}.`);
            setMessageTone("ready");
            await Promise.all([refreshHistory(), refreshMachineState(), refreshLobby()]);
        });
    }

    async function handleCashOutToWallet() {
        if (!accessToken || !machineId) {
            return;
        }

        await runAction(async () => {
            const session = await cashOutMachine(machineId, accessToken);
            setMachineSession(session);
            syncWallet(session.walletBalance);
            setMessage("Machine credits returned to wallet.");
            setMessageTone("ready");
            await Promise.all([refreshHistory(), refreshMachineState(), refreshLobby()]);
        });
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
                setMessage(
                    result.winAmount > 0
                        ? `${result.handRank} paid ${formatMoney(result.winAmount)}. Take score or press BIG/SMALL.`
                        : `${result.handRank}. Round settled, ready for the next deal.`,
                );
                setMessageTone(result.winAmount > 0 ? "ready" : "warning");
                if (machineId) {
                    const nextSession = await getMachineSession(machineId, accessToken);
                    setMachineSession(nextSession);
                    syncWallet(nextSession.walletBalance);
                }
                await Promise.all([refreshHistory(), refreshMachineState(), refreshLobby()]);
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
            const nextSession = await getMachineSession(machineId, accessToken);
            setMachineSession(nextSession);
            syncWallet(nextSession.walletBalance);
            setMessage("Choose the cards to HOLD, then press DRAW.");
            setMessageTone("ready");
            await Promise.all([refreshHistory(), refreshMachineState(), refreshLobby()]);
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
            await refreshSelectedSessionSnapshot();
            setMessage(`Dealer switched. Status: ${result.status}.`);
            setMessageTone(toneForStatus(result.status));
            await Promise.all([refreshHistory(), refreshMachineState(), refreshLobby()]);
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
                await refreshSelectedSessionSnapshot();
                setMessage(`${guess.toUpperCase()} resolved: ${result.status}. Current amount ${formatMoney(result.currentAmount)}.`);
                setMessageTone(toneForStatus(result.status));
                if (isTerminalDoubleUpStatus(result.status)) {
                    clearActiveRoundState();
                }
                await Promise.all([refreshHistory(), refreshMachineState(), refreshLobby()]);
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
            await refreshSelectedSessionSnapshot();
            setMessage(`${guess.toUpperCase()} resolved: ${result.status}. Current amount ${formatMoney(result.currentAmount)}.`);
            setMessageTone(toneForStatus(result.status));
            if (isTerminalDoubleUpStatus(result.status)) {
                clearActiveRoundState();
            }
            await Promise.all([refreshHistory(), refreshMachineState(), refreshLobby()]);
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
                    void refreshSelectedSessionSnapshot();
                    setMessage(`Score taken: ${formatMoney(result.currentAmount)}.`);
                    setMessageTone("ready");
                    clearActiveRoundState();
                    void Promise.all([refreshHistory(), refreshMachineState(), refreshLobby()]);
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
            await refreshSelectedSessionSnapshot();
            setMessage(`Half banked. ${formatMoney(result.currentAmount)} stays in play.`);
            setMessageTone("warning");
            if (isTerminalDoubleUpStatus(result.status)) {
                clearActiveRoundState();
            }
            await Promise.all([refreshHistory(), refreshMachineState(), refreshLobby()]);
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
            setAdminUserDetail(await getAdminUserDetail(userId, accessToken));
            setMessage(`User assigned to ${selectedAgent?.code ?? "agent"}.`);
            setMessageTone("ready");
        });
    }

    async function handleLoadAdminUserDetail(userId: string) {
        if (!accessToken) {
            return;
        }

        await runAction(async () => {
            setSelectedUserId(userId);
            setAdminUserDetail(await getAdminUserDetail(userId, accessToken));
        });
    }

    async function handleAdjustUserWallet(direction: 1 | -1) {
        if (!accessToken || !selectedUserId) {
            setMessage("Select a user before adjusting wallet credit.");
            setMessageTone("warning");
            return;
        }

        const amount = Number(walletToolAmount);
        if (!Number.isFinite(amount) || amount <= 0) {
            setMessage("Enter a positive wallet amount.");
            setMessageTone("warning");
            return;
        }

        const reason = walletToolReason.trim();
        if (!reason) {
            setMessage("Wallet adjustments require a reason.");
            setMessageTone("warning");
            return;
        }

        await runAction(async () => {
            await adjustAdminUserWallet(selectedUserId, amount * direction, reason, accessToken);
            setAdminUserDetail(await getAdminUserDetail(selectedUserId, accessToken));
            await refreshAdminPanel();
            setMessage(`${direction > 0 ? "Credited" : "Debited"} ${formatMoney(amount)}.`);
            setMessageTone("ready");
        });
    }

    async function handleRechargeBonus() {
        if (!accessToken || !selectedUserId) {
            setMessage("Select a user before applying recharge bonus.");
            setMessageTone("warning");
            return;
        }

        const amount = Number(rechargeAmount);
        if (!Number.isFinite(amount) || amount <= 0) {
            setMessage("Enter a positive recharge amount.");
            setMessageTone("warning");
            return;
        }

        await runAction(async () => {
            await applyRechargeBonus(selectedUserId, amount, accessToken);
            setAdminUserDetail(await getAdminUserDetail(selectedUserId, accessToken));
            await refreshAdminPanel();
            setMessage(`Recharge bonus applied for ${formatMoney(amount)}.`);
            setMessageTone("ready");
        });
    }

    async function handleLoadAdminMachineDetail(machineIdToLoad: number) {
        if (!accessToken) {
            return;
        }

        await runAction(async () => {
            setAdminMachineDetail(await getAdminMachineDetail(machineIdToLoad, accessToken));
        });
    }

    async function handleResetAdminMachine(machineIdToReset: number) {
        if (!accessToken || !window.confirm("Reset this machine ledger and sessions? Active recoverable rounds will block the action.")) {
            return;
        }

        await runAction(async () => {
            await resetAdminMachine(machineIdToReset, accessToken);
            setAdminMachineDetail(await getAdminMachineDetail(machineIdToReset, accessToken));
            await refreshAdminPanel();
            setMessage("Machine reset completed.");
            setMessageTone("ready");
        });
    }

    async function handleSetAdminMachineDoor(machineIdToUpdate: number, doorState: 0 | 1) {
        if (!accessToken) {
            return;
        }

        await runAction(async () => {
            await setAdminMachineDoorState(machineIdToUpdate, doorState, accessToken);
            setAdminMachineDetail(await getAdminMachineDetail(machineIdToUpdate, accessToken));
            await refreshAdminPanel();
            setMessage(`Machine door marked ${doorState === 1 ? "open" : "closed"}.`);
            setMessageTone("ready");
        });
    }

    async function handleProvisionCabinetDevice() {
        if (!accessToken) {
            return;
        }

        const machineIdValue = Number(deviceMachineId);
        const displayName = deviceDisplayName.trim();
        const serialNumber = deviceSerialNumber.trim();

        if (!Number.isInteger(machineIdValue) || machineIdValue <= 0) {
            setMessage("Select a machine before provisioning a cabinet device.");
            setMessageTone("warning");
            return;
        }

        if (!displayName || !serialNumber) {
            setMessage("Device display name and serial number are required.");
            setMessageTone("warning");
            return;
        }

        await runAction(async () => {
            const provisioning = await provisionCabinetDevice({
                machineId: machineIdValue,
                displayName,
                serialNumber,
            }, accessToken);
            setDeviceProvisioning(provisioning);
            setSelectedDeviceId(provisioning.device.deviceId);
            setDeviceDisplayName("");
            setDeviceSerialNumber("");
            await refreshAdminPanel();
            setMessage(`Provisioned cabinet ${provisioning.device.displayName}. Save the one-time secret now.`);
            setMessageTone("ready");
        });
    }

    async function handleRevokeCabinetDevice() {
        if (!accessToken || !selectedDevice) {
            setMessage("Select a cabinet device before revoking it.");
            setMessageTone("warning");
            return;
        }

        const reason = deviceRevokeReason.trim();
        if (!reason) {
            setMessage("Revocation reason is required.");
            setMessageTone("warning");
            return;
        }

        await runAction(async () => {
            await revokeCabinetDevice(selectedDevice.deviceId, reason, accessToken);
            setDeviceProvisioning(null);
            await refreshAdminPanel();
            setMessage(`Revoked cabinet ${selectedDevice.displayName}.`);
            setMessageTone("warning");
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

    useEffect(() => {
        if (dealResult || drawResult || isInDoubleUp) {
            setIdleFhCard(null);
            return;
        }

        const currentRank = jackpotSnapshot?.fullHouseRank ?? 2;
        const suits = ["H", "D", "C", "S"];
        const rankLabel = rankLabelFromValue(currentRank);
        let rotationTimer: number | undefined;

        setIdleFhCard(null);

        const revealTimer = window.setTimeout(() => {
            const setRandomFhCard = () => {
                const suit = suits[Math.floor(Math.random() * suits.length)];
                setIdleFhCard({ rank: rankLabel, suit, code: `${rankLabel}${suit}` });
            };

            setRandomFhCard();
            rotationTimer = window.setInterval(setRandomFhCard, 3000);
        }, IDLE_FH_REVEAL_DELAY_MS);

        return () => {
            window.clearTimeout(revealTimer);
            if (rotationTimer !== undefined) {
                window.clearInterval(rotationTimer);
            }
        };
    }, [dealResult, drawResult, isInDoubleUp, jackpotSnapshot?.fullHouseRank]);

    return (
        <div className="cabinet-shell">
            <section className="cabinet">
                <div className="screen">

                    {/* ── Top band: paytable left, credit-only meter right ── */}
                    <div className="apk-top-band">
                        <PaytablePanel
                            payouts={rules?.payoutMultipliers ?? {}}
                            activeHand={drawResult?.handRank ?? null}
                            jackpotFh={jackpotSnapshot?.fullHouse}
                            stake={betAmount || "5000"}
                            activeWinAmount={displayedWinAmount}
                        />
                        <CreditBar credit={cabinetCredit} />
                    </div>

                    {/* ── Label band ── */}
                    {isInDoubleUp && (
                        <div className="apk-label-band apk-du-label">DOUBLE UP</div>
                    )}

                    {/* ── Card stage ── */}
                    <div className="apk-card-stage">
                        {isInDoubleUp ? (
                            <DoubleUpBoard viewModel={doubleUpViewModel} />
                        ) : !dealResult && !drawResult ? (
                            <div className={`apk-idle-stage${idleFhCard ? " apk-idle-stage--fh" : ""}`}>
                                {idleFhCard ? (
                                    <div className="apk-idle-fh-card">
                                        <PlayingCard card={idleFhCard} label="FULL HOUSE" />
                                    </div>
                                ) : (
                                    <div className="apk-idle-logo">
                                        <span>LUCKY5</span>
                                        <span>POKER</span>
                                    </div>
                                )}
                            </div>
                        ) : (
                            /* Normal 5-card row with hold-click */
                            <div className="apk-card-row">
                                {Array.from({ length: CARD_SLOT_COUNT }, (_, index) => {
                                    const cardToDisplay = visibleCardIndexSet.has(index)
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
                        ) : !machineId ? (
                            <div className="player-lobby-panel">
                                <div className="player-lobby-head">
                                    <div>
                                        <div className="section-title">Lucky5 lobby</div>
                                        <div className="section-subtitle">Choose a cabinet, cash in from wallet, then play.</div>
                                    </div>
                                    <div className="lobby-wallet-chip">
                                        <span>Wallet</span>
                                        <strong>{formatMoney(lobby?.walletBalance ?? profile.walletBalance)}</strong>
                                    </div>
                                </div>
                                <div className="player-lobby-grid">
                                    {lobbyMachineCards.map((machine) => (
                                        <button
                                            key={machine.id}
                                            className={`player-machine-card${machine.activeRound ? " has-round" : ""}`}
                                            type="button"
                                            onClick={() => void handleMachineSelection(machine)}
                                            disabled={!machine.isOpen || busy}
                                        >
                                            <span className="machine-card-top">
                                                <strong>{machine.name}</strong>
                                                <em>{machine.isOpen ? "OPEN" : "CLOSED"}</em>
                                            </span>
                                            <span className="machine-card-meta">
                                                BET {formatMoney(machine.minBet)}-{formatMoney(machine.maxBet)} · {machine.phase}
                                            </span>
                                            <span className="machine-card-meter">
                                                RTP {formatPercent(machine.observedRtp)} · ROUNDS {machine.roundCount}
                                            </span>
                                            <span className="machine-card-jackpots">
                                                FH {machine.jackpots ? formatMoney(machine.jackpots.fullHouse) : "--"} · SF {machine.jackpots ? formatMoney(machine.jackpots.straightFlush) : "--"}
                                            </span>
                                            <span className="machine-card-session">
                                                {machine.session
                                                    ? `CREDITS ${formatMoney(machine.session.machineCredits)} · IN ${formatMoney(machine.session.totalCashIn)}`
                                                    : "NO ACTIVE SESSION"}
                                            </span>
                                            <span className="machine-card-action">
                                                {machine.activeRound ? "RESUME ROUND" : "ENTER CABINET"}
                                            </span>
                                        </button>
                                    ))}
                                </div>
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
                                            HOLD
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
                                        DEAL<br />
                                        DRAW
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
                                        <div className="apk-menu-btn-label" aria-hidden="true">
                                            <span className="apk-menu-icon-line" />
                                            <span className="apk-menu-icon-line" />
                                            <span className="apk-menu-icon-line" />
                                        </div>
                                        <div className="apk-menu-text">MENU</div>
                                        <div className="apk-menu-popup">
                                            <div className="cash-console cash-console-menu">
                                                <div className="cash-console-card">
                                                    <span>Wallet</span>
                                                    <strong>{formatMoney(machineSession?.walletBalance ?? profile.walletBalance)}</strong>
                                                </div>
                                                <div className="cash-console-card">
                                                    <span>Credits</span>
                                                    <strong>{formatMoney(cabinetCredit)}</strong>
                                                </div>
                                                <div className="cash-console-card">
                                                    <span>Stake</span>
                                                    <strong>{formatMoney(Number(betAmount) || 0)}</strong>
                                                </div>
                                                <div className="cash-console-card">
                                                    <span>Cash-in</span>
                                                    <strong>{formatMoney(machineSession?.totalCashIn ?? selectedLobbyMachine?.session?.totalCashIn ?? 0)}</strong>
                                                </div>
                                                <button
                                                    className="cash-console-button"
                                                    type="button"
                                                    onClick={() => void handleCashIn(200000)}
                                                    disabled={busy || isInDoubleUp || (!!dealResult && !drawResult) || hasWin || !!doubleUpResult}
                                                >
                                                    CASH IN 200K
                                                </button>
                                                <button
                                                    className="cash-console-button"
                                                    type="button"
                                                    onClick={() => void handleCashIn(1000000)}
                                                    disabled={busy || isInDoubleUp || (!!dealResult && !drawResult) || hasWin || !!doubleUpResult}
                                                >
                                                    CASH IN 1M
                                                </button>
                                                <button
                                                    className="cash-console-button cash-console-out"
                                                    type="button"
                                                    onClick={() => void handleCashOutToWallet()}
                                                    disabled={busy || isInDoubleUp || (!!dealResult && !drawResult) || hasWin || !!doubleUpResult || !(machineSession?.canCashOut ?? false)}
                                                >
                                                    CASH OUT
                                                </button>
                                            </div>
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
                                                    setMachineState(null);
                                                    setMachineSession(null);
                                                    setDealResult(null);
                                                    setDrawResult(null);
                                                    setDoubleUpResult(null);
                                                    setMessage("Returned to lobby. Pick a machine.");
                                                    setMessageTone("ready");
                                                    void refreshLobby();
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

            {/* ── Side column: admin-only telemetry ── */}
            {isAdmin && (
            <aside className="side-column">
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
                            {(["overview", "agents", "users", "machines", "devices", "audit"] as AdminPanelTab[]).map((tab) => (
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

                        {adminTab === "overview" && (
                            <div className="admin-stack">
                                <div className="admin-metric-grid">
                                    <div className="admin-metric-card">
                                        <span>Players</span>
                                        <strong>{adminDashboard?.playerCount ?? 0}</strong>
                                    </div>
                                    <div className="admin-metric-card">
                                        <span>Wallet bank</span>
                                        <strong>{formatMoney(adminDashboard?.totalWalletBalance ?? 0)}</strong>
                                    </div>
                                    <div className="admin-metric-card">
                                        <span>Machine credits</span>
                                        <strong>{formatMoney(adminDashboard?.totalMachineCredits ?? 0)}</strong>
                                    </div>
                                    <div className="admin-metric-card">
                                        <span>Open machines</span>
                                        <strong>{adminDashboard?.openMachineCount ?? 0}/{adminDashboard?.machineCount ?? 0}</strong>
                                    </div>
                                    <div className="admin-metric-card">
                                        <span>Active sessions</span>
                                        <strong>{adminDashboard?.activeMachineSessions ?? 0}</strong>
                                    </div>
                                    <div className="admin-metric-card warning">
                                        <span>Recoverable rounds</span>
                                        <strong>{adminDashboard?.recoverableRounds ?? 0}</strong>
                                    </div>
                                    <div className="admin-metric-card">
                                        <span>Cabinet devices</span>
                                        <strong>{adminDashboard?.activeCabinetDeviceSessions ?? 0}/{adminDashboard?.cabinetDeviceCount ?? 0}</strong>
                                    </div>
                                    <div className="admin-metric-card">
                                        <span>Floor RTP</span>
                                        <strong>{formatPercent(adminDashboard?.observedRtp ?? 0)}</strong>
                                    </div>
                                </div>
                            </div>
                        )}

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
                                                onClick={() => void handleLoadAdminUserDetail(user.userId)}
                                                disabled={busy}
                                            >
                                                DETAILS
                                            </button>
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
                                {adminUserDetail && (
                                    <div className="admin-detail-card">
                                        <div className="admin-detail-head">
                                            <strong>{adminUserDetail.user.username}</strong>
                                            <span>{adminUserDetail.generatedId || "no generated id"}</span>
                                        </div>
                                        <div className="admin-detail-grid">
                                            <span>Wallet {formatMoney(adminUserDetail.user.walletBalance)}</span>
                                            <span>Credit {formatMoney(adminUserDetail.credit)}</span>
                                            <span>Agent {adminUserDetail.agentId ?? "none"}</span>
                                            <span>Wins {adminUserDetail.totalWins}</span>
                                            <span>Sessions {adminUserDetail.sessions.length}</span>
                                            <span>Rounds {adminUserDetail.activeRounds.length}</span>
                                        </div>
                                        <div className="admin-tool-grid">
                                            <input
                                                aria-label="Wallet tool amount"
                                                inputMode="numeric"
                                                value={walletToolAmount}
                                                onChange={(event) => setWalletToolAmount(event.target.value)}
                                            />
                                            <input
                                                aria-label="Wallet adjustment reason"
                                                value={walletToolReason}
                                                onChange={(event) => setWalletToolReason(event.target.value)}
                                            />
                                            <button className="admin-mini-button" type="button" onClick={() => void handleAdjustUserWallet(1)} disabled={busy}>
                                                CREDIT
                                            </button>
                                            <button className="admin-mini-button" type="button" onClick={() => void handleAdjustUserWallet(-1)} disabled={busy}>
                                                DEBIT
                                            </button>
                                        </div>
                                        <div className="admin-tool-grid admin-tool-grid-compact">
                                            <input
                                                aria-label="Recharge amount"
                                                inputMode="numeric"
                                                value={rechargeAmount}
                                                onChange={(event) => setRechargeAmount(event.target.value)}
                                            />
                                            <button className="admin-mini-button" type="button" onClick={() => void handleRechargeBonus()} disabled={busy}>
                                                RECHARGE BONUS
                                            </button>
                                        </div>
                                        <div className="admin-mini-list">
                                            {adminUserDetail.activeRounds.length === 0 && <span>No recoverable rounds.</span>}
                                            {adminUserDetail.activeRounds.slice(0, 3).map((round) => (
                                                <span key={round.roundId}>{round.machineName} · {round.phase} · {formatMoney(round.betAmount)}</span>
                                            ))}
                                        </div>
                                    </div>
                                )}
                            </div>
                        )}

                        {adminTab === "machines" && (
                            <div className="admin-stack">
                                <div className="admin-list">
                                    {adminMachines.length === 0 && <div className="hint">No machines loaded.</div>}
                                    {adminMachines.slice(0, 6).map((machine) => (
                                        <button
                                            className={`admin-list-row admin-machine-row admin-list-row-button${adminMachineDetail?.machine.machineId === machine.machineId ? " active" : ""}`}
                                            key={machine.machineId}
                                            type="button"
                                            onClick={() => void handleLoadAdminMachineDetail(machine.machineId)}
                                            disabled={busy}
                                        >
                                            <span>
                                                <strong>{machine.name}</strong>
                                                <small>
                                                    {machine.phase} · {machine.activePlayers} players · {machine.activeRounds} rounds
                                                </small>
                                            </span>
                                            <em>{formatPercent(machine.observedRtp)}</em>
                                            <small>{machine.isOpen ? "OPEN" : "CLOSED"}</small>
                                        </button>
                                    ))}
                                </div>
                                {adminMachineDetail && (
                                    <div className="admin-detail-card">
                                        <div className="admin-detail-head">
                                            <strong>{adminMachineDetail.machine.name}</strong>
                                            <span>{adminMachineDetail.doorState} · {adminMachineDetail.ready ? "READY" : "NOT READY"}</span>
                                        </div>
                                        <div className="admin-detail-grid">
                                            <span>In {formatMoney(adminMachineDetail.capitalIn)}</span>
                                            <span>Out {formatMoney(adminMachineDetail.capitalOut)}</span>
                                            <span>Base {formatMoney(adminMachineDetail.baseCapitalOut)}</span>
                                            <span>Jackpot {formatMoney(adminMachineDetail.jackpotCapitalOut)}</span>
                                            <span>Double {formatMoney(adminMachineDetail.doubleUpCapitalOut)}</span>
                                            <span>Profit {formatMoney(adminMachineDetail.profit)}</span>
                                        </div>
                                        <div className="admin-tool-grid admin-tool-grid-compact">
                                            <button
                                                className="admin-mini-button"
                                                type="button"
                                                onClick={() => void handleSetAdminMachineDoor(adminMachineDetail.machine.machineId, 1)}
                                                disabled={busy}
                                            >
                                                DOOR OPEN
                                            </button>
                                            <button
                                                className="admin-mini-button"
                                                type="button"
                                                onClick={() => void handleSetAdminMachineDoor(adminMachineDetail.machine.machineId, 0)}
                                                disabled={busy}
                                            >
                                                DOOR CLOSED
                                            </button>
                                            <button
                                                className="admin-mini-button danger"
                                                type="button"
                                                onClick={() => void handleResetAdminMachine(adminMachineDetail.machine.machineId)}
                                                disabled={busy || adminMachineDetail.activeRounds.length > 0}
                                            >
                                                RESET
                                            </button>
                                        </div>
                                        <div className="admin-mini-list">
                                            <strong>Active rounds</strong>
                                            {adminMachineDetail.activeRounds.length === 0 && <span>No recoverable rounds.</span>}
                                            {adminMachineDetail.activeRounds.slice(0, 3).map((round) => (
                                                <span key={round.roundId}>{round.username} · {round.phase} · {formatMoney(round.winAmount || round.betAmount)}</span>
                                            ))}
                                        </div>
                                        <div className="admin-mini-list">
                                            <strong>Cabinet devices</strong>
                                            {adminMachineDetail.cabinetDevices.length === 0 && <span>No provisioned devices.</span>}
                                            {adminMachineDetail.cabinetDevices.slice(0, 3).map((device) => (
                                                <span key={device.deviceId}>{device.displayName} · {device.activeSessionCount} sessions · {device.isRevoked ? "revoked" : "active"}</span>
                                            ))}
                                        </div>
                                    </div>
                                )}
                            </div>
                        )}

                        {adminTab === "devices" && (
                            <div className="admin-stack">
                                <div className="admin-form-grid">
                                    <select
                                        aria-label="Provision machine"
                                        value={deviceMachineId}
                                        onChange={(event) => setDeviceMachineId(event.target.value)}
                                    >
                                        <option value="">SELECT MACHINE</option>
                                        {adminMachines.map((machine) => (
                                            <option key={machine.machineId} value={machine.machineId}>
                                                {machine.name}
                                            </option>
                                        ))}
                                    </select>
                                    <input
                                        aria-label="Cabinet display name"
                                        placeholder="DISPLAY NAME"
                                        value={deviceDisplayName}
                                        onChange={(event) => setDeviceDisplayName(event.target.value)}
                                    />
                                    <input
                                        aria-label="Cabinet serial number"
                                        placeholder="SERIAL NUMBER"
                                        value={deviceSerialNumber}
                                        onChange={(event) => setDeviceSerialNumber(event.target.value)}
                                    />
                                </div>
                                <button
                                    className="admin-command"
                                    type="button"
                                    onClick={() => void handleProvisionCabinetDevice()}
                                    disabled={busy}
                                >
                                    PROVISION CABINET
                                </button>
                                {deviceProvisioning && (
                                    <div className="admin-detail-card">
                                        <div className="admin-detail-head">
                                            <strong>{deviceProvisioning.device.displayName}</strong>
                                            <span>One-time secret</span>
                                        </div>
                                        <div className="admin-tool-grid admin-tool-grid-secret">
                                            <input readOnly value={deviceProvisioning.deviceSecret} aria-label="Provisioned device secret" />
                                        </div>
                                        <div className="admin-mini-list">
                                            <span>{deviceProvisioning.device.machineName} · {deviceProvisioning.device.serialNumber}</span>
                                        </div>
                                    </div>
                                )}
                                <div className="admin-list">
                                    {cabinetDevices.length === 0 && <div className="hint">No cabinet devices loaded.</div>}
                                    {cabinetDevices.map((device) => (
                                        <button
                                            key={device.deviceId}
                                            className={`admin-list-row admin-list-row-button${selectedDeviceId === device.deviceId ? " active" : ""}`}
                                            type="button"
                                            onClick={() => setSelectedDeviceId(device.deviceId)}
                                        >
                                            <span>
                                                <strong>{device.displayName}</strong>
                                                <small>{device.machineName} · {device.serialNumber}</small>
                                            </span>
                                            <em>{device.isRevoked ? "REVOKED" : `${device.activeSessionCount} LIVE`}</em>
                                        </button>
                                    ))}
                                </div>
                                {selectedDevice && (
                                    <div className="admin-detail-card">
                                        <div className="admin-detail-head">
                                            <strong>{selectedDevice.displayName}</strong>
                                            <span>{selectedDevice.machineName} · {selectedDevice.serialNumber}</span>
                                        </div>
                                        <div className="admin-detail-grid">
                                            <span>Fingerprint {selectedDevice.secretFingerprint}</span>
                                            <span>Firmware {selectedDevice.lastFirmwareVersion || "—"}</span>
                                            <span>Client {selectedDevice.lastClientVersion || "—"}</span>
                                            <span>Created {formatDateTime(selectedDevice.createdUtc)}</span>
                                            <span>Last auth {formatDateTime(selectedDevice.lastAuthenticatedUtc)}</span>
                                            <span>Last seen {formatDateTime(selectedDevice.lastSeenUtc)}</span>
                                        </div>
                                        <div className="admin-tool-grid admin-tool-grid-compact">
                                            <input
                                                aria-label="Revocation reason"
                                                value={deviceRevokeReason}
                                                onChange={(event) => setDeviceRevokeReason(event.target.value)}
                                            />
                                            <button
                                                className="admin-mini-button danger"
                                                type="button"
                                                onClick={() => void handleRevokeCabinetDevice()}
                                                disabled={busy || selectedDevice.isRevoked}
                                            >
                                                {selectedDevice.isRevoked ? "REVOKED" : "REVOKE DEVICE"}
                                            </button>
                                        </div>
                                    </div>
                                )}
                            </div>
                        )}

                        {adminTab === "audit" && (
                            <div className="admin-stack">
                                <div className="admin-list admin-audit-list">
                                    {adminAudit.length === 0 && <div className="hint">No audit records loaded.</div>}
                                    {adminAudit.map((entry) => (
                                        <div key={entry.id} className="admin-list-row admin-audit-row">
                                            <span>
                                                <strong>{entry.action}</strong>
                                                <small>{entry.actorRole} · {entry.targetType} · {entry.targetId}</small>
                                            </span>
                                            <em>{entry.outcome}</em>
                                            <small>{formatDateTime(entry.createdUtc)}</small>
                                            {entry.reason && <small>{entry.reason}</small>}
                                            {Object.keys(entry.metadata ?? {}).length > 0 && (
                                                <div className="admin-audit-meta">
                                                    {Object.entries(entry.metadata).map(([key, value]) => (
                                                        <span key={`${entry.id}-${key}`}>{key}: {value}</span>
                                                    ))}
                                                </div>
                                            )}
                                        </div>
                                    ))}
                                </div>
                            </div>
                        )}
                    </section>
            </aside>
            )}
        </div>
    );
}
