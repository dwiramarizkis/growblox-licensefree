-- GrowBlox license-free build
-- Fitur:
--   1. Auto Farm      : panen sugar cane otomatis + tanam seed otomatis
--   2. Auto Put/Break : hancurkan block + tempatkan block otomatis
--   3. Scanner        : daftar objek interaktif di sekitar
--   4. GUI            : WindUI bila tersedia, fallback GUI bawaan bila tidak
-- Tanpa key, HWID, account binding, atau server lisensi.

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

repeat task.wait() until game:IsLoaded()

-- ===========================================================================
-- 1. Anti-duplicate guard
-- ===========================================================================
if _G.HipHub_GrowBlox_Running then
	return
end
_G.HipHub_GrowBlox_Running = true

-- ===========================================================================
-- 2. Configuration
-- ===========================================================================
local CONFIG = {
	autoHarvest = true,
	autoPlant = false,
	autoBreak = false,
	autoPlace = false,

	range = 40,
	interactDistance = 16,
	arriveTimeout = 12,
	hitCount = 2,
	hitInterval = 0.4,
	pickupWait = 1.2,
	walkSpeed = 16,

	breakHits = 1,
	breakInterval = 0.4,
	placeWait = 0.4,

	-- Bila tidak ada target dengan nama cocok, jangan klik sembarangan.
	-- Aktifkan hanya jika kamu sudah yakin game memakai satu jenis ClickDetector.
	fallbackToAnyClick = false,

	-- Lower-case substrings matched against object names.
	sugarCaneNames = {
		"sugar cane",
		"sugarcane",
		"sugar_cane",
		"sugar",
		"cane",
		"tebu",
		"plant",
		"crop",
		"harvest",
	},
	plantSpotNames = {
		"plot",
		"soil",
		"dirt",
		"farm",
		"farmland",
		"field",
		"garden",
		"seedbed",
		"planter",
		"bed",
	},
	breakBlockNames = {
		"block",
		"brick",
		"stone",
		"rock",
		"ore",
		"wood",
		"log",
		"plank",
		"crate",
		"box",
		"hay",
		"grass",
		"flower",
		"tree",
	},
	placeSpotNames = {
		"slot",
		"pad",
		"base",
		"floor",
		"ground",
		"foundation",
		"grid",
		"cell",
		"placeholder",
		"build",
	},
}

-- ===========================================================================
-- 3. Character helpers
-- ===========================================================================
if not player.Character then
	player.CharacterAdded:Wait()
end

local function getCharacter()
	return player.Character
end

local function getRootPart()
	local character = getCharacter()
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local character = getCharacter()
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function setWalkSpeed(speed)
	local humanoid = getHumanoid()
	if humanoid then
		pcall(function()
			humanoid.WalkSpeed = speed
		end)
	end
end

local function walkTo(position)
	local humanoid = getHumanoid()
	if not humanoid then
		return false
	end
	local ok = pcall(function()
		humanoid:MoveTo(position)
	end)
	return ok
end

local function distanceTo(part)
	local root = getRootPart()
	if not root or not part then
		return math.huge
	end
	local ok, distance = pcall(function()
		return (part.Position - root.Position).Magnitude
	end)
	if ok then
		return distance
	end
	return math.huge
end

local function waitUntilNear(part, maxDistance)
	local waited = 0
	while waited < CONFIG.arriveTimeout do
		if distanceTo(part) <= maxDistance then
			return true
		end
		task.wait(0.25)
		waited += 0.25
	end
	return distanceTo(part) <= maxDistance
end

local function nameMatches(name, keywords)
	name = tostring(name):lower()
	for _, keyword in ipairs(keywords) do
		if name:find(keyword, 1, true) then
			return true
		end
	end
	return false
end

local function safeDestroy(instance)
	if instance and instance.Destroy then
		pcall(instance.Destroy, instance)
	end
end

local function notify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = tostring(title or "GrowBlox"),
			Text = tostring(text or ""),
			Duration = duration or 2,
		})
	end)
end

