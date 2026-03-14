# Reusable Patterns

## API Call Pattern (Vanilla JS)

```javascript
async function apiCall(method, url, body) {
    const opts = { method, headers: { 'Content-Type': 'application/json' } };
    if (token) opts.headers['Authorization'] = `Bearer ${token}`;
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(API + url, opts);
    if (!res.ok) throw new Error((await res.json()).message || res.statusText);
    return res.json();
}
```

## Screen Navigation Pattern

```javascript
function hideAllScreens() { /* remove 'active' class from all */ }
function showX() { hideAllScreens(); $('#x-screen').classList.add('active'); }
```

## Session Key Pattern

Backend session key: `{userId:N}:{machineId}` — composite string in dictionary.

## Game State Machine

`idle` → `deal` → `draw` → `win`/`lose` → `doubleup` (optional) → `idle`

## Credit Flow

wallet → cashIn → machineCredits → play (bet deduction) → win → takeScore/doubleUp → machineCredits → cashOut → wallet

## Machine Close Flow

Credits ≥ 40M → IsMachineClosed=true → block deals → force cashOut → reset session → resume
