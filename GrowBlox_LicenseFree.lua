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
	local f = rawget(_G, name)
	if type(f) ~= "function" and type(getgenv) == "function" then
		pcall(function() f = getgenv()[name] end)
	end
	if type(f) == "function" then return f end
	return nil
end

local getgc = globalFn("getgc")
local getconsts = globalFn("getconstants") or (type(debug) == "table" and debug.getconstants) or nil

-- ===========================================================================
-- 1. Konfigurasi
-- ===========================================================================
local CONFIG = {
	autoBreak = true,
	autoPlace = false,
	autoPlant = true,

	-- Item untuk place dan tanam
	placeId = 20,      -- Dirt
	plantId = 696,     -- Dirt Seed

	range = 4,         -- jangkauan tile di sekitar pemain
	interval = 0.25,   -- jeda antar aksi (detik)
	mutePunch = true,
	breakBackground = false,
	walkSpeed = 16,
}

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
end

local function isStateHolder(v)
	local fn = rawget(v, "state")
	if type(fn) ~= "function" then return false end
	local ok, s = pcall(fn)
	return ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number"
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

local function scanRefs()
	if not getgc then
		return false
	end
	for _, v in ipairs(getgc(true)) do
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
		elseif type(v) == "function" then
			if not Refs.SetTile and hasConstPair(v, "placedAt", "flips") then
				Refs.SetTile = v
			end
			if not Refs.Punch and hasConstPair(v, "punch", "punch_miss") then
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
local function placeTile(layer, x, y, id)
	if not Refs.SetTile then return false end
	local ok, err = pcall(Refs.SetTile, layer, x, y, id, false, false)
	if ok then
		invRemove(id, 1)
		return true
	end
	warn("[GrowBlox] placeTile error: " .. tostring(err))
	return false
end

local function punchTile(x, y)
	if not Refs.Punch then return false end
	local ok, err = pcall(Refs.Punch, x, y, CONFIG.mutePunch or nil, nil)
	if not ok then
		warn("[GrowBlox] punch error: " .. tostring(err))
		return false
	end
	return true
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
-- 7. Loop utama
-- ===========================================================================
local running = { breakLoop = true, placeLoop = true, plantLoop = true }

local function startLoop(name, enabled, action)
	task.spawn(function()
		while running[name] do
			if enabled() then
				pcall(action)
			end
			task.wait(CONFIG.interval)
		end
	end)
end

startLoop("breakLoop", function() return CONFIG.autoBreak end, autoBreakOnce)
startLoop("placeLoop", function() return CONFIG.autoPlace end, autoPlaceOnce)
startLoop("plantLoop", function() return CONFIG.autoPlant end, autoPlantOnce)

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

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 180, 0, 158)
	frame.Position = UDim2.new(0.5, -90, 1, -162)
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
		frame.Size = v and UDim2.new(0, 180, 0, 158) or UDim2.new(0, 70, 0, 28)
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
