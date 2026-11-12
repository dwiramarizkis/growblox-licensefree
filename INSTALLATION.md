# Installation and Execution Instructions

## Important notice

`GrowBlox_LicenseFree.lua` is a **reference reconstruction** of the GrowBlox
application core. The original GrowBlox main source was not returned by the
HipHub endpoint for the provided key, so this build must be replaced with the
owner's real main source when it is obtained.

---

## 1. Run in a Roblox executor (intended target)

1. Open your Roblox executor that supports the standard Roblox Lua/Luau API
   (`game`, `Instance`, `task`, `Vector3`, `CFrame`, `Enum`, `TweenService`,
   `UserInputService`, `Players`, `workspace`).
2. Attach the executor to Roblox.
3. Copy the full contents of `GrowBlox_LicenseFree.lua`.
4. Paste into the executor and run.
5. Expected result:
   - A `HipHub_GrowBlox` ScreenGui appears under `PlayerGui`.
   - Select a mode from the grid.
   - Click `SHOOT` or left-click in the world to fire the selected part.

No key, HWID, account, token, or license server is required.

---

## 2. Run the automated test suite (this repository)

Requires Lune (Luau runtime) and Windows PowerShell.

1. Install Lune 0.10.x:
   - Option A: `winget install Lune.Lune`
   - Option B: download from the official Lune project and add to `PATH`.
2. Open PowerShell in the project directory.
3. Run:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
lune run test_runner.lua
```

Expected output:

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

Exit code `0` indicates all automated checks passed.

---

## 3. File map

| File | Run? | Description |
|---|---|---|
| `GrowBlox_LicenseFree.lua` | Yes (executor) | License-free reference build |
| `test_runner.lua` | Yes (Lune) | Mock-Roblox automated test harness |
| `HipHub_Loader_Original.lua` | No (evidence) | Verbatim retrieved loader source |
| `REVERSE_ENGINEERING_REPORT.md` | No | Full analysis report |
| `CHANGELOG.md` | No | Change log |
| `DEPENDENCIES.md` | No | Dependency list |
| `TEST_REPORT.md` | No | Test results |
| `INSTALLATION.md` | No | This file |

---

## 4. Replacing the reconstruction with the real source

When the authorized original GrowBlox main source is available:

1. Remove the server/license validation section from that source.
2. Preserve its application modules and entry point.
3. Verify its external dependencies (services, executor APIs).
4. Port the feature set into the structure of `GrowBlox_LicenseFree.lua`, or
   execute the cleaned original source directly.
5. Re-run `lune run test_runner.lua` after adapting the harness to the real
   feature set.
