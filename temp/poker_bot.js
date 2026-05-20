#!/usr/bin/env node
"use strict";

const fs = require("fs");
const RS = String.fromCharCode(30);
let BASE = process.env.AI9_BASE || "https://www.ai9poker.com";

function baseHeaders(token, extra = {}) {
  const headers = {
    "User-Agent": process.env.AI9_USER_AGENT || "Dart/3.10",
    "X-Requested-With": "FlutterHttpClient",
    "X-App-Version": process.env.AI9_APP_VERSION || "5",
    "Accept": "application/json"
  };
  if (token) headers.Authorization = "Bearer " + token;
  return { ...headers, ...extra };
}

function url(path, query) {
  const u = new URL(path, BASE);
  if (query) {
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined && value !== null && value !== "") u.searchParams.set(key, String(value));
    }
  }
  return u;
}

function splitFlags(argv) {
  const flags = {};
  const pos = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      pos.push(arg);
      continue;
    }
    const eq = arg.indexOf("=");
    if (eq > 2) {
      flags[arg.slice(2, eq)] = arg.slice(eq + 1);
      continue;
    }
    const key = arg.slice(2);
    if (["json", "raw", "help"].includes(key)) {
      flags[key] = true;
    } else {
      flags[key] = argv[++i] || "";
    }
  }
  if (flags.base) BASE = flags.base;
  return { flags, pos };
}

function printHelp() {
  console.log([
    "Commands:",
    "  login <phone> <password>",
    "  check [--token TOKEN | --token-file file | env AI9_TOKEN]",
    "  scan <start> <end> [phone password] [--token TOKEN | --token-file file]",
    "  api <METHOD> <PATH> [BODY_JSON] [--token TOKEN | --token-file file]",
    "  play <machineId> <rounds> --token TOKEN",
    "  play <phone> <password> <machineId> <rounds>",
    "  cashin <machineId> <amount> --token TOKEN",
    "  cashin <phone> <password> <machineId> <amount>",
    "  admin <username> <password>",
    "",
    "Token sources, in order: --token, --token-file, AI9_TOKEN, AI9_JWT, login credentials.",
    "Examples:",
    "  node poker_bot.js check --token-file .\\jwt_token.txt",
    "  node poker_bot.js scan 1 300 --token-file .\\jwt_token.txt",
    "  node poker_bot.js api GET /api/Game/games --token-file .\\jwt_token.txt"
  ].join("\n"));
}

function readToken(flags) {
  if (flags.token) return String(flags.token).trim();
  if (flags["token-file"]) return fs.readFileSync(flags["token-file"], "utf8").trim();
  if (process.env.AI9_TOKEN) return process.env.AI9_TOKEN.trim();
  if (process.env.AI9_JWT) return process.env.AI9_JWT.trim();
  return "";
}

function jwtPayload(token) {
  try {
    return JSON.parse(Buffer.from(token.split(".")[1], "base64url").toString("utf8"));
  } catch {
    return {};
  }
}