-- ===========================================================================
-- 4. Executor function resolution
-- ===========================================================================
local function getExecutorFunction(name)
	local ok, fn = pcall(function()
		local f = rawget(_G, name)
		if type(f) ~= "function" and type(getgenv) == "function" then
			f = getgenv()[name]
		end
		return f
	end)
	if ok and type(fn) == "function" then
		return fn
	end
	return nil
end

-- ===========================================================================
-- 5. Target scanning (detector-first)
-- ===========================================================================
local function isOwnedByPlayer(instance)
	local character = getCharacter()
	if character and instance:IsDescendantOf(character) then
		return true
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack and instance:IsDescendantOf(backpack) then
		return true
	end
	return false
end

local function getPartPosition(instance)
	if instance:IsA("BasePart") then
		return instance.Position
	end
	local part = instance:FindFirstChildWhichIsA("BasePart")
	if part then
		return part.Position
	end
	return nil
end

-- Cari target interaktif terdekat. Detector-nya yang dicari lebih dulu,
-- lalu nama dicocokkan ke detector, parent, dan grandparent.
local function findInteractable(keywords)
	local root = getRootPart()
	if not root then
		return nil
	end

	local center = root.Position
	local best = nil
	local bestDistance = math.huge

	for _, descendant in ipairs(workspace:GetDescendants()) do
		local ok = pcall(function()
			local isClick = descendant:IsA("ClickDetector")
			local isPrompt = descendant:IsA("ProximityPrompt")
			if not isClick and not isPrompt then
				return
			end

			local parent = descendant.Parent
			if not parent then
				return
			end

			if isOwnedByPlayer(descendant) then
				return
			end

			local matched = false
			if keywords then
				local names = {
					descendant.Name,
					parent.Name,
					parent.Parent and parent.Parent.Name,
				}
				for _, n in ipairs(names) do
					if nameMatches(n, keywords) then
						matched = true
						break
					end
				end
			else
				matched = true
			end

			if not matched then
				return
			end

			local targetPart
			if parent:IsA("BasePart") then
				targetPart = parent
			else
				targetPart = parent:FindFirstChildWhichIsA("BasePart")
			end

			local position = targetPart and targetPart.Position
			if not position then
				position = getPartPosition(parent)
			end
			if not position then
				return
			end

			local distance = (position - center).Magnitude
			if distance <= CONFIG.range and distance < bestDistance then
				bestDistance = distance
				best = {
					part = targetPart,
					name = parent.Name,
					className = parent.ClassName,
					distance = distance,
					clickDetector = isClick and descendant or nil,
					prompt = isPrompt and descendant or nil,
				}
			end
		end)
	end

	return best
end

local function findSugarCane()
	local target = findInteractable(CONFIG.sugarCaneNames)
	if target then
		return target
	end

	if CONFIG.fallbackToAnyClick then
		local any = findInteractable(nil)
		if any and any.clickDetector then
			return any
		end
	end

	return nil
end

local function findPlantSpot()
	return findInteractable(CONFIG.plantSpotNames)
end

local function findBreakBlock()
	return findInteractable(CONFIG.breakBlockNames)
end

local function findPlaceSpot()
	return findInteractable(CONFIG.placeSpotNames)
end

-- ===========================================================================
-- 6. Interaction helpers
-- ===========================================================================
local function fireClickDetector(clickDetector)
	if not clickDetector then
		return false
	end

	local fire = getExecutorFunction("fireclickdetector")
	if fire then
		local ok = pcall(fire, clickDetector)
		if ok then
			return true
		end
		ok = pcall(fire, clickDetector, 1)
		if ok then
			return true
		end
	end

	local fireSignal = getExecutorFunction("firesignal")
	if fireSignal then
		local ok = pcall(fireSignal, clickDetector.MouseClick)
		if ok then
			return true
		end
	end

	local fireTouch = getExecutorFunction("firetouchinterest")
	if fireTouch then
		local part = clickDetector.Parent
		if part and part:IsA("BasePart") then
			local root = getRootPart()
			local character = getCharacter()
			local touchers = { root, character }
			for _, toucher in ipairs(touchers) do
				if toucher then
					local ok = pcall(fireTouch, part, toucher, 0)
					if ok then
						return true
					end
					ok = pcall(fireTouch, part, toucher, 1)
					if ok then
						return true
					end
				end
			end
		end
	end

	return false
