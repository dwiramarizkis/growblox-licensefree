# Dependency List

## Runtime dependencies (Roblox standard, always available)

| Dependency | Used by | Notes |
|---|---|---|
| `game` | Service access | Required |
| `game:GetService("Players")` | `LocalPlayer`, `PlayerGui` | Required |
| `game:GetService("UserInputService")` | Input detection + `InputBegan` | Required |
| `game:GetService("TweenService")` | UI/part tweens | Required |
| `game:GetService("Workspace")` (via `workspace`) | Part spawning, descendants | Required |
| `Instance` | UI and part construction | Required |
| `task.wait`, `task.spawn`, `task.delay` | Scheduling | Required |
| `warn` | Diagnostics | Required |
| `math`, `table`, `string`, `pcall` | Standard Lua/Luau | Required |

## Roblox type/type-category globals

`Color3`, `UDim2`, `UDim`, `TweenInfo`, `Enum`, `BrickColor`, `Vector3`,
`CFrame`, `PhysicalProperties`.

## Optional dependencies (all removed)

None. The license-free build makes no calls to:

- `gethui`
- `getgenv`
- `shared`
- `gethwid`
- `identifyexecutor`
- `getexecutorname`
- `setclipboard`
- `isfile`
- `readfile`
- `loadstring`
- `game:HttpGet`
- `RbxAnalyticsService`
- `HttpService`

## Test dependencies

| Dependency | Version | Purpose |
|---|---|---|
| Lune (Luau runtime) | 0.10.5 | Executes `test_runner.lua` and the target script under a mocked Roblox environment |
| Windows PowerShell | 5.1 | Test invocation shell |
