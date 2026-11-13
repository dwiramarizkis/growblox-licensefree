-- GrowBlox License-Free v2
-- Dibangun dari data asli game Growblox (bukan tebakan):
--   - World grid : world.fg[y][x], world.bg[y][x]
--   - State      : state().x, state().y, state().facing
--   - Inventory  : inv.slots = { {id=..., n=...}, ... }, inv:remove(id, n)
--   - Place      : SetTile("fg"/"bg", x, y, id, false, false)
--   - Punch      : Punch(x, y, mute, nil)
--   - Item ID    : 20 = Dirt, 696 = Dirt Seed, 2 = Lava Seed, 5 = Rock Seed
-- Tanpa key, HWID, akun, atau server lisensi.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

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
local getconsts = globalFn("getconstants")
if not getconsts and type(debug) == "table" then
	pcall(function() getconsts = debug.getconstants end)
end

print("[GrowBlox] executor: getgc=" .. tostring(getgc ~= nil) .. " getconstants=" .. tostring(getconsts ~= nil))

-- Modul game (fallback aman; tidak pakai WaitForChild yang bisa infinite yield)
local Shared = ReplicatedStorage:FindFirstChild("Shared")
local WorldRemotes = ReplicatedStorage:FindFirstChild("WorldRemotes")
local SetTileRemote = WorldRemotes and WorldRemotes:FindFirstChild("SetTile")

local ItemDB = nil
local InventoryModule = nil
local NetOk, Net = false, nil

if Shared then
	pcall(function()
		ItemDB = require(Shared:FindFirstChild("ItemDB"))
	end)
	pcall(function()
		InventoryModule = require(Shared:FindFirstChild("Inventory"))
	end)
	pcall(function()
		NetOk, Net = pcall(require, Shared:FindFirstChild("Net"))
	end)
end

-- Kalau Shared belum ada, coba sekali dengan timeout 10 detik
if not Shared then
	local waited = 0
	while waited < 10 do
		Shared = ReplicatedStorage:FindFirstChild("Shared")
		if Shared then break end
		task.wait(0.5)
		waited += 0.5
	end
	if Shared then
		pcall(function()
			ItemDB = require(Shared:FindFirstChild("ItemDB"))
		end)
		pcall(function()
			InventoryModule = require(Shared:FindFirstChild("Inventory"))
		end)
		pcall(function()
			NetOk, Net = pcall(require, Shared:FindFirstChild("Net"))
		end)
	end
end

-- ===========================================================================
-- 1. Konfigurasi
-- ===========================================================================
local CONFIG = {
	autoBreak = true,
	autoPlace = false,
	autoPlant = true,
	pnbEnabled = false,  -- Place 'n Break grid mode

	-- Item untuk place dan tanam
	placeId = 20,      -- Dirt
	plantId = 696,     -- Dirt Seed

	range = 4,         -- jangkauan tile di sekitar pemain
	interval = 0.25,   -- jeda antar aksi (detik)
	mutePunch = true,
	breakBackground = false,
	walkSpeed = 16,

	-- Grid PNB
	gridSize = 5,           -- 5x5 di sekitar pemain
	pnbInterval = 0.15,     -- jeda antar aksi PNB
	pnbBreakOccupied = true,  -- pecahkan tile terisi di sel terpilih
	pnbPlaceEmpty = true,     -- isi tile kosong di sel terpilih
}

-- Sel grid terpilih: map "x,y" -> true
local selectedTiles = {}
local gridTiles = {}   -- cache posisi grid terakhir

-- ===========================================================================
-- 2. Temukan referensi game (sekali jalan, pola terbukti)
-- ===========================================================================
local Refs = {
	World = nil,   -- tabel {fg=..., bg=..., w=..., h=...}
	State = nil,   -- fungsi () -> {x, y, facing, ...}
	Inv = nil,     -- tabel {slots=..., count=fn, remove=fn}
	SetTile = nil, -- fungsi (layer, x, y, id, flip, ...)
	Punch = nil,   -- fungsi (x, y, mute, ...)
}

