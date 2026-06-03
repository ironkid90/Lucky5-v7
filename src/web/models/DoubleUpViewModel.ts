import type { DoubleUpResult, PokerCard } from "@/lib/types";

export type DoubleUpPhase = "idle" | "active" | "resolved";

const TERMINAL_STATUSES = new Set(["Cashout", "Lose", "SafeFail", "MachineClosed"]);

export interface DoubleUpViewModel {
  roundId: string;
  phase: DoubleUpPhase;
  status: string;
  currentAmount: number;
  walletBalance: number;
  dealerCard: PokerCard | null;
  challengerCard: PokerCard | null;
  cardTrail: PokerCard[];
  switchesRemaining: number;
  isNoLoseActive: boolean;
  isLucky5Active: boolean;
  luckyMultiplier: number;
  suspenseMs: number;
  revealMs: number;
  flipFrames: number;
  pulseFrames: number;
  isTerminal: boolean;
  canGuess: boolean;
  canSwitch: boolean;
}

export function isTerminalDoubleUpStatus(status: string): boolean {
  return TERMINAL_STATUSES.has(status);
}

export function mapDoubleUpResultToViewModel(result: DoubleUpResult | null): DoubleUpViewModel | null {
  if (!result) {
    return null;
  }

  const isTerminal = isTerminalDoubleUpStatus(result.status);

  return {
    roundId: result.roundId,
    phase: isTerminal ? "resolved" : "active",
    status: result.status,
    currentAmount: result.currentAmount,
    walletBalance: result.walletBalance,
    dealerCard: result.dealerCard ?? null,
    challengerCard: result.challengerCard ?? null,
    cardTrail: result.cardTrail ?? [],
    switchesRemaining: result.switchesRemaining,
    isNoLoseActive: result.isNoLoseActive,
    isLucky5Active: result.isLucky5Active ?? false,
    luckyMultiplier: result.luckyMultiplier,
    suspenseMs: result.noise?.suspenseMs ?? 0,
    revealMs: result.noise?.revealMs ?? 0,
    flipFrames: result.noise?.flipFrames ?? 0,
    pulseFrames: result.noise?.pulseFrames ?? 0,
    isTerminal,
    canGuess: !isTerminal,
    canSwitch: !isTerminal && result.switchesRemaining > 0,
  };
}