end

local function fireProximityPrompt(prompt)
	if not prompt then
		return false
	end

	local fire = getExecutorFunction("fireproximityprompt")
	if fire then
		local ok = pcall(fire, prompt)
		if ok then
			return true
		end
	end

	local fireSignal = getExecutorFunction("firesignal")
	if fireSignal then
		local ok = pcall(fireSignal, prompt.Triggered)
		if ok then
			return true
		end
	end

	if prompt.InputHoldBegin and prompt.InputHoldEnd then
		pcall(prompt.InputHoldBegin, prompt)
		task.wait(0.08)
		pcall(prompt.InputHoldEnd, prompt)
		return true
	end

	return false
end

local function interactWithTarget(target)
	if target.clickDetector then
		if fireClickDetector(target.clickDetector) then
			return true
		end
	end
	if target.prompt then
		if fireProximityPrompt(target.prompt) then
			return true
		end
	end
	return false
end

-- ===========================================================================
-- 7. Farm actions
-- ===========================================================================
local function harvestSugarCane()
	local target = findSugarCane()
	if not target then
		return 0, "no target"
	end

	local part = target.part or target.clickDetector and target.clickDetector.Parent
	if not part or not part:IsA("BasePart") then
		return 0, "target has no part"
	end

	setWalkSpeed(CONFIG.walkSpeed)
	walkTo(part.Position)
	if not waitUntilNear(part, CONFIG.interactDistance) then
		return 0, "target too far"
	end

	local hits = 0
	for i = 1, CONFIG.hitCount do
		if not part.Parent then
			break
		end
		if interactWithTarget(target) then
			hits += 1
		end
		if i < CONFIG.hitCount then
			task.wait(CONFIG.hitInterval)
		end
	end

	if hits == 0 then
		return 0, "click failed"
	end

	task.wait(CONFIG.pickupWait)
	return hits, "ok"
end

local function plantSeed()
	local target = findPlantSpot()
	if not target then
		return 0, "no plant spot"
	end

	local part = target.part or target.prompt and target.prompt.Parent
	if not part or not part:IsA("BasePart") then
		return 0, "target has no part"
	end

	setWalkSpeed(CONFIG.walkSpeed)
	walkTo(part.Position)
	if not waitUntilNear(part, CONFIG.interactDistance) then
		return 0, "target too far"
	end

	if interactWithTarget(target) then
		task.wait(CONFIG.placeWait)
		return 1, "ok"
	end

	return 0, "interact failed"
end

local function breakBlock()
	local target = findBreakBlock()
	if not target then
		return 0, "no break block"
	end

	local part = target.part or target.clickDetector and target.clickDetector.Parent
	if not part or not part:IsA("BasePart") then
		return 0, "target has no part"
	end

	setWalkSpeed(CONFIG.walkSpeed)
	walkTo(part.Position)
	if not waitUntilNear(part, CONFIG.interactDistance) then
		return 0, "target too far"
	end

	local hits = 0
	for i = 1, CONFIG.breakHits do
		if not part.Parent then
			break
		end
		if interactWithTarget(target) then
			hits += 1
		end
		if i < CONFIG.breakHits then
			task.wait(CONFIG.breakInterval)
		end
	end

	if hits == 0 then
		return 0, "break interact failed"
	end

	task.wait(CONFIG.pickupWait)
	return hits, "ok"
end

local function placeBlock()
	local target = findPlaceSpot()
	if not target then
		return 0, "no place spot"
	end

	local part = target.part or target.prompt and target.prompt.Parent
	if not part or not part:IsA("BasePart") then
		return 0, "target has no part"
	end

	setWalkSpeed(CONFIG.walkSpeed)
	walkTo(part.Position)
	if not waitUntilNear(part, CONFIG.interactDistance) then
		return 0, "target too far"
	end

	if interactWithTarget(target) then
		task.wait(CONFIG.placeWait)
		return 1, "ok"
	end

	return 0, "place interact failed"
