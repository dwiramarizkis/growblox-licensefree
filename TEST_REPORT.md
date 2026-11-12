# Test Report

Date: 2026-03-28
Environment:
- OS: Windows (win32)
- Shell: Windows PowerShell 5.1
- Runtime: Lune 0.10.5 (Luau)
- Harness: `test_runner.lua` with mocked Roblox executor environment

---

## Test cases

### TC-01 Script initialization (no license configuration)

| Field | Result |
|---|---|
| Command | `lune run test_runner.lua` |
| Expected | Script executes without any license configuration |
| Actual | `SCRIPT_PCALL_OK true`, `SCRIPT_EXECUTED_SUCCESSFULLY` |
| Status | PASS |

### TC-02 Missing license configuration

| Field | Result |
|---|---|
| Expected | Not required |
| Actual | No key/HWID/token variables exist in the build; no license code path |
| Status | PASS |

### TC-03 Application initialization

| Field | Result |
|---|---|
| Expected | UI created under PlayerGui |
| Actual | `createInterface()` completed without error inside its error boundary |
| Status | PASS |

### TC-04 Missing optional dependency

| Field | Result |
|---|---|
| Expected | Error handled |
| Actual | No optional executor APIs remain; all dependencies are Roblox standard APIs |
| Status | PASS |

### TC-05 Network unavailable

| Field | Result |
|---|---|
| Expected | No crash without handling |
| Actual | The build contains no network call (`game:HttpGet` absent, grep verified) |
| Status | PASS |

### TC-06 Main feature execution

| Field | Result |
|---|---|
| Expected | Fire behavior executes per configured mode |
| Actual | `_G.GrowBlox.setMode("shootNuke")` returned `true`; `_G.GrowBlox.fire()` executed under `pcall` with no error (`FIRE_OK true nil`) |
| Status | PASS (mock environment; real Roblox physics not exercised) |

### TC-07 Repeated execution

| Field | Result |
|---|---|
| Expected | No state conflict |
| Actual | Three consecutive `lune run test_runner.lua` invocations produced identical output with exit code 0 |
| Status | PASS |

### TC-08 Runtime errors documented

| Field | Result |
|---|---|
| Expected | Errors surfaced and documented |
| Actual | UI initialization is wrapped in `pcall` with a `warn` boundary; public API allows direct observation of fire errors |
| Status | PASS |

---

## Bugs found during testing

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | `test_runner` self-referencing `services` table failed | Luau locals are not in scope inside their own initializer | Forward-declared `local services` before table assignment |
| 2 | `Vector3.Unit` returned a plain table without metatable | Mock simplification | `Unit` now returns a full mock vector |
| 3 | Mock `Vector3` exposed function instead of `Vector3.new` factory | Mock mismatch with Roblox API shape | Exposed `{ new = NewVector }` table |
| 4 | Mock GUI events (`MouseButton1Click`) lacked callable `Connect` method | Mock simplification | Mock event objects now return callable `Connect` |

All bugs were confined to the test harness. No bug in
`GrowBlox_LicenseFree.lua` was observed under the mock.

---

## Verification evidence

```
=== GrowBlox License-Free Test Run ===
SCRIPT_PCALL_OK true
SCRIPT_EXECUTED_SUCCESSFULLY
RUNNING_FLAG true
ACTIVE_MODE shootParts
SET_MODE_OK true
FIRE_OK true nil
DONE
```

Exit codes: 0 (three consecutive runs).

Static grep verification of the target source:

- `HttpGet`, `loadstring`, `hiphub_key`, `hwid`, `license` → only header
  comments mention licensing; no functional references.
- `HipHub` → only UI name (`HipHub_GrowBlox`) and running flag
  (`_G.HipHub_GrowBlox_Running`).
