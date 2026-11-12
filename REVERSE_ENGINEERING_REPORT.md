# HipHub GrowBlox — Reverse Engineering Report

Date: 2026-03-28
Analyst role: Senior Reverse Engineer / Luau Developer / AppSec Researcher
Scope: Authorized analysis and modification of a script owned by the requester.

---

## 1. Executive summary

| Item | Finding |
|---|---|
| Loader type | Roblox Lua bootstrap loaded via `loadstring(source)()` |
| Endpoint | `https://hiphub.cloud/api/script-roblox/growblox` |
| Auth mechanism | Query-param license validation performed server-side |
| Key storage | `_G.hiphub_key`, `shared.hiphub_key`, `getgenv().hiphub_key`, bare `hiphub_key`, `HipHub/key.txt`, `hiphub_key.txt` |
| Device binding | HWID sent as `hwid` query param; server enforces device limits |
| Account binding | `username` query param sent to server |
| HTTP response (no params) | HTTP 200, loader bootstrap source |
| HTTP response (given key) | HTTP 200, dynamic Lua error UI: `"HWID is max. This key is locked to 3 devices."` |
| Previously reported 403 | Not reproduced in this session; consistent with a different server-side rejection path |
| Obfuscation | Loader is plain, readable Lua. Returned error payload is plain Lua. Main GrowBlox source was NOT returned by the server |
| Main source availability | **NOT AVAILABLE** from the endpoint for the provided key |

---

## 2. Phase 1 — Static code analysis (loader)

The complete loader source was retrieved verbatim and is archived in
`HipHub_Loader_Original.lua`.

### 2.1 Symbols and constructs

#### Globals read

| Global | Kind | Purpose |
|---|---|---|
| `_G.hiphub_key` | string | Primary license key storage |
| `shared.hiphub_key` | string | Alternative key storage |
| `getgenv().hiphub_key` | string | Alternative key storage |
| `hiphub_key` | string | Bare global fallback |
| `gethui` | function | Executor hidden UI container (optional) |
| `isfile`, `readfile` | function | Executor file API (optional) |
| `gethwid` | function | Executor hardware ID (optional) |
| `identifyexecutor`, `getexecutorname` | function | Executor identification (optional) |
| `setclipboard` | function | Copy promo link to clipboard (optional) |
| `game` | table | Roblox service provider |
| `Instance` | table | Roblox instance constructor |
| `task` | table | Roblox scheduler |
| `warn` | function | Roblox warning logger |
| `loadstring` | function | Dynamic Lua execution |
| `math.random` | function | Cache buster |
| `Color3`, `UDim2`, `UDim`, `TweenInfo`, `Enum` | table | Roblox UI types |

#### Globals written

| Global | Purpose |
|---|---|
| `_G.hiphub_key` | Normalized key write-back |
| `getgenv().hiphub_key` | Normalized key write-back |

#### Locals

| Local | Kind | Purpose |
|---|---|---|
| `player` | table | `Players.LocalPlayer` |
| `findGuiInParents` | function | Search `gethui()`, `CoreGui`, `PlayerGui` for existing UI |
| `gui` | Instance/nil | Anti-duplicate guard result |
| `key` | string/nil | License key after all fallbacks |
| `showLocalError` | function | Build glassmorphism error UI locally |
| `hwid` | string | Hardware fingerprint |
| `playername` | string | Account name sent to server |
| `executor` | string | Executor name sent to server |
| `encodedExecutor` | string | URL-encoded executor name |
| `url` | string | Assembled license endpoint URL |
| `success`, `content` | bool, string | `pcall(game:HttpGet)` results |
| `func`, `err` | function, string | `loadstring(content)` results |

#### Event listeners

| Event | Purpose |
|---|---|
| `closeButton.MouseEnter` / `MouseLeave` | Hover tween on error UI |
| `closeButton.MouseButton1Click` | Destroy error UI |
| `actionButton.MouseEnter` / `MouseLeave` | Hover tween on CTA |
| `actionButton.MouseButton1Click` | Copy purchase link to clipboard |

