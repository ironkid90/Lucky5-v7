export interface PokerCard {
  rank: string;
  suit: string;
  code: string;
}

export interface JackpotInfo {
  fullHouse: number;
  fullHouseRank: number;
  fourOfAKindA: number;
  fourOfAKindB: number;
  activeFourOfAKindSlot: number;
  straightFlush: number;
  // Cabinet-banner identity strings populated by JackpotInfoDto.
  // Optional on the wire (older builds may omit them).
  machineSerial?: string | null;
  machineSerie?: string | null;
  machineKent?: string | null;
  // Live KENT counter (0..3). Optional until the Kent detection
  // backend lands; cabinet falls back to 0 when missing.
  kentStreak?: number | null;
}

export interface MachineSession {
  sessionId: string;
  machineId: number;
  machineCredits: number;
  totalCashIn: number;
  cashOutThreshold: number;
  canCashOut: boolean;
  isMachineClosed: boolean;
  walletBalance: number;
}

export interface DealResult {
  roundId: string;
  cards: PokerCard[];
  betAmount: number;
  walletBalanceAfterBet: number;
  jackpots?: JackpotInfo | null;
  advisedHolds?: number[] | null;
}

export interface DrawResult {
  roundId: string;
  cards: PokerCard[];
  handRank: string;
  winAmount: number;
  walletBalanceAfterRound: number;
  jackpotWon: number;
  jackpots?: JackpotInfo | null;
  doubleUpAvailable: boolean;
}

export interface PresentationNoise {
  suspenseMs: number;
  revealMs: number;
  flipFrames: number;
  pulseFrames: number;
}

export interface DoubleUpResult {
  roundId: string;
  status: string;
  currentAmount: number;
  walletBalance: number;
  dealerCard?: PokerCard | null;
  challengerCard?: PokerCard | null;
  cardTrail?: PokerCard[] | null;
  switchesRemaining: number;
  isNoLoseActive: boolean;
  isLucky5Active?: boolean;
  luckyMultiplier: number;
  noise?: PresentationNoise | null;
}

export interface MachineListing {
  id: number;
  name: string;
  isOpen: boolean;
  minBet: number;
  maxBet: number;
}

export interface MachineState {
  phase: string;
  observedRtp: number;
  targetRtp: number;
  activeRounds: number;
  consecutiveLosses: number;
  cooldownRemaining: number;
  jackpots: JackpotInfo;
}

export interface MemberProfile {
  userId: string;
  username: string;
  displayName: string;
  email: string;
  phoneNumber: string;
  walletBalance: number;
  lastSeenUtc: string;
  role: string;
}

export interface WalletLedgerEntry {
  id: string;
  amount: number;
  balanceAfter: number;
  type: string;
  reference: string;
  createdUtc: string;
}

export interface DefaultRules {
  payoutMultipliers: Record<string, number>;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken?: string;
}

export interface LoginResult {
  tokens: AuthTokens;
  profile: MemberProfile;
}
