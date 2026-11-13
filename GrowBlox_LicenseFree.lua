-- GrowBlox License-Free v3
-- Logika mengikuti k.lua (Syigrow) untuk game Growblox:
--   - Gerakan : hook WorldMenu.isDown + AutoInput (kiri/kanan/lompat)
--   - Place   : Refs.SetTile(layer, x, y, id, false, false) + Refs.Inv:remove(id, 1)
--   - Break   : Refs.Punch(x, y, mute, nil)
--   - Grid    : pilih tile relatif terhadap posisi pemain (5x5, pemain di tengah)
-- Tanpa key/HWID/server lisensi.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local function globalFn(name)
	local ok, f = pcall(function()
		local r = rawget(_G, name)
		if type(r) ~= "function" and type(getgenv) == "function" then
			r = getgenv()[name]
		end
		return r
	end)
	if ok and type(f) == "function" then return f end
	return nil
end

local getgc = globalFn("getgc")
local getconsts = globalFn("getconstants") or (type(debug) == "table" and debug.getconstants) or nil

print("[GrowBlox] executor: getgc=" .. tostring(getgc ~= nil) .. " getconstants=" .. tostring(getconsts ~= nil))

-- ===========================================================================
-- Konfigurasi
-- ===========================================================================
local CONFIG = {
	autoBreak = true,
	autoPlace = false,
	autoPlant = true,
	pnbEnabled = false,

	placeId = 20,       -- Dirt
	plantId = 696,      -- Dirt Seed

	range = 4,
	interval = 0.25,
	breakMs = 220,      -- jeda tiap pukulan (ms), seperti k.lua
	afterBreakMs = 300, -- jeda setelah hancur
	punchCooldown = 0.22,
	mutePunch = true,

	gridSize = 5,
	pnbInterval = 0.15,
	pnbBreakOccupied = true,
	pnbPlaceEmpty = true,
}

local selectedTiles = {} -- "x,y" -> true (absolut)
local gridTiles = {}

-- ===========================================================================
-- Referensi game
-- ===========================================================================
local Refs = {
	World = nil,
	State = nil,
	Inv = nil,
	SetTile = nil,
	Punch = nil,
}

local function isWorldTbl(v)
	return type(rawget(v, "fg")) == "table" and type(rawget(v, "bg")) == "table"
		and type(rawget(v, "w")) == "number" and type(rawget(v, "h")) == "number"
end

local function isInvTbl(v)
	return type(rawget(v, "slots")) == "table"
		and (rawget(v, "capacity") ~= nil or type(rawget(v, "count")) == "function")
		and type(rawget(v, "remove")) == "function"
end

local function isStateHolder(v)
	local fn = rawget(v, "state")
	if type(fn) ~= "function" then return false end
	local ok, s = pcall(fn)
	return ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number"
		and s.facing ~= nil and s.vx ~= nil
end

local function fnConsts(fn)
	if not getconsts then return nil end
	local ok, c = pcall(getconsts, fn)
	if ok and type(c) == "table" then return c end
	return nil
end

local function hasConsts(fn, ...)
	local c = fnConsts(fn)
	if not c then return false end
	for _, want in ipairs({ ... }) do
		local found = false
		for _, v in pairs(c) do
			if v == want then found = true break end
		end
		if not found then return false end
	end
	return true
end

local function isSetTileFn(fn)
	if not getconsts then return false end
	local c = fnConsts(fn)
	if not c then return false end
	local hasSend, hasPlaced, hasFlips = false, false, false
	for _, v in pairs(c) do
		if v == "tile" or v == "SetTile" then hasSend = true
		elseif v == "placedAt" then hasPlaced = true
		elseif v == "flips" then hasFlips = true end
	end
	if hasSend and hasPlaced and hasFlips then return true end
	return hasConsts(fn, "tileChanged", "layer", "flip")
end

local function isPunchFn(fn)
	if not getconsts then return false end
	if hasConsts(fn, "Empty the Vending Machine first!", "newCrack")
		or hasConsts(fn, "Empty the Vending Machine first!", "HarvestProvider")
		or hasConsts(fn, "punchEvent", "punch_miss")
		or hasConsts(fn, "punchCount", "Punch", "punchFx") then
		return true
	end
	return false
end