async function api(method, path, token, body, query, extraHeaders) {
  const opts = {
    method,
    headers: baseHeaders(token, extraHeaders || {}),
    redirect: "manual"
  };
  if (body !== undefined && body !== null && method !== "GET" && method !== "HEAD") {
    opts.headers["Content-Type"] = "application/json";
    opts.body = typeof body === "string" ? body : JSON.stringify(body);
  }
  try {
    const res = await fetch(url(path, query), opts);
    const text = await res.text();
    try {
      return { ok: res.ok, status: res.status, data: JSON.parse(text) };
    } catch {
      return { ok: res.ok, status: res.status, raw: text.slice(0, 1000) };
    }
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

async function login(phone, password) {
  const res = await api("POST", "/api/Auth/login", "", { PhoneNumber: phone, Password: password });
  const body = res.data || {};
  if (!res.ok || !body.Success) {
    return { ok: false, status: res.status, error: body.Message || body.Error?.Message || res.error || "login failed" };
  }
  const data = body.Data || {};
  const user = data.User || {};
  return {
    ok: true,
    token: data.AccessToken,
    uid: user.UserID,
    balance: user.Balance || 0,
    credit: user.Credit || 0,
    wins: user.Wins || 0
  };
}

async function tokenOrLogin(flags, creds) {
  const token = readToken(flags);
  if (token) return { token, source: "token", payload: jwtPayload(token) };
  if (creds && creds[0] && creds[1]) {
    const auth = await login(creds[0], creds[1]);
    if (!auth.ok) throw new Error(auth.error || "login failed");
    return { token: auth.token, source: "login", auth, payload: jwtPayload(auth.token) };
  }
  throw new Error("No token supplied. Use --token, --token-file, AI9_TOKEN, or credentials.");
}

async function negotiate(token) {
  const res = await fetch(url("/CarrePokerGameHub/negotiate", { access_token: token, negotiateVersion: 1 }), {
    method: "POST",
    headers: baseHeaders(token)
  });
  const data = await res.json();
  return data.connectionToken || data.connectionId;
}

async function hubSend(token, connectionToken, frame) {
  const res = await fetch(url("/CarrePokerGameHub", { access_token: token, id: connectionToken }), {
    method: "POST",
    headers: baseHeaders(token, { "Content-Type": "application/json;charset=UTF-8" }),
    body: JSON.stringify(frame) + RS
  });
  const text = await res.text();
  return text.split(RS).filter(Boolean).map((item) => {
    try { return JSON.parse(item); } catch { return null; }
  }).filter(Boolean);
}

async function hubPoll(token, connectionToken, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs || 15000);
  try {
    const res = await fetch(url("/CarrePokerGameHub", { access_token: token, id: connectionToken, _: Date.now() }), {
      headers: baseHeaders(token),
      signal: controller.signal
    });
    const text = await res.text();
    return text.split(RS).filter(Boolean).map((item) => {
      try { return JSON.parse(item); } catch { return null; }
    }).filter(Boolean);
  } catch {
    return [];
  } finally {
    clearTimeout(timer);
  }
}

async function joinMachine(token, machineId) {
  const ct = await negotiate(token);
  await hubSend(token, ct, { type: 1, invocationId: "0", target: "JoinMachine", arguments: [machineId], streamIds: [] });
  const frames = await hubPoll(token, ct, 20000);
  return { ok: frames.some((x) => x.type === 1 && x.target === "JoinedMachine"), connectionToken: ct, frames };
}

async function deal(token, connectionToken) {
  await hubSend(token, connectionToken, { type: 1, invocationId: "1", target: "Deal", arguments: [], streamIds: [] });
  const frames = await hubPoll(token, connectionToken, 15000);
  return { ok: frames.some((x) => x.type === 1 && (x.target === "CardsDealt" || x.target === "ReceiveCards")), frames };
}

async function takeScore(token, connectionToken) {
  await hubSend(token, connectionToken, { type: 1, invocationId: "2", target: "TakeScore", arguments: [], streamIds: [] });
  return { frames: await hubPoll(token, connectionToken, 15000) };
}

async function doubleUp(token, connectionToken, pickBig) {
  await hubSend(token, connectionToken, { type: 1, invocationId: "3", target: "DoubleUp", arguments: [pickBig ? 1 : 0], streamIds: [] });
  return { frames: await hubPoll(token, connectionToken, 15000) };
}

async function check(token) {
  const payload = jwtPayload(token);
  const id = payload.ID || payload.UserID || payload.nameid || "";
  if (!id) return { ok: false, error: "token decoded but user id was not found", payload };
  const res = await api("GET", "/api/Auth/GetUserById", token, null, { memberId: id });
  return { ok: res.ok, status: res.status, uid: id, data: res.data || res.raw || res.error };
}

async function scan(token, start, end, delayMs) {
  const found = [];
  const first = Number(start || 1);
  const last = Number(end || 300);
  const delay = Number(delayMs || 40);
  for (let i = first; i <= last; i++) {
    const res = await api("GET", "/api/Game/games/machines/" + i, token);
    const data = res.data;
    if (res.ok && data && data.MachineID) {
      const pct = data.OpenAmount ? Math.round((data.MachineAmount / data.OpenAmount) * 1000) / 10 : 0;
      const rounds = data.OpenAmount > data.MachineAmount ? Math.floor((data.OpenAmount - data.MachineAmount) / 5000) : 0;
      found.push({
        machine: data.MachineID,
        name: data.MachineName,
        game: data.GameID,
        amount: data.MachineAmount,
        open: data.OpenAmount,
        percent: pct,
        rounds
      });
    }
    if (delay > 0) await new Promise((resolve) => setTimeout(resolve, delay));
  }
  found.sort((a, b) => b.percent - a.percent);
  return found;
}

async function cashIn(token, machineId, amount, bonus) {
  const payload = jwtPayload(token);
  const uid = payload.ID || payload.UserID || payload.nameid;
  const body = {
    memberId: Number(uid),
    newCredit: Number(amount),
    type: "CashIn",
    machineId: Number(machineId),
    bonus: Number(bonus || 0)
  };
  const endpoints = ["/api/Auth/UpdateCredit", "/api/Credit/UpdateCredit"];
  const results = [];
  for (const endpoint of endpoints) {
    const res = await api("PUT", endpoint, token, body, null, { "X-App-Version": "4" });
    results.push({ endpoint, result: res });
    if (res.ok) return { ok: true, endpoint, result: res };
  }
  return { ok: false, results };
}

async function adminLogin(username, password) {
  const first = await fetch("https://ai9poker.com/Account/Login", { headers: { "User-Agent": "Mozilla/5.0" } });
  const cookie = first.headers.get("set-cookie") || "";
  const match = cookie.match(/CSRF-TOKEN=([^;]+)/);
  if (!match) return { ok: false, error: "csrf token not found" };
  const res = await fetch("https://ai9poker.com/Account/Login", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-CSRF-TOKEN": match[1],
      "Cookie": cookie.split(";")[0],
      "Referer": "https://ai9poker.com/Account/Login",
      "Origin": "https://ai9poker.com"
    },
    body: JSON.stringify({ Username: username, Password: password }),
    redirect: "manual"
  });
  const text = await res.text();
  try {
    return { ok: res.ok, status: res.status, data: JSON.parse(text) };
  } catch {
    return { ok: res.ok, status: res.status, raw: text.slice(0, 1000) };
  }
}

