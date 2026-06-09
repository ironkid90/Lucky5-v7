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

export interface ActiveRoundState {
  roundId: string;
  machineId: number;
  betAmount: number;
  phase: string;
  handRank: string;
  pendingWinAmount: number;
  doubleUpAvailable: boolean;
}

export interface PlayerLobbyMachine {
  id: number;
  name: string;
  isOpen: boolean;
  minBet: number;
  maxBet: number;
  jackpots: JackpotInfo;
  observedRtp: number;
  phase: string;
  roundCount: number;
  session?: MachineSession | null;
  activeRound?: ActiveRoundState | null;
}

export interface PlayerLobby {
  userId: string;
  username: string;
  walletBalance: number;
  credit: number;
  machines: PlayerLobbyMachine[];
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

export interface ActiveRoundDoubleUpState {
  dealerCard: PokerCard;
  currentAmount: number;
  switchesRemaining: number;
  isNoLoseActive: boolean;
  luckyMultiplier: number;
  currentRoundIndex: number;
  cardTrail?: PokerCard[] | null;
  isLucky5Active: boolean;
}

export interface ActiveRoundState {
  roundId: string;
  machineId: number;
  betAmount: number;
  phase: string;
  handRank: string;
  cards: PokerCard[];
  resultCards: PokerCard[];
  heldIndexes: number[];
  pendingWinAmount: number;
  doubleUpAvailable: boolean;
  takeHalfUsed: boolean;
  doubleUpSession?: ActiveRoundDoubleUpState | null;
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
  credit?: number;
  agentId?: number | null;
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

export interface AdminUser {
  userId: string;
  username: string;
  displayName: string;
  phoneNumber: string;
  walletBalance: number;
  role: string;
  createdUtc: string;
  lastSeenUtc: string;
}

export interface AdminMachineSession {
  sessionId: string;
  userId: string;
  username: string;
  machineCredits: number;
  totalCashIn: number;
  isMachineClosed: boolean;
  counterplayScore: number;
  lastUpdatedUtc: string;
}

export interface AdminMachine {
  machineId: number;
  name: string;
  isOpen: boolean;
  minBet: number;
  maxBet: number;
  observedRtp: number;
  targetRtp: number;
  baseRtp: number;
  phase: string;
  lastPayoutScale: number;
  roundCount: number;
  consecutiveLosses: number;
  roundsSinceMediumWin: number;
  cooldownRemaining: number;
  netSinceLastClose: number;
  roundsSinceLucky5Hit: number;
  lastRoundUtc: string;
  jackpotFullHouse: number;
  jackpotFullHouseRank: number;
  jackpotFourOfAKindA: number;
  jackpotFourOfAKindB: number;
  activeFourOfAKindSlot: number;
  jackpotStraightFlush: number;
  jackpotKent: number;
  activeRounds: number;
  activePlayers: number;
  sessions: AdminMachineSession[];
}

export interface AdminDashboard {
  userCount: number;
  playerCount: number;
  adminCount: number;
  totalWalletBalance: number;
  totalMachineCredits: number;
  machineCount: number;
  openMachineCount: number;
  closedMachineCount: number;
  activeMachineSessions: number;
  recoverableRounds: number;
  cabinetDeviceCount: number;
  activeCabinetDeviceSessions: number;
  revokedCabinetDeviceCount: number;
  totalCapitalIn: number;
  totalCapitalOut: number;
  observedRtp: number;
}

export interface AdminActiveRound {
  roundId: string;
  userId: string;
  username: string;
  machineId: number;
  machineName: string;
  betAmount: number;
  phase: string;
  handRank: string;
  winAmount: number;
  isCompleted: boolean;
  isPayoutSettled: boolean;
  enteredDoubleUp: boolean;
  createdUtc: string;
  ageSeconds: number;
}

export interface AdminUserSession {
  sessionId: string;
  machineId: number;
  machineName: string;
  machineCredits: number;
  totalCashIn: number;
  isMachineClosed: boolean;
  counterplayScore: number;
  createdUtc: string;
  lastUpdatedUtc: string;
}

export interface AdminUserDetail {
  user: AdminUser;
  email: string;
  fullName: string;
  credit: number;
  agentId?: number | null;
  generatedId: string;
  minimumOut: number;
  bonusDate?: string | null;
  bonusRechargeCount: number;
  sessionNetLoss: number;
  totalWins: number;
  recentLedger: WalletLedgerEntry[];
  sessions: AdminUserSession[];
  activeRounds: AdminActiveRound[];
}

export interface CabinetDevice {
  deviceId: string;
  machineId: number;
  machineName: string;
  displayName: string;
  serialNumber: string;
  secretFingerprint: string;
  createdUtc: string;
  createdByAdminId: string;
  lastAuthenticatedUtc?: string | null;
  lastSeenUtc?: string | null;
  lastFirmwareVersion: string;
  lastClientVersion: string;
  isRevoked: boolean;
  revokedUtc?: string | null;
  revokedByAdminId?: string | null;
  revocationReason: string;
  activeSessionCount: number;
}

export interface CabinetDeviceProvisioning {
  device: CabinetDevice;
  deviceSecret: string;
}

export interface AdminAuditEntry {
  id: string;
  sequenceNumber: number;
  createdUtc: string;
  actorUserId: string;
  actorRole: string;
  action: string;
  targetType: string;
  targetId: string;
  machineId?: number | null;
  cabinetDeviceId?: string | null;
  outcome: string;
  reason: string;
  metadata: Record<string, string>;
}

export interface AdminMachineDetail {
  machine: AdminMachine;
  doorState: string;
  active: boolean;
  ready: boolean;
  capitalIn: number;
  capitalOut: number;
  baseCapitalOut: number;
  jackpotCapitalOut: number;
  doubleUpCapitalOut: number;
  machineAmount: number;
  currentUserAmount: number;
  openAmount: number;
  profit: number;
  activeRounds: AdminActiveRound[];
  cabinetDevices: CabinetDevice[];
}

export interface AgentInfo {
  id: number;
  name: string;
  code: string;
  phoneNumber: string;
  isActive: boolean;
  creditPool: number;
  createdUtc: string;
}

export interface DefaultRules {
  payoutMultipliers: Record<string, number>;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken?: string;
}

export interface OtpChallengeInfo {
  expiresAtUtc: string;
  previewCode?: string | null;
}

export interface LoginResult {
  tokens: AuthTokens;
  profile: MemberProfile;
}

export interface SignupResult {
  profile: MemberProfile;
  otp: OtpChallengeInfo;
}