local function scanRefs()
	if not getgc then
		print("[GrowBlox] getgc TIDAK ADA")
		return false
	end
	local ok, all = pcall(getgc, true)
	if not ok or type(all) ~= "table" then
		print("[GrowBlox] getgc(true) gagal: " .. tostring(all))
		return false
	end
	print("[GrowBlox] getgc objects=" .. tostring(#all))

	local punchSeen, settileSeen = {}, {}
	for _, v in ipairs(all) do
		if type(v) == "table" then
			-- World: cukup fg/bg + w/h (tanpa spawn)
			if not Refs.World and type(rawget(v, "fg")) == "table"
				and type(rawget(v, "bg")) == "table"
				and type(rawget(v, "w")) == "number"
				and type(rawget(v, "h")) == "number" then
				Refs.World = v
			end
			-- Inventory: slots + remove + count (count bisa method/function)
			if not Refs.Inv and type(rawget(v, "slots")) == "table"
				and type(rawget(v, "remove")) == "function"
				and (type(rawget(v, "count")) == "function" or type(rawget(v, "capacity")) == "number") then
				Refs.Inv = v
			end
			-- State holder: state function
			if not Refs.State then
				local fn = rawget(v, "state")
				if type(fn) == "function" then
					local okS, s = pcall(fn)
					if okS and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" then
						Refs.State = fn
					end
				end
			end
		elseif type(v) == "function" then
			if isSetTileFn(v) then settileSeen[#settileSeen + 1] = v end
			if isPunchFn(v) then punchSeen[#punchSeen + 1] = v end
		end
	end
	Refs.SetTile = settileSeen[1]
	Refs.Punch = punchSeen[1]
	print(string.format("[GrowBlox] refs: world=%s state=%s inv=%s settile=%s punch=%s (setcand=%d punchcand=%d)",
		tostring(Refs.World ~= nil),
		tostring(Refs.State ~= nil),
		tostring(Refs.Inv ~= nil),
		tostring(Refs.SetTile ~= nil),
		tostring(Refs.Punch ~= nil),
		#settileSeen,
		#punchSeen))
	return Refs.World ~= nil
end

local refsOk = scanRefs()
if not refsOk then
	print("[GrowBlox] Gagal menemukan world. Coba ulang dalam 3 detik...")
	task.wait(3)
	scanRefs()
end
if not Refs.World then
	print("[GrowBlox] FATAL: world tidak ditemukan. Pastikan sudah masuk world.")
end

-- ===========================================================================
-- Modul game (seperti k.lua)
-- ===========================================================================
local Shared = ReplicatedStorage:FindFirstChild("Shared")
local WorldRemotes = ReplicatedStorage:FindFirstChild("WorldRemotes")
local SetTileRemote = WorldRemotes and WorldRemotes:FindFirstChild("SetTile")

local ItemDB = nil
local InventoryModule = nil
local NetOk, Net = false, nil

if Shared then
	pcall(function() ItemDB = require(Shared:FindFirstChild("ItemDB")) end)
	pcall(function() InventoryModule = require(Shared:FindFirstChild("Inventory")) end)
	pcall(function() NetOk, Net = pcall(require, Shared:FindFirstChild("Net")) end)
end

-- WorldMenu module untuk hook gerakan (k.lua)
local MenuModule = nil
local MenuModOk = false
pcall(function()
	local GameGui = PlayerGui:FindFirstChild("GameGui") or PlayerGui:WaitForChild("GameGui", 5)
	if GameGui then
		local wm = GameGui:FindFirstChild("WorldMenu")
		if wm and wm:IsA("ModuleScript") then
			MenuModOk, MenuModule = pcall(require, wm)
		end
	end
end)

-- ===========================================================================
-- AutoInput + hook isDown (logika persis k.lua)
-- ===========================================================================
local AutoInput = { active = false, left = false, right = false, jump = false, down = false }
local OrigIsDown = nil

local function isDownWrapper(saved, key, ...)
	if AutoInput.active then
		if key == "keyLeft" then return AutoInput.left end
		if key == "keyRight" then return AutoInput.right end
		if key == "keyJump" then return AutoInput.jump end
		if key == "keyDown" then return AutoInput.down end
	end
	return OrigIsDown(saved, key, ...)
end

if MenuModOk and type(MenuModule) == "table" and type(rawget(MenuModule, "isDown")) == "function" then
	OrigIsDown = rawget(MenuModule, "isDown")
	MenuModule.isDown = isDownWrapper
	print("[GrowBlox] WorldMenu.isDown hooked")
else
	print("[GrowBlox] WorldMenu.isDown TIDAK ditemukan, gerakan auto mati")
end

local function releaseInput()
	AutoInput.left, AutoInput.right, AutoInput.jump, AutoInput.down = false, false, false, false
end

-- ===========================================================================
-- Helper data game
-- ===========================================================================
local function playerState()
	if not Refs.State then return nil end
	local ok, s = pcall(Refs.State)
	if ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" and s.active ~= false then
		return s
	end
	return nil
end

local function getPlayerTile()
	local s = playerState()
	if not s then return nil end
	return math.floor(s.x), math.floor(s.y - 0.475)
end

local function tileAt(layer, x, y)
	local w = Refs.World
	if not w or x < 0 or y < 0 or x >= w.w or y >= w.h then return nil end
	local grid = w[layer]
	local row = grid and grid[y]
	return row and (row[x] or 0) or nil
end

local function fgIdAt(x, y)
	local w = Refs.World
	local row = w and w.fg[y]
	return (row and row[x]) or 0
end

local function invCount(id)
	if not Refs.Inv then return 0 end
	-- Coba method count
	local cnt = rawget(Refs.Inv, "count")
	if type(cnt) == "function" then
		local ok, n = pcall(cnt, Refs.Inv, id)
		if ok and type(n) == "number" then return n end
		-- fallback: count tanpa self
		local ok2, n2 = pcall(cnt, id)
		if ok2 and type(n2) == "number" then return n2 end
	end
	-- Fallback: cari di slots
	for _, slot in ipairs(Refs.Inv.slots or {}) do
		if type(slot) == "table" and slot.id == id then
			return slot.n or 0
		end
	end
	return 0
end

local function invRemove(id, n)
	if not Refs.Inv then return false end
	local rm = rawget(Refs.Inv, "remove")
	if type(rm) ~= "function" then return false end
	local ok = pcall(rm, Refs.Inv, id, n or 1)
	if ok then return true end
	-- fallback: tanpa self
	return pcall(rm, id, n or 1)
end

local function breakable(id)
	return type(id) == "number" and id > 0
end

-- ===========================================================================
-- Aksi dasar (persis k.lua)
-- ===========================================================================
local function sendSetTile(layer, x, y, id)
	if Refs.SetTile then
		local ok, err = pcall(Refs.SetTile, layer, x, y, id, false, false)
		if ok then return true end
		warn("[GrowBlox] setTile gagal: " .. tostring(err))
	end
	if NetOk and type(Net) == "table" and type(Net.tile) == "table" then
		local ok = pcall(Net.tile.send, {
			layer = (layer == "bg") and 2 or 1,
			x = x,
			y = y,
			id = id,
			flip = false,
		})
		if ok then return true end
	elseif SetTileRemote then
		pcall(function() SetTileRemote:FireServer(layer, x, y, id, false) end)
		return true
	end
	return false
end

local function tryPlace(x, y, id)
	if not id or invCount(id) <= 0 then return "habis" end
	if fgIdAt(x, y) ~= 0 then return nil end
	if not sendSetTile("fg", x, y, id) then return nil end
	invRemove(id, 1) -- persis k.lua
	return "place"
end

local lastPunch = {}

local function tryBreak(x, y)
	local key = x .. "," .. y
	local now = os.clock()
	if lastPunch[key] and (now - lastPunch[key]) < CONFIG.punchCooldown then
		return "cooldown"
	end
	lastPunch[key] = now

	local id = fgIdAt(x, y)
	if not breakable(id) then return nil end

	if Refs.Punch then
		local ok, err = pcall(Refs.Punch, x, y, CONFIG.mutePunch or nil, nil)
		if ok then
			-- Cek tile berubah setelah pukulan (persis k.lua)
			local newId = fgIdAt(x, y)
			if newId ~= id then
				return "broke"
			end
			return "hit"
		end
		warn("[GrowBlox] punch error: " .. tostring(err))
	end

	-- Fallback: set tile 0 (server-authoritative)
	if sendSetTile("fg", x, y, 0) then
		return "broke"
	end
	return nil
end

-- ===========================================================================
-- Gerakan otomatis (steerX + execWalk dari k.lua, disederhanakan)
-- ===========================================================================
local function autoOn()
	return true
end

local function frame()
	task.wait()
	return autoOn()
end

local function waitAuto(ms)
	task.wait(math.max(ms or 0, 30) / 1000)
	return autoOn()
end

local function steerX(s, targetX, tol)
	local dx = targetX - s.x
	local vx = s.vx or 0
	local decel = s.grounded and 48 or 17
	local dir = 0
	if math.abs(dx) > tol then
		dir = dx > 0 and 1 or -1
		if vx * dir > 0 and (vx * vx) / (2 * decel) >= math.abs(dx) - tol * 0.5 then
			dir = 0
		end
	end
	AutoInput.left = dir < 0
	AutoInput.right = dir > 0
end

local function execWalk(tx, ty)
	if not OrigIsDown then return false end
	local cx = tx + 0.5
	local s0 = playerState()
	if not s0 then return false end
	local limit = 1.5 + math.abs(cx - s0.x) * 0.35
	local t0 = os.clock()
	AutoInput.active = true
	while frame() do
		local s = playerState()
		if not s or s.dead then releaseInput(); return false end
		local nx, ny = math.floor(s.x), math.floor(s.y - 0.475)
		if s.grounded and ny ~= ty then releaseInput(); return false end
		steerX(s, cx, 0.1)
		if nx == tx and math.abs(s.x - cx) <= 0.2 and s.grounded and math.abs(s.vx or 0) < 2 then
			releaseInput()
			return true
		end
		if os.clock() - t0 > limit then releaseInput(); return false end
	end
	releaseInput()
	return false
end

local function execJumpUp(tx, ty)
	if not OrigIsDown then return false end
	local cx = tx + 0.5
	releaseInput()
	AutoInput.active = true
	AutoInput.jump = true
	local t0 = os.clock()
	local airborne = false
	while frame() do
		local s = playerState()
		if not s or s.dead then releaseInput(); return false end
		if not s.grounded then airborne = true end
		if AutoInput.jump and (airborne and (s.vy or 0) >= 0) then
			AutoInput.jump = false
		end
		steerX(s, cx, 0.1)
		if airborne and s.grounded then
			local nx, ny = math.floor(s.x), math.floor(s.y - 0.475)
			if ny == ty then
				if nx == tx and math.abs(s.x - cx) <= 0.25 then
					releaseInput()
					return true
				end
			else
				releaseInput()
				return false
			end
		end
		if os.clock() - t0 > 1.8 then releaseInput(); return false end
	end
	releaseInput()
	return false
end

-- Jalan menuju tile target (hanya 1 tile di atas/bawah, tanpa A*)
local function walkTo(tx, ty, maxSec)
	if not OrigIsDown then return false end
	local s = playerState()
	if not s then return false end
	local nx, ny = getPlayerTile()
	if not nx then return false end

	AutoInput.active = true
	local t0 = os.clock()
	local ok = false

	if ny == ty then
		ok = execWalk(tx, ty)
	elseif ty == ny - 1 then
		-- Turun: jalan ke arah tx, jatuh
		ok = execWalk(tx, ny)
	elseif ty == ny + 1 then
		-- Naik 1 tile
		if execWalk(tx, ny) then
			ok = execJumpUp(tx, ty)
		end
	end

	AutoInput.active = false
	releaseInput()
	return ok
end

-- ===========================================================================
-- Farm actions
-- ===========================================================================
local function tilesAround(px, py, radius)
	local out = {}
	if not Refs.World then return out end
	for y = py - radius, py + radius do
		for x = px - radius, px + radius do
			local fg = tileAt("fg", x, y)
			if fg ~= nil then
				out[#out + 1] = {
					x = x,
					y = y,
					fg = fg,
					distance = math.abs(x - px) + math.abs(y - py),
				}
			end
		end
	end
	table.sort(out, function(a, b)
		if a.distance ~= b.distance then return a.distance < b.distance end
		if a.y ~= b.y then return a.y < b.y end
		return a.x < b.x
	end)
	return out
end

local function autoBreakOnce()
	local px, py = getPlayerTile()
	if not px then return false, "no state" end

	-- Cari semua tile terisi yang siap dipukul (bukan cooldown),
	-- lalu pukul BERGANTIAN seperti k.lua.
	local ready = {}
	local now = os.clock()
	for _, t in ipairs(tilesAround(px, py, CONFIG.range)) do
		if breakable(t.fg) then
			local key = t.x .. "," .. t.y
			if not lastPunch[key] or (now - lastPunch[key]) >= CONFIG.punchCooldown then
				ready[#ready + 1] = t
			end
		end
	end
	if #ready == 0 then return false, "no breakable ready" end

	-- Pilih tile yang paling lama tidak dipukul (round-robin sederhana)
	table.sort(ready, function(a, b)
		local ka = a.x .. "," .. a.y
		local kb = b.x .. "," .. b.y
		local ta = lastPunch[ka] or 0
		local tb = lastPunch[kb] or 0
		return ta < tb
	end)

	local target = ready[1]
	local r = tryBreak(target.x, target.y)
	if r == "hit" or r == "broke" then
		return true, "break " .. target.x .. "," .. target.y .. " id=" .. tostring(target.fg)
	end
	return false, "break failed: " .. tostring(r)
end

local function autoPlantOnce()
	local px, py = getPlayerTile()
	if not px then return false, "no state" end

	local target = nil
	for _, t in ipairs(tilesAround(px, py, CONFIG.range)) do
		if t.fg == 0 or t.fg == "" or t.fg == nil then
			target = t
			break
		end
	end
	if not target then return false, "no empty tile" end

	local r = tryPlace(target.x, target.y, CONFIG.plantId)
	if r == "place" then
		return true, "plant " .. target.x .. "," .. target.y
	end
	return false, "plant failed: " .. tostring(r)
end

local function autoPlaceOnce()
	local px, py = getPlayerTile()
	if not px then return false, "no state" end

	local target = nil
	for _, t in ipairs(tilesAround(px, py, CONFIG.range)) do
		if t.fg == 0 or t.fg == "" or t.fg == nil then
			target = t
			break
		end
	end
	if not target then return false, "no empty tile" end

	local r = tryPlace(target.x, target.y, CONFIG.placeId)
	if r == "place" then
		return true, "place " .. target.x .. "," .. target.y
	end
	return false, "place failed: " .. tostring(r)
end

-- ===========================================================================
-- PNB grid mode
-- ===========================================================================
local function pnbTick()
	if not CONFIG.pnbEnabled then return false, "pnb off" end
	local px, py = getPlayerTile()
	if not px then return false, "no state" end

	gridTiles = {}
	local half = math.floor(CONFIG.gridSize / 2)
	for row = 1, CONFIG.gridSize do
		for col = 1, CONFIG.gridSize do
			local tx = px - half + (col - 1)
			local ty = py - half + (row - 1)
			local fg = tileAt("fg", tx, ty)
			if fg ~= nil then
				gridTiles[#gridTiles + 1] = { x = tx, y = ty, fg = fg }
			end
		end
	end

	for _, t in ipairs(gridTiles) do
		if selectedTiles[t.x .. "," .. t.y] then
			if breakable(t.fg) and CONFIG.pnbBreakOccupied then
				local r = tryBreak(t.x, t.y)
				if r == "hit" or r == "broke" then
					return true, "pnb break " .. t.x .. "," .. t.y
				end
			elseif (t.fg == 0 or t.fg == "" or t.fg == nil) and CONFIG.pnbPlaceEmpty then
				local r = tryPlace(t.x, t.y, CONFIG.placeId)
				if r == "place" then
					return true, "pnb place " .. t.x .. "," .. t.y
				end
			end
		end
	end
	return false, "no pnb action"
end

local function toggleTileSelection(x, y)
	local key = x .. "," .. y
	if selectedTiles[key] then
		selectedTiles[key] = nil
	else
		selectedTiles[key] = true
	end
	return selectedTiles[key] == true
end

local function clearTileSelection()
	selectedTiles = {}
end

-- ===========================================================================
-- Loop utama
-- ===========================================================================
local running = { breakLoop = true, placeLoop = true, plantLoop = true, pnbLoop = true }

local function startLoop(name, enabled, action, waitTime)
	task.spawn(function()
		while running[name] do
			if enabled() then
				local ok, a, b = pcall(action)
				if not ok then
					warn("[GrowBlox] loop " .. name .. " error: " .. tostring(a))
				elseif a == true then
					print("[GrowBlox] " .. name .. " -> " .. tostring(a) .. " " .. tostring(b))
				end
			end
			task.wait(waitTime or CONFIG.interval)
		end
	end)
end

startLoop("breakLoop", function() return CONFIG.autoBreak and not CONFIG.pnbEnabled end, autoBreakOnce, CONFIG.breakMs / 1000)
startLoop("placeLoop", function() return CONFIG.autoPlace and not CONFIG.pnbEnabled end, autoPlaceOnce)
startLoop("plantLoop", function() return CONFIG.autoPlant and not CONFIG.pnbEnabled end, autoPlantOnce)
startLoop("pnbLoop", function() return CONFIG.pnbEnabled end, pnbTick, CONFIG.pnbInterval)

-- ===========================================================================
-- GUI
-- ===========================================================================
local function notify(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = tostring(title),
			Text = tostring(text),
			Duration = duration or 2,
		})
	end)
end

local ui = {}

local function createGui()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GrowBloxUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 2147483647

	pcall(function()
		local parent = player:FindFirstChild("PlayerGui")
		if not parent and type(gethui) == "function" then parent = gethui() end
		if not parent then parent = game:GetService("CoreGui") end
		screenGui.Parent = parent
	end)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 180, 0, 236)
	frame.Position = UDim2.new(0.5, -90, 1, -240)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.BackgroundColor3 = Color3.fromRGB(15, 18, 32)
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 24)
	title.Position = UDim2.new(0, 8, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "GrowBlox"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hideBtn = Instance.new("TextButton")
	hideBtn.Size = UDim2.new(0, 22, 0, 20)
	hideBtn.Position = UDim2.new(1, -26, 0, 4)
	hideBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	hideBtn.BorderSizePixel = 0
	hideBtn.Text = "X"
	hideBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	hideBtn.Font = Enum.Font.GothamBold
	hideBtn.TextSize = 10
	hideBtn.Parent = frame

	local hideCorner = Instance.new("UICorner")
	hideCorner.CornerRadius = UDim.new(0, 5)
	hideCorner.Parent = hideBtn

	local visible = true
	local function setVisible(v)
		visible = v
		frame.Size = v and UDim2.new(0, 180, 0, 236) or UDim2.new(0, 70, 0, 28)
		for _, child in ipairs(frame:GetChildren()) do
			if child ~= title and child ~= hideBtn and child:IsA("GuiObject") then
				child.Visible = v
			end
		end
	end

	hideBtn.MouseButton1Click:Connect(function()
		setVisible(not visible)
		hideBtn.Text = visible and "X" or "+"
	end)

	local function addToggle(buttonName, configKey, y)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -16, 0, 30)
		btn.Position = UDim2.new(0, 8, 0, y)
		btn.BackgroundColor3 = Color3.fromRGB(30, 36, 60)
		btn.BorderSizePixel = 0
		btn.Text = buttonName .. ": " .. (CONFIG[configKey] and "ON" or "OFF")
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.AutoButtonColor = true
		btn.Parent = frame

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 5)
		c.Parent = btn

		btn.MouseButton1Click:Connect(function()
			CONFIG[configKey] = not CONFIG[configKey]
			btn.Text = buttonName .. ": " .. (CONFIG[configKey] and "ON" or "OFF")
			notify(buttonName, CONFIG[configKey] and "ON" or "OFF", 1.5)
		end)
	end

	addToggle("Auto Break", "autoBreak", 30)
	addToggle("Auto Place", "autoPlace", 64)
	addToggle("Auto Plant", "autoPlant", 98)
	addToggle("PNB Grid", "pnbEnabled", 132)

	local gridBtn = Instance.new("TextButton")
	gridBtn.Size = UDim2.new(1, -16, 0, 30)
	gridBtn.Position = UDim2.new(0, 8, 0, 166)
	gridBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
	gridBtn.BorderSizePixel = 0
	gridBtn.Text = "OPEN GRID PNB"
	gridBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	gridBtn.Font = Enum.Font.GothamBold
	gridBtn.TextSize = 12
	gridBtn.Parent = frame

	local gridCorner = Instance.new("UICorner")
	gridCorner.CornerRadius = UDim.new(0, 5)
	gridCorner.Parent = gridBtn

	-- Tombol debug
	local function addMoveButton(label, x, action)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 42, 0, 24)
		btn.Position = UDim2.new(0, x, 0, 200)
		btn.BackgroundColor3 = Color3.fromRGB(60, 70, 100)
		btn.BorderSizePixel = 0
		btn.Text = label
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 10
		btn.Parent = frame

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 4)
		c.Parent = btn

		btn.MouseButton1Click:Connect(function() action() end)
	end

	addMoveButton("<", 8, function()
		AutoInput.active = true
		AutoInput.left = true
		task.wait(0.2)
		releaseInput()
		AutoInput.active = false
	end)
	addMoveButton(">", 56, function()
		AutoInput.active = true
		AutoInput.right = true
		task.wait(0.2)
		releaseInput()
		AutoInput.active = false
	end)
	addMoveButton("^", 104, function()
		AutoInput.active = true
		AutoInput.jump = true
		task.wait(0.15)
		AutoInput.jump = false
		AutoInput.active = false
	end)

	-- Panel grid PNB
	local gridPanel = Instance.new("Frame")
	gridPanel.Size = UDim2.new(0, 190, 0, 250)
	gridPanel.Position = UDim2.new(0.5, -95, 0.5, -125)
	gridPanel.BackgroundColor3 = Color3.fromRGB(18, 22, 40)
	gridPanel.BorderSizePixel = 0
	gridPanel.Active = true
	gridPanel.Draggable = true
	gridPanel.Visible = false
	gridPanel.Parent = screenGui

	local gpCorner = Instance.new("UICorner")
	gpCorner.CornerRadius = UDim.new(0, 8)
	gpCorner.Parent = gridPanel

	local gpTitle = Instance.new("TextLabel")
	gpTitle.Size = UDim2.new(1, -60, 0, 24)
	gpTitle.Position = UDim2.new(0, 8, 0, 4)
	gpTitle.BackgroundTransparency = 1
	gpTitle.Text = "Grid PNB (5x5)"
	gpTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	gpTitle.Font = Enum.Font.GothamBold
	gpTitle.TextSize = 12
	gpTitle.TextXAlignment = Enum.TextXAlignment.Left
	gpTitle.Parent = gridPanel

	local gpClose = Instance.new("TextButton")
	gpClose.Size = UDim2.new(0, 22, 0, 20)
	gpClose.Position = UDim2.new(1, -26, 0, 4)
	gpClose.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	gpClose.BorderSizePixel = 0
	gpClose.Text = "X"
	gpClose.TextColor3 = Color3.fromRGB(255, 255, 255)
	gpClose.Font = Enum.Font.GothamBold
	gpClose.TextSize = 10
	gpClose.Parent = gridPanel

	local gpCloseCorner = Instance.new("UICorner")
	gpCloseCorner.CornerRadius = UDim.new(0, 5)
	gpCloseCorner.Parent = gpClose

	local gpInfo = Instance.new("TextLabel")
	gpInfo.Size = UDim2.new(1, -16, 0, 18)
	gpInfo.Position = UDim2.new(0, 8, 0, 28)
	gpInfo.BackgroundTransparency = 1
	gpInfo.Text = "Terpilih: 0"
	gpInfo.TextColor3 = Color3.fromRGB(180, 200, 230)
	gpInfo.Font = Enum.Font.Gotham
	gpInfo.TextSize = 11
	gpInfo.TextXAlignment = Enum.TextXAlignment.Left
	gpInfo.Parent = gridPanel

	local gpClear = Instance.new("TextButton")
	gpClear.Size = UDim2.new(0, 90, 0, 22)
	gpClear.Position = UDim2.new(1, -98, 0, 26)
	gpClear.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
	gpClear.BorderSizePixel = 0
	gpClear.Text = "CLEAR"
	gpClear.TextColor3 = Color3.fromRGB(0, 0, 0)
	gpClear.Font = Enum.Font.GothamBold
	gpClear.TextSize = 10
	gpClear.Parent = gridPanel

	local gpClearCorner = Instance.new("UICorner")
	gpClearCorner.CornerRadius = UDim.new(0, 5)
	gpClearCorner.Parent = gpClear

	gpClear.MouseButton1Click:Connect(function() clearTileSelection() end)

	local gridButtons = {}
	local cellSize = 34
	for row = 0, 4 do
		for col = 0, 4 do
			local cell = Instance.new("TextButton")
			cell.Size = UDim2.new(0, cellSize, 0, cellSize)
			cell.Position = UDim2.new(0, 8 + col * (cellSize + 2), 0, 54 + row * (cellSize + 2))
			cell.BackgroundColor3 = Color3.fromRGB(30, 36, 60)
			cell.BorderSizePixel = 0
			cell.Text = "?"
			cell.TextColor3 = Color3.fromRGB(255, 255, 255)
			cell.Font = Enum.Font.GothamBold
			cell.TextSize = 8
			cell.Parent = gridPanel

			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 4)
			cCorner.Parent = cell

			gridButtons[(row * 5) + col + 1] = cell
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.3)
			if not gridPanel.Visible then continue end
			local px, py = getPlayerTile()
			local selectedCount = 0
			for _ in pairs(selectedTiles) do selectedCount += 1 end
			gpInfo.Text = "Terpilih: " .. selectedCount .. " | Posisi: " .. (px and (px .. "," .. py) or "?")

			if px then
				local half = math.floor(CONFIG.gridSize / 2)
				for row = 0, 4 do
					for col = 0, 4 do
						local tx = px - half + col
						local ty = py - half + row
						local idx = (row * 5) + col + 1
						local cell = gridButtons[idx]
						if cell then
							local fg = tileAt("fg", tx, ty)
							local selected = selectedTiles[tx .. "," .. ty] == true
							local isPlayer = (row == half and col == half)
							if isPlayer then
								cell.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
								cell.Text = "YOU"
							elseif selected then
								cell.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
								cell.Text = breakable(fg) and tostring(fg) or "S"
							elseif breakable(fg) then
								cell.BackgroundColor3 = Color3.fromRGB(80, 60, 30)
								cell.Text = tostring(fg)
							else
								cell.BackgroundColor3 = Color3.fromRGB(30, 36, 60)
								cell.Text = "."
							end
						end
					end
				end
			end
		end
	end)

	for idx, cell in ipairs(gridButtons) do
		cell.MouseButton1Click:Connect(function()
			local px, py = getPlayerTile()
			if not px then return end
			local half = math.floor(CONFIG.gridSize / 2)
			local row = math.floor((idx - 1) / 5)
			local col = (idx - 1) % 5
			if row == half and col == half then return end
			local tx = px - half + col
			local ty = py - half + row
			toggleTileSelection(tx, ty)
		end)
	end

	gridBtn.MouseButton1Click:Connect(function()
		gridPanel.Visible = not gridPanel.Visible
	end)

	gpClose.MouseButton1Click:Connect(function()
		gridPanel.Visible = false
	end)

	ui.screenGui = screenGui