end

-- ===========================================================================
-- 8. Loops
-- ===========================================================================
local loopRunning = {
	harvest = true,
	plant = true,
	breakBlocks = true,
	placeBlocks = true,
}

local function startLoop(name, enabled, action)
	task.spawn(function()
		while loopRunning[name] do
			if enabled() then
				local ok, err = pcall(action)
				if not ok then
					warn("[GrowBlox] " .. name .. " error: " .. tostring(err))
				end
			end
			task.wait(0.5)
		end
	end)
end

startLoop("harvest", function() return CONFIG.autoHarvest end, harvestSugarCane)
startLoop("plant", function() return CONFIG.autoPlant end, plantSeed)
startLoop("breakBlocks", function() return CONFIG.autoBreak end, breakBlock)
startLoop("placeBlocks", function() return CONFIG.autoPlace end, placeBlock)

-- ===========================================================================
-- 9. Scanner
-- ===========================================================================
local function scanNearby(radius)
	local root = getRootPart()
	if not root then
		warn("[GrowBlox] Character not found.")
		return {}
	end

	local center = root.Position
	local found = {}

	for _, descendant in ipairs(workspace:GetDescendants()) do
		local ok = pcall(function()
			local isClick = descendant:IsA("ClickDetector")
			local isPrompt = descendant:IsA("ProximityPrompt")
			if not isClick and not isPrompt then
				return
			end

			local parent = descendant.Parent
			if not parent then
				return
			end

			local part
			if parent:IsA("BasePart") then
				part = parent
			else
				part = parent:FindFirstChildWhichIsA("BasePart")
			end

			local position = part and part.Position
			if not position then
				return
			end

			local distance = (position - center).Magnitude
			if distance <= radius then
				table.insert(found, {
					name = parent.Name,
					className = parent.ClassName,
					detector = isClick and "ClickDetector" or "ProximityPrompt",
					distance = math.floor(distance),
				})
			end
		end)
	end

	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)

	return found
end