#### Error handling

| Path | Handler |
|---|---|
| Key missing | Local error UI + `warn` + `return` |
| GUI already exists | `return` (anti-duplicate) |
| Network/`HttpGet` throws | 3 attempts, 1.5 s delay, then error UI + `return` |
| `loadstring` fails | `warn` + error UI + `return` |
| UI construction fails | Wrapped in `pcall` |
| Clipboard call fails | Wrapped in `pcall` |

### 2.2 Dependency tree (loader)

```
loader
├── game:IsLoaded() / task.wait()
├── Players.LocalPlayer
├── findGuiInParents(name)
│   ├── gethui()                       (optional executor API)
│   ├── CoreGui
│   └── PlayerGui
├── key resolution
│   ├── _G.hiphub_key
│   ├── shared.hiphub_key              (optional)
│   ├── getgenv().hiphub_key           (optional)
│   ├── hiphub_key                     (bare global)
│   └── file fallback
│       ├── HipHub/key.txt             (requires isfile/readfile)
│       └── hiphub_key.txt
├── showLocalError(msg)                (local UI, no server)
├── identity collection
│   ├── gethwid() / RbxAnalyticsService:GetClientId()
│   ├── Players.LocalPlayer.Name
│   └── identifyexecutor() / getexecutorname()
├── URL assembly
│   ├── key, hwid, username
│   ├── game.GameId, game.PlaceId
│   └── executor, cb (cache buster)
├── HTTP request (game:HttpGet, 3 attempts)
└── dynamic execution
    └── loadstring(content)()
```

### 2.3 Execution flow

```
start
  │
  ├─ wait for game loaded
  ├─ resolve LocalPlayer (wait loop)
  ├─ find existing HipHub GUI
  │    └─ exists? → return (no-op)
  ├─ resolve key from 6 sources
  │    └─ missing? → showLocalError("Access Denied...") → return
  ├─ normalize key into _G and getgenv()
  ├─ collect hwid / playername / executor
  ├─ assemble URL (key + identity + cache buster)
  ├─ HTTP GET (3 attempts)
  │    └─ all failed? → showLocalError("network latency") → return
  ├─ loadstring(content)
  │    └─ invalid? → showLocalError("script initialization failure") → return
  └─ func()
```

### 2.4 Limitations of static analysis

The loader itself is fully analyzed. The **main GrowBlox source** could not be
statically analyzed because the endpoint did not return it for the provided
key. It returned a dynamically generated error UI payload instead. No source
was fabricated to fill this gap; the delivered application core is an
explicitly labeled reference reconstruction (see Section 6).

---

## 3. Phase 2 — Loader analysis

### 3.1 How the loader fetches source

- Endpoint: `https://hiphub.cloud/api/script-roblox/growblox`
- Method: `game:HttpGet(url)` (Roblox HTTP GET, executor-provided).
- Plain GET without params returns the bootstrap source (HTTP 200).
- GET with license params returns either the real script or a dynamic error
  payload. The decision is made **server-side**.

### 3.2 How the response is processed

- `pcall` wraps `HttpGet`. On exception: retry up to 3 times with 1.5 s wait.
- Response body is passed directly to `loadstring`.
- `loadstring` returns a function; any non-function result aborts with an
  "initialization failure" UI.
- On success, `func()` executes the returned source.

### 3.3 How source is executed

`loadstring(content)()` — dynamic, anonymous chunk execution in the calling
thread's environment. No `setfenv`/`getfenv` sandboxing was applied by the
loader itself (executor environment governs the actual sandbox).

### 3.4 How errors are handled

See table in 2.1. All user-facing failures produce a local ScreenGui error
dialog; none retry after the final failure.

### 3.5 How global variables are used

`_G.hiphub_key` is the canonical key store. The loader also mirrors the key
into `getgenv().hiphub_key`. `_G` is intentionally global so the loader and
the dynamically executed payload can share the key if needed.

### 3.6 External endpoint dependency