end

local uiOk, uiErr = pcall(createGui)
if not uiOk then
	warn("[GrowBlox] GUI failed: " .. tostring(uiErr))
end

-- ===========================================================================
-- API publik
-- ===========================================================================
_G.GrowBlox = {
	config = CONFIG,
	refs = Refs,
	breakOnce = autoBreakOnce,
	placeOnce = autoPlaceOnce,
	plantOnce = autoPlantOnce,
	pnbTick = pnbTick,
	toggleTile = toggleTileSelection,
	clearTiles = clearTileSelection,
	walkTo = walkTo,
	getState = playerState,
	tileAt = tileAt,
	scanAround = function(radius)
		local px, py = getPlayerTile()
		if not px then return {} end
		return tilesAround(px, py, radius or CONFIG.range)
	end,
	destroy = function()
		running.breakLoop = false
		running.placeLoop = false
		running.plantLoop = false
		running.pnbLoop = false
		if OrigIsDown and MenuModule and rawget(MenuModule, "isDown") == isDownWrapper then
			MenuModule.isDown = OrigIsDown
		end
		if ui.screenGui then
			pcall(function() ui.screenGui:Destroy() end)
		end
		_G.GrowBlox = nil
	end,
}

print("[GrowBlox] Loaded v3. Break=" .. tostring(CONFIG.autoBreak)
	.. " Place=" .. tostring(CONFIG.autoPlace)
	.. " Plant=" .. tostring(CONFIG.autoPlant))
notify("GrowBlox v3", "Loaded. Break=" .. tostring(CONFIG.autoBreak and "ON" or "OFF") .. " Plant=" .. tostring(CONFIG.autoPlant and "ON" or "OFF"), 3)