local function isWorldTbl(v)
	return type(rawget(v, "fg")) == "table" and type(rawget(v, "bg")) == "table"
		and type(rawget(v, "w")) == "number" and type(rawget(v, "h")) == "number"
		and rawget(v, "spawn") ~= nil
end

local function isInvTbl(v)
	return type(rawget(v, "slots")) == "table"
		and (rawget(v, "capacity") ~= nil or type(rawget(v, "count")) == "function")
		and (not InventoryModule or getmetatable(v) == InventoryModule)
end

local function isStateHolder(v)
	local fn = rawget(v, "state")
	if type(fn) ~= "function" then return false end
	local ok, s = pcall(fn)
	return ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number"
		and s.facing ~= nil and s.vx ~= nil
end

local function constsOf(fn)
	if not getconsts then return nil end
	local ok, c = pcall(getconsts, fn)
	if ok and type(c) == "table" then return c end
	return nil
end

local function hasConst(fn, target)
	local c = constsOf(fn)
	if not c then return false end
	for _, v in ipairs(c) do
		if v == target then return true end
	end
	return false
end

local function hasConstPair(fn, a, b)
	local c = constsOf(fn)
	if not c then return false end
	local ha, hb = false, false
	for _, v in ipairs(c) do
		if v == a then ha = true end
		if v == b then hb = true end
		if ha and hb then return true end
	end
	return false
end

-- Persis pola k.lua: SetTile = konstanta "placedAt" + "flips";
-- fallback ByteNet = konstanta "tile" + "placedAt" + "flips".
local function isSetTileFn(fn)
	if not getconsts then return false end
	if globalFn("islclosure") and not globalFn("islclosure")(fn) then return false end
	local ok, consts = pcall(getconsts, fn)
	if not ok or type(consts) ~= "table" then return false end
	local hasSend, hasPlaced, hasFlips = false, false, false
	for _, c in pairs(consts) do
		if c == "tile" or c == "SetTile" then hasSend = true
		elseif c == "placedAt" then hasPlaced = true
		elseif c == "flips" then hasFlips = true end
	end
	return hasSend and hasPlaced and hasFlips
end

-- Persis pola k.lua: Punch = "Empty the Vending Machine first!" + ("newCrack" atau "HarvestProvider")
local function isPunchFn(fn)
	if not getconsts then return false end
	if globalFn("islclosure") and not globalFn("islclosure")(fn) then return false end
	local ok, consts = pcall(getconsts, fn)
	if not ok or type(consts) ~= "table" then return false end
	local hasVend, hasMark = false, false
	for _, c in pairs(consts) do
		if c == "Empty the Vending Machine first!" then hasVend = true
		elseif c == "newCrack" or c == "HarvestProvider" then hasMark = true end
	end
	return hasVend and hasMark
end

-- Pastikan fungsi milik game, bukan script ini (persis k.lua)
local function isGameFn(fn)
	if fn == isSetTileFn or fn == isPunchFn then return false end
	local isExecClosure = globalFn("isexecutorclosure")
	if isExecClosure then
		local ok, res = pcall(isExecClosure, fn)
		if ok and res then return false end
	end
	if type(debug) == "table" and debug.info then
		local ok, src = pcall(debug.info, fn, "s")
		if ok and type(src) == "string" and src ~= "" and not string.find(src, "GrowBlox", 1, true) then
			return false
		end
	end
	return true
end

