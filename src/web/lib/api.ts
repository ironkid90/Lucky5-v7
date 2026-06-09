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
  LoginResult,
  MachineListing,
  MachineSession,
  MachineState,
  MemberProfile,
  PlayerLobby,
  SignupResult,
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

export async function signup(username: string, password: string, phoneNumber: string): Promise<SignupResult> {
  return apiFetch<SignupResult>("POST", "/api/auth/signup", null, { username, password, phoneNumber, email: `${username}@lucky5.local` });
}

export async function verifyOtp(username: string, otp: string): Promise<void> {
  await apiFetch("POST", "/api/auth/verify-otp", null, { username, otpCode: otp });
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

export async function getPlayerLobby(token: string): Promise<PlayerLobby> {
  return apiFetch<PlayerLobby>("GET", "/api/Game/lobby", token);
}

// ── Admin / agent desk ──────────────────────────────────────────────────────

export async function listAdminUsers(token: string): Promise<AdminUser[]> {
  return apiFetch<AdminUser[]>("GET", "/api/Admin/users", token);
}

export async function getAdminDashboard(token: string): Promise<AdminDashboard> {
  return apiFetch<AdminDashboard>("GET", "/api/Admin/dashboard", token);
}

export async function searchAdminUsers(query: string, token: string): Promise<AdminUser[]> {
  return apiFetch<AdminUser[]>("GET", `/api/Admin/users/search?q=${encodeURIComponent(query)}`, token);
}

export async function getAdminUserDetail(userId: string, token: string): Promise<AdminUserDetail> {
  return apiFetch<AdminUserDetail>("GET", `/api/Admin/users/${userId}/detail`, token);
}

export async function adjustAdminUserWallet(
  targetUserId: string,
  amount: number,
  reason: string,
  token: string,
): Promise<WalletLedgerEntry> {
  return apiFetch<WalletLedgerEntry>("POST", "/api/Admin/users/credit", token, { targetUserId, amount, reason });
}

export async function applyRechargeBonus(userId: string, rechargeAmount: number, token: string): Promise<WalletLedgerEntry> {
  return apiFetch<WalletLedgerEntry>("POST", "/api/Admin/users/recharge-bonus", token, { userId, rechargeAmount });
}

export async function listAdminMachines(token: string): Promise<AdminMachine[]> {
  return apiFetch<AdminMachine[]>("GET", "/api/Admin/machines", token);
}

export async function getAdminMachineDetail(machineId: number, token: string): Promise<AdminMachineDetail> {
  return apiFetch<AdminMachineDetail>("GET", `/api/Admin/machines/${machineId}/detail`, token);
}

export async function resetAdminMachine(machineId: number, token: string): Promise<AdminMachine> {
  return apiFetch<AdminMachine>("POST", `/api/Admin/machines/${machineId}/reset`, token);
}

export async function setAdminMachineDoorState(machineId: number, doorState: 0 | 1, token: string): Promise<number> {
  return apiFetch<number>("POST", `/api/Admin/machines/${machineId}/door-state`, token, { doorState });
}

export async function listAdminAudit(token: string, take = 25): Promise<AdminAuditEntry[]> {
  return apiFetch<AdminAuditEntry[]>("GET", `/api/Admin/audit?take=${take}`, token);
}

export async function listCabinetDevices(token: string): Promise<CabinetDevice[]> {
  return apiFetch<CabinetDevice[]>("GET", "/api/Admin/cabinet-devices", token);
}

export async function provisionCabinetDevice(
  request: { machineId: number; displayName: string; serialNumber: string },
  token: string,
): Promise<CabinetDeviceProvisioning> {
  return apiFetch<CabinetDeviceProvisioning>("POST", "/api/Admin/cabinet-devices", token, request);
}

export async function revokeCabinetDevice(
  deviceId: string,
  reason: string,
  token: string,
): Promise<CabinetDevice> {
  return apiFetch<CabinetDevice>("POST", `/api/Admin/cabinet-devices/${deviceId}/revoke`, token, { reason });
}

export async function listAgents(token: string): Promise<AgentInfo[]> {
  return apiFetch<AgentInfo[]>("GET", "/api/Agent", token);
}

export async function createAgent(
  request: { name: string; code: string; phoneNumber: string },
  token: string,
): Promise<AgentInfo> {
  return apiFetch<AgentInfo>("POST", "/api/Agent", token, request);
}

export async function loadAgentCredit(agentId: number, amount: number, token: string): Promise<AgentInfo> {
  return apiFetch<AgentInfo>("POST", `/api/Agent/${agentId}/load-credit`, token, { amount });
}

export async function assignUserToAgent(agentId: number, userId: string, token: string): Promise<void> {
  await apiFetch("POST", `/api/Agent/${agentId}/assign-user/${userId}`, token);
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

export async function getActiveRound(machineId: number, token: string): Promise<ActiveRoundState | null> {
  return apiFetch<ActiveRoundState | null>("GET", `/api/Game/machine/${machineId}/active-round`, token);
}

export async function cashInMachine(machineId: number, amount: number, token: string): Promise<MachineSession> {
  return apiFetch<MachineSession>("POST", `/api/Game/machine/${machineId}/cash-in`, token, { amount });
}

export async function cashOutMachine(machineId: number, token: string): Promise<MachineSession> {
  return apiFetch<MachineSession>("POST", `/api/Game/machine/${machineId}/cash-out`, token);
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
