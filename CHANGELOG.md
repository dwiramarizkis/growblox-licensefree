# Change Log

## 2026-03-28 — License-free reference build

### Added
- `GrowBlox_LicenseFree.lua`: standalone GrowBlox reference reconstruction.
  - Part catalogue and shooting engine.
  - Mode selector UI.
  - Public test/debug API `_G.GrowBlox` (fire, setMode, getActiveMode,
    getUi, destroy).
- `test_runner.lua`: Lune Luau harness with a mocked Roblox executor
  environment for automated verification.

### Removed (relative to original loader)
- `_G.hiphub_key`, `shared.hiphub_key`, `getgenv().hiphub_key`, bare
  `hiphub_key` resolution.
- `HipHub/key.txt` and `hiphub_key.txt` file fallback.
- HWID, username, executor identity collection.
- `game:HttpGet` call to `https://hiphub.cloud/api/script-roblox/growblox`.
- `loadstring(content)()` dynamic execution of server response.
- Promotional "BUY PREMIUM KEY" error UI.
- Retry loop for license endpoint network failures.
- `getgenv`/`shared`/`gethwid`/`identifyexecutor`/`getexecutorname`/
  `setclipboard`/`isfile`/`readfile` executor API dependencies.

### Changed
- Execution model: server-driven dynamic chunk → self-contained static chunk.
- Error handling: licensing/network errors → application error boundary only.
- UI name retained (`HipHub_GrowBlox`) so anti-duplicate behavior matches the
  original loader convention.

### Known limitations
- The original GrowBlox main source was not returned by the endpoint for the
  provided key. This build is a reference reconstruction and must be replaced
  with the owner's real main source when available.
- In-game behavior (real Roblox physics, real UI input) is not yet verified;
  only Lune mock verification was performed.
