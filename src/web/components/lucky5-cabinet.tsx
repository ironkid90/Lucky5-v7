"use client";

import { useCallback, startTransition, useEffect, useState } from "react";

import {
    cashoutDoubleUp,
    deal,
    draw,
    getDefaultRules,
    getMachineSession,
    getMachineState,
    getMemberHistory,
    getProfile,
    guessDoubleUp,
    listMachines,
    login,
    signup,
    startDoubleUp,
    switchDealer,
    switchFhRank,
    takeHalf,
    verifyOtp,
} from "@/lib/api";
import type {
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
} from "@/models/DoubleUpViewModel";

const DEFAULT_USERNAME = "tester";
const DEFAULT_PASSWORD = "password";
const DEFAULT_OTP = "123456";

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

function formatMoney(value: number) {
    return new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 }).format(value);
}

function formatPercent(value: number) {
    return `${(value * 100).toFixed(1)}%`;
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

// Card image path - placeholder for custom design
function cardImgSrc(card: PokerCard): string {
    // Return empty placeholder until custom card design is ready
    return "";
}

function PlayingCard({ card, label, held, onClick }: {
    card?: PokerCard | null;
    label?: string;
    held?: boolean;
    onClick?: () => void;
}) {
    return (
        <div
            className={`playing-card-apk${held ? " held" : ""}${onClick ? " clickable" : ""}`}
            onClick={onClick}
            role={onClick ? "button" : undefined}
            tabIndex={onClick ? 0 : undefined}
            onKeyDown={onClick ? (e) => e.key === "Enter" && onClick() : undefined}
        >
            {held && <div className="hold-badge-apk">HOLD</div>}
            {card
                ? <img src={cardImgSrc(card)} alt={`${card.rank}${card.suit}`} className="card-img" />
                : <div className="card-back-apk" />
            }
            {label && <div className="card-label-apk">{label}</div>}
        </div>
    );
}

// ── PaytablePanel ────────────────────────────────────────────────────────────
function PaytablePanel({
    payouts,
    activeHand,
    jackpotFh,
}: {
    payouts: Record<string, number>;
    activeHand?: string | null;
    jackpotFh?: number;
}) {
    return (
        <div className="apk-paytable">
            {PAYTABLE_ROWS.map(({ key, label, color }) => {
                const multiplier = payouts[key];
                const display = key === "FullHouse" && jackpotFh
                    ? formatMoney(jackpotFh)
                    : multiplier !== undefined
                        ? String(multiplier * 5000)
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
}: {
    machineName?: string | null;
    jackpots?: MachineState["jackpots"] | null;
    fourOfAKindA: number;
    fourOfAKindB: number;
    bonusText?: string | null;
    machineSerial?: string | null;
    kentStreak?: number | null;
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
                <span className="apk-jp-fh-label">K</span>
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

    const MACHINE_CREDIT_LIMIT = 40000000;

    const selectedMachine = machines.find((machine) => machine.id === machineId) ?? null;
    const activeCards = drawResult?.cards ?? dealResult?.cards ?? [];
    const openRoundId = dealResult?.roundId ?? null;
    const hasWin = (drawResult?.winAmount ?? 0) > 0;
    const doubleUpViewModel = mapDoubleUpResultToViewModel(doubleUpResult);
    const doubleUpAmount = doubleUpViewModel?.currentAmount ?? drawResult?.winAmount ?? 0;

    function clearActiveRoundState() {
        setDealResult(null);
        setDrawResult(null);
        setHoldIndexes([]);
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
                await signup(username, password, "+96101000000");
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
        if (!accessToken || !machineId) {
            setMessage("Boot the cabinet and select a machine first.");
            setMessageTone("warning");
            return;
        }

        if (dealResult && !drawResult) {
            await runAction(async () => {
                const result = await draw(
                    dealResult.roundId,
                    [...holdIndexes].sort((a, b) => a - b),
                    accessToken,
                );
                setDrawResult(result);
                setDoubleUpResult(null);
                syncWallet(result.walletBalanceAfterRound);
                setMessage(
                    result.winAmount > 0
                        ? `${result.handRank} paid ${formatMoney(result.winAmount)}. Take score or enter DOUBLE-UP.`
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
            syncWallet(result.walletBalanceAfterBet);
            setMessage("Choose the cards to HOLD, then press DRAW.");
            setMessageTone("ready");
            await Promise.all([refreshHistory(), refreshMachineState()]);
        });
    }

    async function handleStartDoubleUp() {
        if (!accessToken || !drawResult || !hasWin) {
            return;
        }

        await runAction(async () => {
            const result = await startDoubleUp(drawResult.roundId, accessToken);
            setDoubleUpResult(result);
            setMessage(`DOUBLE-UP armed. Dealer shows ${result.dealerCard?.code ?? "--"}. Big or small?`);
            setMessageTone(toneForStatus(result.status));
        });
    }

    async function handleSwitch() {
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

    async function handleGuess(guess: "big" | "small") {
        if (!accessToken || !openRoundId) {
            return;
        }

        await runAction(async () => {
            const result = await guessDoubleUp(openRoundId, guess, accessToken);
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

    function toggleHold(index: number) {
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

    const isInDoubleUp = doubleUpViewModel !== null && !doubleUpViewModel.isTerminal;
    const bonusText = drawResult?.handRank
        ? `${drawResult.handRank.toUpperCase().replace(/([A-Z])/g, " $1").trim()} WINS BONUS`
        : null;

    // Rotating idle FH face-up card in slot 2 (index 1) when not in a round
    useEffect(() => {
        if (dealResult || drawResult || isInDoubleUp) {
            setIdleFhCard(null);
            return;
        }

        // Generate a random FH card based on current jackpot rank
        const currentRank = jackpotSnapshot?.fullHouseRank ?? 2;
        const suits = ["H", "D", "C", "S"];
        const randomSuit = suits[Math.floor(Math.random() * suits.length)];
        const rankLabel = currentRank === 11 ? "J" : currentRank === 12 ? "Q" : currentRank === 13 ? "K" : currentRank === 14 ? "A" : String(currentRank);

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
                            /* Double-up view: dealer card left + challenger card right */
                            <div className="apk-du-card-row">
                                <PlayingCard card={doubleUpViewModel?.dealerCard ?? null} label={doubleUpViewModel?.isLucky5Active ? "LUCKY 5!" : "DEALER"} />
                                <PlayingCard card={doubleUpViewModel?.challengerCard ?? null} label="BIG / SMALL ?" />
                            </div>
                        ) : (
                            /* Normal 5-card row with hold-click */
                            <div className="apk-card-row">
                                {Array.from({ length: 5 }, (_, index) => {
                                    // Idle FH face-up card in slot 2 (index 1) when not in a round
                                    const isIdleSlot = index === 1 && !dealResult && !drawResult && !isInDoubleUp;
                                    const cardToDisplay = isIdleSlot ? idleFhCard : (activeCards[index] ?? null);
                                    return (
                                        <PlayingCard
                                            key={`card-${index}`}
                                            card={cardToDisplay}
                                            held={holdIndexes.includes(index)}
                                            onClick={() => toggleHold(index)}
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
                    />

                    {/* ── Control deck ── */}
                    <div className="apk-control-deck">
                        {!profile ? (
                            /* Auth panel when not logged in */
                            <div className="auth-panel">
                                <div className="section-title">Boot the cabinet</div>
                                <div className="auth-hint">
                                    Sign up if needed, verify OTP 123456, then log in.
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
                                    {Array.from({ length: 5 }, (_, index) => (
                                        <button
                                            key={index}
                                            className={`apk-hold-btn${holdIndexes.includes(index) ? " active" : ""}`}
                                            type="button"
                                            onClick={() => toggleHold(index)}
                                            disabled={!dealResult || !!drawResult || busy || isInDoubleUp}
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
                                        disabled={busy || !doubleUpViewModel?.canGuess}
                                    >
                                        BIG
                                    </button>
                                    <button
                                        className="apk-btn apk-btn-small"
                                        type="button"
                                        onClick={() => void handleGuess("small")}
                                        disabled={busy || !doubleUpViewModel?.canGuess}
                                    >
                                        SMALL
                                    </button>
                                    <button
                                        className="apk-btn apk-btn-cancel"
                                        type="button"
                                        onClick={() => {
                                            setHoldIndexes([]);
                                        }}
                                        disabled={busy || !dealResult || !!drawResult || isInDoubleUp}
                                    >
                                        CANCEL<br />HOLD
                                    </button>
                                    <button
                                        className="apk-btn apk-btn-deal"
                                        type="button"
                                        onClick={() => void handleDealOrDraw()}
                                        disabled={busy || !machineId || isInDoubleUp}
                                    >
                                        {busy ? "WAIT" : dealResult && !drawResult ? "DRAW" : "DEAL"}<br />
                                        {dealResult && !drawResult ? "" : "DRAW"}
                                    </button>
                                    <button
                                        className="apk-btn apk-btn-bet"
                                        type="button"
                                        onClick={() => {
                                            setHasPressedBetThisSession(true);
                                            const next = selectedMachine
                                                ? Math.min(Number(betAmount) + (selectedMachine.minBet), selectedMachine.maxBet)
                                                : Number(betAmount);
                                            setBetAmount(String(next));
                                        }}
                                        disabled={busy || !!dealResult || isInDoubleUp}
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
                                        disabled={busy || !openRoundId || (!hasWin && !doubleUpResult)}
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
                                        disabled={busy || !openRoundId || (!hasWin && !doubleUpResult)}
                                    >
                                        TAKE<br />SCORE
                                    </button>
                                </div>

                                {/* SWITCH + DOUBLE-UP entry — shown below bottom row when applicable */}
                                {(hasWin || isInDoubleUp) && (
                                    <div className="apk-du-action-row">
                                        <button
                                            className="apk-btn apk-btn-switch"
                                            type="button"
                                            onClick={() => void handleSwitch()}
                                            disabled={busy || !doubleUpViewModel?.canSwitch}
                                        >
                                            SWITCH<br />DEALER
                                        </button>
                                        <button
                                            className="apk-btn apk-btn-double-up"
                                            type="button"
                                            onClick={() => void handleStartDoubleUp()}
                                            disabled={busy || !hasWin || isInDoubleUp}
                                        >
                                            DOUBLE<br />UP
                                        </button>
                                        <div className="apk-du-info">
                                            <div className="apk-du-status">{doubleUpViewModel?.status ?? "—"}</div>
                                            <div className="apk-du-amount">
                                                {formatMoney(doubleUpAmount)}
                                            </div>
                                            {(doubleUpViewModel?.switchesRemaining ?? 0) > 0 && (
                                                <div className="apk-du-switches">
                                                    SW: {doubleUpViewModel!.switchesRemaining}
                                                </div>
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
                                const rankLabel = rank === 11 ? "J" : rank === 12 ? "Q" : rank === 13 ? "K" : rank === 14 ? "A" : String(rank);
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