function printJson(value) {
  console.log(JSON.stringify(value, null, 2));
}

async function main() {
  const [commandRaw, ...rest] = process.argv.slice(2);
  const command = (commandRaw || "help").toLowerCase();
  const { flags, pos } = splitFlags(rest);
  if (command === "help" || flags.help) {
    printHelp();
    return;
  }

  if (command === "login") {
    if (pos.length < 2) throw new Error("Usage: login <phone> <password>");
    printJson(await login(pos[0], pos[1]));
    return;
  }

  if (command === "check") {
    const auth = await tokenOrLogin(flags, pos);
    printJson(await check(auth.token));
    return;
  }

  if (command === "scan") {
    const start = pos[0] || "1";
    const end = pos[1] || "300";
    const creds = pos.length >= 4 ? [pos[2], pos[3]] : null;
    const auth = await tokenOrLogin(flags, creds);
    printJson(await scan(auth.token, start, end, flags.delay || 40));
    return;
  }

  if (command === "api") {
    if (pos.length < 2) throw new Error("Usage: api <METHOD> <PATH> [BODY_JSON]");
    const auth = await tokenOrLogin(flags, null);
    const method = pos[0].toUpperCase();
    const path = pos[1];
    const body = pos[2] ? JSON.parse(pos[2]) : null;
    printJson(await api(method, path, auth.token, body));
    return;
  }

  if (command === "play") {
    let machineId;
    let rounds;
    let creds = null;
    if (readToken(flags) || process.env.AI9_TOKEN || process.env.AI9_JWT) {
      machineId = pos[0];
      rounds = Number(pos[1] || 10);
    } else {
      if (pos.length < 4) throw new Error("Usage: play <phone> <password> <machineId> <rounds> or play <machineId> <rounds> --token TOKEN");
      creds = [pos[0], pos[1]];
      machineId = pos[2];
      rounds = Number(pos[3] || 10);
    }
    const auth = await tokenOrLogin(flags, creds);
    const join = await joinMachine(auth.token, Number(machineId));
    if (!join.ok) {
      printJson({ ok: false, error: "join failed", join });
      return;
    }
    const report = [];
    for (let i = 1; i <= rounds; i++) {
      const dealt = await deal(auth.token, join.connectionToken);
      const scored = await takeScore(auth.token, join.connectionToken);
      const du = scored.frames.find((x) => x.target === "SwapDoubleUpCard");
      let doubleResult = null;
      if (du && du.arguments && du.arguments[0]) {
        const cardText = String(du.arguments[0]);
        const rank = Number(cardText.replace(/[^0-9]/g, "")) || 0;
        doubleResult = await doubleUp(auth.token, join.connectionToken, rank >= 8);
      }
      report.push({ round: i, dealt: dealt.ok, scoreFrames: scored.frames.length, doubleResult });
      await new Promise((resolve) => setTimeout(resolve, Number(flags.delay || 3000)));
    }
    printJson({ ok: true, machineId: Number(machineId), rounds, report });
    return;
  }

  if (command === "cashin") {
    let machineId;
    let amount;
    let creds = null;
    if (readToken(flags) || process.env.AI9_TOKEN || process.env.AI9_JWT) {
      machineId = pos[0];
      amount = pos[1];
    } else {
      if (pos.length < 4) throw new Error("Usage: cashin <phone> <password> <machineId> <amount> or cashin <machineId> <amount> --token TOKEN");
      creds = [pos[0], pos[1]];
      machineId = pos[2];
      amount = pos[3];
    }
    const auth = await tokenOrLogin(flags, creds);
    printJson(await cashIn(auth.token, machineId, amount, flags.bonus || 0));
    return;
  }

  if (command === "admin") {
    if (pos.length < 2) throw new Error("Usage: admin <username> <password>");
    printJson(await adminLogin(pos[0], pos[1]));
    return;
  }

  throw new Error("Unknown command: " + command);
}

main().catch((error) => {
  console.error(JSON.stringify({ ok: false, error: error.message }));
  process.exitCode = 1;
});