local function printScan(radius)
	local found = scanNearby(radius)
	warn("[GrowBlox] Scanner: " .. #found .. " interactables within " .. radius .. " studs")
	for i, entry in ipairs(found) do
		if i > 50 then
			warn("[GrowBlox] ... " .. (#found - 50) .. " more (use _G.GrowBlox.scan(radius) for full list)")
			break
		end
		warn(string.format(
			"[GrowBlox] %d. [%s] %s (%d studs) via %s",
			i,
			entry.className,
			entry.name,
			entry.distance,
			entry.detector
		))
	end
	return found
end

-- ===========================================================================
-- 10. UI (WindUI + fallback)
-- ===========================================================================
local function createWindUi()
	local windUi = loadstring(game:HttpGet(
		"https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"
	))()

	local window = windUi:CreateWindow({
		Title = "GrowBlox",
		Folder = "GrowBlox",
		Icon = "solar:folder-2-bold-duotone",
		NewElements = true,
		OpenButton = {
			Title = "Open GrowBlox",
			Enabled = true,
			Draggable = true,
		},
	})

	local farmTab = window:Tab({
		Title = "Auto Farm",
		Desc = "Sugar cane auto farm",
		Icon = "solar:home-2-bold",
	})

	local putTab = window:Tab({
		Title = "Auto Put/Break",
		Desc = "Break and place blocks",
		Icon = "solar:home-2-bold",
	})

	local scanTab = window:Tab({
		Title = "Scanner",
		Desc = "Find nearby object names",
		Icon = "solar:home-2-bold",
	})

	farmTab:Toggle({
		Title = "Auto Harvest",
		Desc = "Break sugar cane with 2 hits",
		Value = CONFIG.autoHarvest,
		Callback = function(state)
			CONFIG.autoHarvest = state
			notify("Auto Harvest", state and "ON" or "OFF", 1.5)
		end,
	})

	farmTab:Toggle({
		Title = "Auto Plant",
		Desc = "Plant seed on empty plot",
		Value = CONFIG.autoPlant,
		Callback = function(state)
			CONFIG.autoPlant = state
			notify("Auto Plant", state and "ON" or "OFF", 1.5)
		end,
	})

	farmTab:Slider({
		Title = "Range",
		Desc = "Search radius (studs)",
		Step = 1,
		Value = {
			Min = 5,
			Max = 100,
			Default = CONFIG.range,
		},
		Callback = function(value)
			CONFIG.range = value
		end,
	})

	farmTab:Slider({
		Title = "Interact Distance",
		Desc = "Walk until this close (studs)",
		Step = 1,
		Value = {
			Min = 5,
			Max = 30,
			Default = CONFIG.interactDistance,
		},
		Callback = function(value)
			CONFIG.interactDistance = value
		end,
	})

	farmTab:Slider({
		Title = "Hit Interval",
		Desc = "Delay between 2 hits (seconds)",
		Step = 0.1,
		Value = {
			Min = 0.1,
			Max = 2,
			Default = CONFIG.hitInterval,
		},
		Callback = function(value)
			CONFIG.hitInterval = value
		end,
	})

	putTab:Toggle({
		Title = "Auto Break",
		Desc = "Break nearby breakable blocks",
		Value = CONFIG.autoBreak,
		Callback = function(state)
			CONFIG.autoBreak = state
			notify("Auto Break", state and "ON" or "OFF", 1.5)
		end,
	})

	putTab:Toggle({
		Title = "Auto Place",
		Desc = "Place block on empty spot",
		Value = CONFIG.autoPlace,
		Callback = function(state)
			CONFIG.autoPlace = state
			notify("Auto Place", state and "ON" or "OFF", 1.5)
		end,
	})

	putTab:Slider({
		Title = "Break Hits",
		Desc = "Hits needed to break a block",
		Step = 1,
		Value = {
			Min = 1,
			Max = 10,
			Default = CONFIG.breakHits,
		},
		Callback = function(value)
			CONFIG.breakHits = value
		end,
	})

	putTab:Slider({
		Title = "Break Interval",
		Desc = "Delay between break hits (seconds)",
		Step = 0.1,
		Value = {
			Min = 0.1,
			Max = 2,
			Default = CONFIG.breakInterval,
		},
		Callback = function(value)
			CONFIG.breakInterval = value
		end,
	})

	putTab:Slider({
		Title = "Place Delay",
		Desc = "Wait after placing (seconds)",
		Step = 0.1,
		Value = {
			Min = 0.1,
			Max = 2,
			Default = CONFIG.placeWait,
		},
		Callback = function(value)
			CONFIG.placeWait = value
		end,
	})

	scanTab:Button({
		Title = "Scan Nearby (30 studs)",
		Desc = "Print object names to console",
		Justify = "Center",
		Callback = function()
			printScan(30)
		end,
	})

	scanTab:Button({
		Title = "Scan Wide (100 studs)",
		Desc = "Print more object names",
		Justify = "Center",
		Callback = function()
			printScan(100)
		end,
	})

	return {
		lib = windUi,
		window = window,
		screenGui = windUi.ScreenGui,
	}
end

local function createFallbackUi()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HipHub_GrowBlox"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	pcall(function()
		local parent
		if type(gethui) == "function" then
			parent = gethui()
		end
		if not parent then
			parent = player:WaitForChild("PlayerGui")
		end
		screenGui.Parent = parent
	end)

	local frame = Instance.new("Frame")
	frame.Name = "Main"
	frame.Size = UDim2.new(0, 230, 0, 246)
	frame.Position = UDim2.new(0, 10, 0.5, -123)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 44)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 10)
	frameCorner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 30)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "GrowBlox (License-Free)"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local function addToggleButton(buttonName, configKey, y)
		local button = Instance.new("TextButton")
		button.Name = configKey
		button.Size = UDim2.new(1, -20, 0, 34)
		button.Position = UDim2.new(0, 10, 0, y)
		button.BackgroundColor3 = Color3.fromRGB(30, 36, 60)
		button.BorderSizePixel = 0
		button.Text = buttonName .. ": " .. (CONFIG[configKey] and "ON" or "OFF")
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 13
		button.AutoButtonColor = true
		button.Parent = frame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			CONFIG[configKey] = not CONFIG[configKey]
			button.Text = buttonName .. ": " .. (CONFIG[configKey] and "ON" or "OFF")
			notify(buttonName, CONFIG[configKey] and "ON" or "OFF", 1.5)
		end)
	end

	addToggleButton("Auto Harvest", "autoHarvest", 44)
	addToggleButton("Auto Plant", "autoPlant", 84)
	addToggleButton("Auto Break", "autoBreak", 124)
	addToggleButton("Auto Place", "autoPlace", 164)

	local scanButton = Instance.new("TextButton")
	scanButton.Size = UDim2.new(1, -20, 0, 34)
	scanButton.Position = UDim2.new(0, 10, 0, 204)
	scanButton.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
	scanButton.BorderSizePixel = 0
	scanButton.Text = "SCAN NEARBY (30)"
	scanButton.TextColor3 = Color3.fromRGB(0, 0, 0)
	scanButton.Font = Enum.Font.GothamBold
	scanButton.TextSize = 13
	scanButton.Parent = frame

	local scanCorner = Instance.new("UICorner")
	scanCorner.CornerRadius = UDim.new(0, 6)
	scanCorner.Parent = scanButton

	scanButton.MouseButton1Click:Connect(function()
		printScan(30)
	end)

	return {
		lib = nil,
		window = nil,
		screenGui = screenGui,
	}