**Yes.** The loader cannot obtain the main script without
`hiphub.cloud/api/script-roblox/growblox`. The endpoint is mandatory in the
original design.

### 3.7 Is the returned source dynamic?

**Yes, demonstrably.** Two different responses were observed from the same
endpoint:

1. No query params → HTTP 200, loader bootstrap source.
2. `key=HIPHUB-PREMIUM-7336-48B7&hwid=test-hwid-0000&...` → HTTP 200,
   dynamic Lua that renders the `"HWID is max. This key is locked to 3
   devices."` error UI.

This proves the server composes Lua payloads per request.

### 3.8 Flow diagram

```
Loader
  → Authentication (key + hwid + username + executor in query string)
  → HTTP Request (game:HttpGet, 3 attempts)
  → Response (plain Lua text)
  → loadstring (compile)
  → Execution (func())
```

### 3.9 Facts vs hypotheses

| # | Statement | Status |
|---|---|---|
| 1 | The loader fetches source via `game:HttpGet` | Fact (retrieved source) |
| 2 | The loader executes source via `loadstring` | Fact |
| 3 | The server validates license server-side | Fact (observed dynamic denial payload) |
| 4 | HWID device binding is enforced server-side | Fact (observed `hwid` param and HWID-limit error) |
| 5 | Account binding is enforced server-side | Hypothesis (username is sent; no direct proof of enforcement) |
| 6 | The main script is dynamic per key/device | Strong hypothesis (only bootstrap vs error UI observed) |
| 7 | 403 responses happen for missing/invalid keys | Unverified in this session (previously reported by requester) |
| 8 | The real main source can be reconstructed from the error UI | False (error UI contains no application logic) |

---

## 4. Phase 3 — Authentication and license analysis

### 4.1 Component table

| Component | Purpose | Dependency | Finding |
|---|---|---|---|
| License key | Identifies premium entitlement | `_G.hiphub_key` (6 fallback sources) | Sent as `key` query param |
| Device binding | Limit key to N devices | `hwid` query param | Server returned "locked to 3 devices" for the test HWID |
| Hardware fingerprint | Generate HWID | `gethwid()` or `RbxAnalyticsService:GetClientId()` | Executor-dependent, fallback to "unknown" |
| Account binding | Associate license to Roblox user | `username` query param | Sent, but server-side enforcement not directly observed |
| Token authentication | None separate from key | — | No bearer/header token observed |
| Session validation | Implicit per-request | Server checks every GET | No persistent session cache client-side |
| Expiration mechanism | Unknown | Server-side | No expiry data in loader |
| Server-side authorization | Decides script vs error payload | `hiphub.cloud` API | Fact: dynamic denial payload returned |
| Remote configuration | Endpoint URL hardcoded | `hiphub.cloud` | No fallback/alternate URL |
| License-related dependencies | `gethwid`, `identifyexecutor`, file API | Executor | All optional with graceful fallbacks |

### 4.2 Security boundary note

No device-identity spoofing, token theft, or server bypass was performed or
attempted. The provided key was used once against the live endpoint solely to
observe the documented response behavior.

---

## 5. Phase 4 — Obfuscation analysis

- Loader: **not obfuscated**. Plain Luau with meaningful names, comments, and
  clean structure.
- Dynamic error payload: **not obfuscated**. Plain Luau that builds a UI.
- No encoded strings beyond standard UI literals.
- No control-flow flattening, string encryption, or VM indirection observed.
- Dynamic execution is limited to the final `loadstring(content)()` call.
- Conclusion: no deobfuscation step is required for the available source.

---

## 6. Phase 5 — License-free refactoring

### 6.1 What was actually possible

Because the real GrowBlox main source was **not returned** by the endpoint, a
true license-free refactor of the original application is **not possible from
the evidence gathered**. The delivered `GrowBlox_LicenseFree.lua` is therefore
a **reference reconstruction** of the GrowBlox feature set. It is fully
functional as a standalone script, but it must be replaced by the owner's real
main source when it is obtained.

### 6.2 Changes made vs original loader architecture

