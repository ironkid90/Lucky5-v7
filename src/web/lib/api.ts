import type {
  DealResult,
  DefaultRules,
  DoubleUpResult,
  DrawResult,
  JackpotInfo,
  LoginResult,
  MachineListing,
  MachineSession,
  MachineState,
  MemberProfile,
  WalletLedgerEntry,
} from "@/lib/types";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "";

async function apiFetch<T>(
  method: string,
  path: string,
  token: string | null,
  body?: unknown,
): Promise<T> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const res = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  const json = await res.json();

  if (!res.ok || json?.success === false) {
    throw new Error(json?.message ?? `HTTP ${res.status}`);
  }

  return (json?.data ?? json) as T;
}

// ── Auth ─────────────────────────────────────────────────────────────────────

export async function signup(username: string, password: string, phoneNumber: string): Promise<void> {
  await apiFetch("POST", "/api/auth/signup", null, { username, password, phoneNumber, email: `${username}@lucky5.local` });
}

export async function verifyOtp(username: string, otp: string): Promise<void> {
  await apiFetch("POST", "/api/auth/verify-otp", null, { username, otp });
}

export async function login(username: string, password: string): Promise<LoginResult> {
  return apiFetch<LoginResult>("POST", "/api/auth/login", null, { username, password });
}

export async function getProfile(token: string): Promise<MemberProfile> {
  return apiFetch<MemberProfile>("GET", "/api/Auth/GetUserById", token);
}

export async function getMemberHistory(token: string): Promise<WalletLedgerEntry[]> {
  return apiFetch<WalletLedgerEntry[]>("GET", "/api/Auth/MemberHistory", token);
}

// ── Machines ─────────────────────────────────────────────────────────────────

export async function listMachines(token: string): Promise<MachineListing[]> {
  return apiFetch<MachineListing[]>("GET", "/api/Game/games/machines", token);
}

export async function getDefaultRules(): Promise<DefaultRules> {
  return apiFetch<DefaultRules>("GET", "/api/Game/defaultRules", null);
}

export async function getMachineState(machineId: number, token: string): Promise<MachineState> {
  return apiFetch<MachineState>("GET", `/api/Game/machine/${machineId}/state`, token);
}

export async function getMachineSession(machineId: number, token: string): Promise<MachineSession> {
  return apiFetch<MachineSession>("GET", `/api/Game/machine/${machineId}/session`, token);
}

// ── Player-initiated FH-rank switch (cabinet HOLD[0] picker) ──
// Calls the existing ChangeJackpotRank backend handler. The cabinet gates this
// client-side on hasPressedBetThisSession + idle phase per the authoritative
// gameplay reference §4.1.
export async function switchFhRank(
  machineId: number,
  rank: number,
  token: string,
): Promise<JackpotInfo> {
  return apiFetch<JackpotInfo>("POST", "/api/Game/jackpot/rank", token, { machineId, rank });
}

// ── Core game actions ─────────────────────────────────────────────────────────

export async function deal(machineId: number, betAmount: number, token: string): Promise<DealResult> {
  return apiFetch<DealResult>("POST", "/api/Game/cards/deal", token, { machineId, betAmount });
}

export async function draw(roundId: string, holdIndexes: number[], token: string): Promise<DrawResult> {
  return apiFetch<DrawResult>("POST", "/api/Game/cards/draw", token, { roundId, holdIndexes });
}

// ── Double-up ─────────────────────────────────────────────────────────────────

export async function startDoubleUp(roundId: string, token: string): Promise<DoubleUpResult> {
  return apiFetch<DoubleUpResult>("POST", "/api/Game/double-up/start", token, { roundId });
}

export async function guessDoubleUp(roundId: string | null, guess: string, token: string): Promise<DoubleUpResult> {
  return apiFetch<DoubleUpResult>("POST", "/api/Game/double-up/guess", token, { roundId, guess });
}

export async function switchDealer(roundId: string | null, token: string): Promise<DoubleUpResult> {
  return apiFetch<DoubleUpResult>("POST", "/api/Game/double-up/switch", token, { roundId });
}

export async function takeHalf(roundId: string | null, token: string): Promise<DoubleUpResult> {
  return apiFetch<DoubleUpResult>("POST", "/api/Game/double-up/take-half", token, { roundId });
}

export async function cashoutDoubleUp(roundId: string | null, token: string): Promise<DoubleUpResult> {
  return apiFetch<DoubleUpResult>("POST", "/api/Game/double-up/cashout", token, { roundId });
}