local function scanRefs()
	if not getgc then
		print("[GrowBlox] scanRefs: getgc nil")
		return false
	end
	local okList, all = pcall(getgc, true)
	if not okList or type(all) ~= "table" then
		print("[GrowBlox] scanRefs: getgc(true) gagal: " .. tostring(all))
		return false
	end
	print("[GrowBlox] scanRefs: getgc objects=" .. tostring(#all))
	for _, v in ipairs(all) do
		if type(v) == "table" then
			if not Refs.World then
				local ok, isW = pcall(isWorldTbl, v)
				if ok and isW then Refs.World = v end
			end
			if not Refs.Inv then
				local ok, isI = pcall(isInvTbl, v)
				if ok and isI then Refs.Inv = v end
			end
			if not Refs.State then
				local ok, isS = pcall(isStateHolder, v)
				if ok and isS then Refs.State = rawget(v, "state") end
			end
		elseif type(v) == "function" and (not Refs.SetTile or not Refs.Punch) and isGameFn(v) then
			if not Refs.SetTile and isSetTileFn(v) then
				Refs.SetTile = v
			elseif not Refs.Punch and isPunchFn(v) then
				Refs.Punch = v
			end
		end
		if Refs.World and Refs.Inv and Refs.State and Refs.SetTile and Refs.Punch then
			break
		end
	end
	return Refs.World ~= nil
end

local refsOk = scanRefs()
print("[GrowBlox] refs: world=" .. tostring(Refs.World ~= nil)
	.. " state=" .. tostring(Refs.State ~= nil)
	.. " inv=" .. tostring(Refs.Inv ~= nil)
	.. " settile=" .. tostring(Refs.SetTile ~= nil)
	.. " punch=" .. tostring(Refs.Punch ~= nil))

-- ===========================================================================
-- 3. Helper data game
-- ===========================================================================
local function getState()
	if not Refs.State then return nil end
	local ok, s = pcall(Refs.State)
	if ok and type(s) == "table" and type(s.x) == "number" then
		return s
	end
	return nil
end

local function tileAt(layer, x, y)
	local w = Refs.World
	if not w or x < 0 or y < 0 or x >= w.w or y >= w.h then return nil end
	local grid = w[layer]
	local row = grid and grid[y]
	return row and (row[x] or 0) or nil
end

local function getPlayerTile()
	local s = getState()
	if not s then return nil end
	return math.floor(s.x + 0.5), math.floor(s.y - 0.475 + 0.5)
end

local function invCount(id)
	if not Refs.Inv then return 0 end
	for _, slot in ipairs(Refs.Inv.slots or {}) do
		if type(slot) == "table" and slot.id == id then
			return slot.n or 0
		end
	end
	return 0
end

local function invRemove(id, n)
	if not Refs.Inv then return false end
	if type(Refs.Inv.remove) == "function" then
		local ok = pcall(function()
			Refs.Inv:remove(id, n or 1)
		end)
		return ok
	end
	return false
end

-- ===========================================================================
-- 4. Aksi dasar game
-- ===========================================================================
-- Sama persis dengan k.lua: SetTile dulu, fallback ByteNet, fallback remote lama.
local function sendSetTile(layer, x, y, id)
	if Refs.SetTile then
		local ok, err = pcall(Refs.SetTile, layer, x, y, id, false, false)
		if ok then return true end
		warn("[GrowBlox] setTile game gagal: " .. tostring(err))
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
		pcall(function()
			SetTileRemote:FireServer(layer, x, y, id, false)
		end)
		return true
	end
	return false
end

local function placeTile(layer, x, y, id)
	if not sendSetTile(layer, x, y, id) then
		return false
	end
	-- Update grid lokal + inventory (sama seperti k.lua)
	local grid = Refs.World and Refs.World[layer]
	if grid and grid[y] then
		grid[y][x] = id
	end
	invRemove(id, 1)
	return true
end

local function punchTile(x, y)
	if Refs.Punch then
		local ok, err = pcall(Refs.Punch, x, y, CONFIG.mutePunch or nil, nil)
		if not ok then
			warn("[GrowBlox] punch error: " .. tostring(err))
			return false
		end
		return true
	end
	-- Fallback: hapus tile langsung (hanya kalau game mengizinkan)
	warn("[GrowBlox] Punch tidak ketemu, fallback setTile 0")
	return sendSetTile("fg", x, y, 0)
end

local function breakable(id)
	return id ~= 0 and id ~= nil
end

-- ===========================================================================
-- 5. Scan tile di sekitar pemain
-- ===========================================================================
local function tilesAround(px, py, radius)
	local out = {}
	if not Refs.World then return out end
	for y = py - radius, py + radius do
		for x = px - radius, px + radius do
			local fg = tileAt("fg", x, y)
			local bg = tileAt("bg", x, y)
			if fg ~= nil then
				out[#out + 1] = {
					x = x,
					y = y,
					fg = fg,
					bg = bg,
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

-- ===========================================================================
-- 6. Aksi farming
-- ===========================================================================
local function autoBreakOnce()
	local px, py = getPlayerTile()
	if not px then return false, "no state" end
	local target = nil
	for _, t in ipairs(tilesAround(px, py, CONFIG.range)) do
		if t.fg ~= 0 and breakable(t.fg) then
			target = t
			break
		end
		if CONFIG.breakBackground and t.bg ~= 0 and breakable(t.bg) then
			target = t
			break
		end
	end
	if not target then return false, "no breakable" end
	local ok = punchTile(target.x, target.y)
	return ok, ok and ("punch " .. target.x .. "," .. target.y) or "punch failed"
end

local function autoPlaceOnce()
	local px, py = getPlayerTile()
	if not px then return false, "no state" end
	local target = nil
	for _, t in ipairs(tilesAround(px, py, CONFIG.range)) do
		if t.fg == 0 then
			target = t
			break
		end
	end
	if not target then return false, "no empty tile" end
	if invCount(CONFIG.placeId) <= 0 then return false, "no block" end
	local ok = placeTile("fg", target.x, target.y, CONFIG.placeId)
	return ok, ok and ("place " .. target.x .. "," .. target.y) or "place failed"
end

local function autoPlantOnce()
	local px, py = getPlayerTile()
	if not px then return false, "no state" end
	local target = nil
	for _, t in ipairs(tilesAround(px, py, CONFIG.range)) do
		if t.fg == 0 then
			target = t
			break
		end
	end
	if not target then return false, "no empty tile" end
	if invCount(CONFIG.plantId) <= 0 then return false, "no seed" end
	local ok = placeTile("fg", target.x, target.y, CONFIG.plantId)
	return ok, ok and ("plant " .. target.x .. "," .. target.y) or "plant failed"
end

-- ===========================================================================
-- 6b. Place 'n Break grid mode
-- ===========================================================================
local function pnbTick()
	if not CONFIG.pnbEnabled then
		return false, "pnb off"
	end

	local px, py = getPlayerTile()
	if not px then return false, "no state" end

	-- Refresh cache grid
	gridTiles = {}
	for y = py - CONFIG.gridSize, py + CONFIG.gridSize do
		for x = px - CONFIG.gridSize, px + CONFIG.gridSize do
			local fg = tileAt("fg", x, y)
			local bg = tileAt("bg", x, y)
			if fg ~= nil then
				gridTiles[#gridTiles + 1] = { x = x, y = y, fg = fg, bg = bg }
			end
		end
	end

	-- Eksekusi pada sel terpilih saja
	for _, t in ipairs(gridTiles) do
		if selectedTiles[t.x .. "," .. t.y] then
			if t.fg ~= 0 and CONFIG.pnbBreakOccupied then
				local ok = punchTile(t.x, t.y)
				if ok then
					return true, "pnb break " .. t.x .. "," .. t.y
				end
			elseif t.fg == 0 and CONFIG.pnbPlaceEmpty then
				if invCount(CONFIG.placeId) > 0 then
					local ok = placeTile("fg", t.x, t.y, CONFIG.placeId)
					if ok then
						return true, "pnb place " .. t.x .. "," .. t.y
					end
				else
					return false, "no block"
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
-- 7. Loop utama
-- ===========================================================================
local running = { breakLoop = true, placeLoop = true, plantLoop = true, pnbLoop = true }

local function startLoop(name, enabled, action, waitTime)
	task.spawn(function()
		while running[name] do
			if enabled() then
				pcall(action)
			end
			task.wait(waitTime or CONFIG.interval)
		end
	end)
end

startLoop("breakLoop", function() return CONFIG.autoBreak and not CONFIG.pnbEnabled end, autoBreakOnce)
startLoop("placeLoop", function() return CONFIG.autoPlace and not CONFIG.pnbEnabled end, autoPlaceOnce)
startLoop("plantLoop", function() return CONFIG.autoPlant and not CONFIG.pnbEnabled end, autoPlantOnce)
startLoop("pnbLoop", function() return CONFIG.pnbEnabled end, pnbTick, CONFIG.pnbInterval)

-- ===========================================================================
-- 8. GUI kecil (tidak menghalangi)
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

	-- Frame utama (kolom tombol)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 180, 0, 210)
	frame.Position = UDim2.new(0.5, -90, 1, -214)
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
		frame.Size = v and UDim2.new(0, 180, 0, 210) or UDim2.new(0, 70, 0, 28)
		for _, child in ipairs(frame:GetChildren()) do
			if child ~= title and child ~= hideBtn then
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

	-- Tombol buka grid PNB
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

	-- =====================================================================
	-- Panel Grid PNB (5x5) terpisah, bisa digeser
	-- =====================================================================
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

	gpClear.MouseButton1Click:Connect(function()
		clearTileSelection()
	end)

	-- Grid 5x5 tombol
	local gridButtons = {}
	local cellSize = 32
	for row = 0, 4 do
		for col = 0, 4 do
			local cell = Instance.new("TextButton")
			cell.Size = UDim2.new(0, cellSize, 0, cellSize)
			cell.Position = UDim2.new(0, 8 + col * (cellSize + 2), 0, 52 + row * (cellSize + 2))
			cell.BackgroundColor3 = Color3.fromRGB(30, 36, 60)
			cell.BorderSizePixel = 0
			cell.Text = "?"
			cell.TextColor3 = Color3.fromRGB(255, 255, 255)
			cell.Font = Enum.Font.GothamBold
			cell.TextSize = 9
			cell.Parent = gridPanel

			local cCorner = Instance.new("UICorner")
			cCorner.CornerRadius = UDim.new(0, 4)
			cCorner.Parent = cell

			gridButtons[(row * 5) + col + 1] = cell
		end
	end

	-- Perbarui tampilan grid tiap 0.3 detik
	task.spawn(function()
		while true do
			task.wait(0.3)
			if not gridPanel.Visible then continue end

			local px, py = getPlayerTile()
			local selectedCount = 0
			for key in pairs(selectedTiles) do
				selectedCount += 1
			end
			gpInfo.Text = "Terpilih: " .. selectedCount .. " | Posisi: " .. (px and (px .. "," .. py) or "?")

			if px then
				local half = math.floor(CONFIG.gridSize / 2)
				local idx = 1
				for row = 0, 4 do
					for col = 0, 4 do
						local tx = px - half + col
						local ty = py - half + row
						local cell = gridButtons[idx]
						idx += 1
						if cell then
							local fg = tileAt("fg", tx, ty)
							local selected = selectedTiles[tx .. "," .. ty] == true
							if selected then
								cell.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
							elseif fg ~= 0 then
								cell.BackgroundColor3 = Color3.fromRGB(80, 60, 30)
							else
								cell.BackgroundColor3 = Color3.fromRGB(30, 36, 60)
							end
							cell.Text = (fg == 0 and "0" or tostring(fg))
						end
					end
				end
			end
		end
	end)

	-- Klik sel grid: toggle pilih
	for idx, cell in ipairs(gridButtons) do
		cell.MouseButton1Click:Connect(function()
			local px, py = getPlayerTile()
			if not px then return end
			local half = math.floor(CONFIG.gridSize / 2)
			local row = math.floor((idx - 1) / 5)
			local col = (idx - 1) % 5
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
-- 9. API publik
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
	getState = getState,
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
		if ui.screenGui then
			pcall(function() ui.screenGui:Destroy() end)
		end
		_G.GrowBlox = nil
	end,
}

print("[GrowBlox] Loaded. AutoBreak=" .. tostring(CONFIG.autoBreak)
	.. " AutoPlace=" .. tostring(CONFIG.autoPlace)
	.. " AutoPlant=" .. tostring(CONFIG.autoPlant))
notify("GrowBlox", "Loaded. Break=" .. tostring(CONFIG.autoBreak and "ON" or "OFF") .. " Plant=" .. tostring(CONFIG.autoPlant and "ON" or "OFF"), 3)