end

-- ===========================================================================
-- 11. Error boundary
-- ===========================================================================
local uiOk, uiHandle = pcall(createWindUi)
if not uiOk then
	warn("[GrowBlox] WindUI failed (" .. tostring(uiHandle) .. "), using built-in fallback UI")
	uiOk, uiHandle = pcall(createFallbackUi)
	if not uiOk then
		warn("[GrowBlox] Fallback UI also failed: " .. tostring(uiHandle))
		uiHandle = nil
	end
end

-- ===========================================================================
-- 12. Startup report
-- ===========================================================================
task.spawn(function()
	task.wait(2)
	local cane = findSugarCane()
	local spot = findPlantSpot()
	local block = findBreakBlock()
	local place = findPlaceSpot()

	warn(string.format(
		"[GrowBlox] Detected -> cane: %s | plant: %s | break: %s | place: %s",
		cane and ("\"" .. cane.name .. "\"") or "none",
		spot and ("\"" .. spot.name .. "\"") or "none",
		block and ("\"" .. block.name .. "\"") or "none",
		place and ("\"" .. place.name .. "\"") or "none"
	))

	notify(
		"GrowBlox Loaded",
		"Cane: " .. (cane and cane.name or "none")
			.. " | Plant: " .. (spot and spot.name or "none")
			.. " | Break: " .. (block and block.name or "none")
			.. " | Place: " .. (place and place.name or "none"),
		5
	)
end)

-- ===========================================================================
-- 13. Public test/debug API
-- ===========================================================================
_G.GrowBlox = {
	config = CONFIG,
	harvestNow = harvestSugarCane,
	plantNow = plantSeed,
	breakNow = breakBlock,
	placeNow = placeBlock,
	scan = scanNearby,
	printScan = printScan,
	findSugarCane = findSugarCane,
	findPlantSpot = findPlantSpot,
	findBreakBlock = findBreakBlock,
	findPlaceSpot = findPlaceSpot,
	getUi = function()
		return uiHandle and uiHandle.screenGui
	end,
	destroy = function()
		if uiHandle and uiHandle.screenGui then
			safeDestroy(uiHandle.screenGui)
		end
		loopRunning.harvest = false
		loopRunning.plant = false
		loopRunning.breakBlocks = false
		loopRunning.placeBlocks = false
		_G.HipHub_GrowBlox_Running = nil
		_G.GrowBlox = nil
	end,
}