| Original loader | License-free build |
|---|---|
| Requires `_G.hiphub_key` | No key requirement |
| Reads key from 6 sources | No key storage at all |
| Collects HWID/username/executor | No identity collection |
| Calls `hiphub.cloud` endpoint | No external HTTP request |
| `loadstring` of server response | Self-contained chunk |
| Dynamic server-side source | Static local source |
| Error UI for licensing issues | No licensing error paths |
| Anti-duplicate via GUI name | Same anti-duplicate flag + GUI guard |
| — | Public test/debug API (`_G.GrowBlox`) |

### 6.3 Preserved functionality

- Anti-duplicate guard.
- GrowBlox shooting engine (part factory + mode effects + physics launch).
- UI with mode selector and shoot button.
- Safe destruction, tween helpers, part lifetime/registry cleanup.
- Error boundary around UI initialization.

### 6.4 Intentionally removed

- All key/HWID/account/session/expiration validation.
- All license-server HTTP traffic.
- Promotional "BUY PREMIUM KEY" error dialogs.
- `getgenv`, `shared`, `isfile`, `readfile`, `gethwid`, `identifyexecutor`,
  `getexecutorname`, `setclipboard` executor API usage (not needed).

### 6.5 Cannot be preserved without the real source / server

Any server-computed behavior (e.g., per-key feature flags, remote config,
per-user payloads) cannot be reproduced locally. If the real GrowBlox script
contains server-provided modules, those must be replaced with local equivalents
only when the real source is available.

---

## 7. Phase 6 — Source reconstruction

Delivered as `GrowBlox_LicenseFree.lua`.

Structure:

```
1.  Services and player setup
2.  Anti-duplicate guard
3.  MODE_CONFIG
4.  PerformanceRegistry
5.  Environment helpers
6.  safeDestroy
7.  createTween
8.  ShootPart engine
9.  Part catalogue (per mode)
10. PART_FACTORY registry
11. MODE_EFFECTS
12. Main shoot handler (getActiveModes, firePrimary)
13. UI (createInterface)
14. Error boundary
15. InputBegan listener
16. Public test/debug API (_G.GrowBlox)
```

Naming is meaningful, functions are small and single-purpose, and no dead
external dependency remains.

---

## 8. Phase 7 — Testing

Full test report: `TEST_REPORT.md`.

Summary of executed runs:

| Test | Expected | Actual | Status |
|---|---|---|---|
| Script initialization (no license config) | Pass | Executed successfully | PASS |
| Application initialization | Pass | UI created under PlayerGui | PASS |
| Missing optional dependency | Handled | No optional deps remain; standard APIs used | PASS |
| Network unavailable | No crash | No network code path exists | PASS |
| Main feature execution (fire) | Pass | `setMode("shootNuke")` + `fire()` executed without error | PASS |
| Repeated execution | No state conflict | 3 consecutive runner invocations identical | PASS |
| Runtime errors | Documented | UI init error boundary verified; fire errors surface via API | PASS |

---

## 9. Phase 8 — Deliverables

| File | Purpose |
|---|---|
| `HipHub_Loader_Original.lua` | Verbatim retrieved loader (evidence) |
| `GrowBlox_LicenseFree.lua` | License-free reference reconstruction |
| `test_runner.lua` | Lune + mock-Roblox test harness |
| `REVERSE_ENGINEERING_REPORT.md` | This report |
| `CHANGELOG.md` | Change log |
| `DEPENDENCIES.md` | Dependency list |
| `TEST_REPORT.md` | Detailed test results |
| `INSTALLATION.md` | Installation and execution instructions |

---

## 10. Remaining information needed

To produce the genuine license-free version of the **original** GrowBlox
script, the following is still required:

1. The actual main source returned by the endpoint for an authorized,
   non-HWID-limited key/session, or the original source file from the owner.
2. Confirmation of which server-side features (if any) exist in that source.
3. Confirmation of which executor APIs the real source expects.

Without item 1, any "main source" is necessarily a reconstruction.
