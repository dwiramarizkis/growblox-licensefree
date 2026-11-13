-- GrowBlox Probe (cari fungsi game + hook untuk rekam aksi manual)
-- Jalankan SETELAH masuk world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_Probe.lua"))()
--
-- Langkah:
--   1. Jalankan script ini.
--   2. Lakukan manual di game: pukul/pecah 1-2 tile, tanam 1 seed, panen 1 pohon.
--   3. Lihat console/output -> kirim hasilnya.
-- Script ini TIDAK melakukan aksi apa pun, hanya memasang hook + scan.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local lines = {}
local function add(k, v)
	v = tostring(v)
	lines[#lines + 1] = k .. ": " .. v
	print("[Probe] " .. k .. ": " .. v)
end

local function globalFn(name)
	local f = rawget(_G, name)
	if type(f) ~= "function" and type(getgenv) == "function" then
		pcall(function() f = getgenv()[name] end)
	end
	if type(f) == "function" then return f end
	return nil
end

local getgc = globalFn("getgc")
local getconsts = globalFn("getconstants") or (debug and debug.getconstants)
local getupval = globalFn("getupvalue") or (debug and debug.getupvalue)
local getinfo = globalFn("getinfo") or (debug and debug.getinfo)
local hookfn = globalFn("hookfunction")

-- ---------------------------------------------------------------------------
-- 1. Status
-- ---------------------------------------------------------------------------
add("PlaceId", tostring(game.PlaceId))
add("Player", tostring(player and player.Name))
add("Character", player and player.Character and "ADA" or "TIDAK ADA (game tidak pakai Character Roblox)")
add("getgc", getgc and "ADA" or "TIDAK")
add("getconstants", getconsts and "ADA" or "TIDAK")
add("hookfunction", hookfn and "ADA" or "TIDAK")

-- ---------------------------------------------------------------------------
-- 2. Workspace (tanpa Character)
-- ---------------------------------------------------------------------------
local wsChildren = workspace:GetChildren()
local baseParts = {}
local allDes = workspace:GetDescendants()
for _, d in ipairs(allDes) do
	if d:IsA("BasePart") then
		baseParts[#baseParts + 1] = d
	end
end
add("Workspace children", #wsChildren)
local wsNames = {}
for _, c in ipairs(wsChildren) do
	wsNames[#wsNames + 1] = c.Name .. " [" .. c.ClassName .. "]"
end
add("WS top", table.concat(wsNames, " | "))

local nameCounts = {}
for _, p in ipairs(baseParts) do
	nameCounts[p.Name] = (nameCounts[p.Name] or 0) + 1
end
local unique = {}
for name, n in pairs(nameCounts) do
	unique[#unique + 1] = { name = name, n = n }
end
table.sort(unique, function(a, b) return a.n > b.n end)
local uniqStr = {}
for i = 1, math.min(40, #unique) do
	uniqStr[#uniqStr + 1] = unique[i].name .. " x" .. unique[i].n
end
add("BaseParts", tostring(#baseParts) .. " | unik: " .. table.concat(uniqStr, ", "))

-- ---------------------------------------------------------------------------
-- 3. Deskripsi argumen
-- ---------------------------------------------------------------------------
local function describe(v, depth)
	depth = depth or 0
	if depth > 3 then return "..." end
	local tv = type(v)
	if v == nil then return "nil" end
	if tv == "boolean" or tv == "number" then return tostring(v) end
	if tv == "string" then
		if #v > 60 then return ("%q"):format(v:sub(1, 60) .. "...") end
		return ("%q"):format(v)
	end
	if tv == "table" then
		local parts = {}
		local n = 0
		for k, val in pairs(v) do
			n = n + 1
			if n > 5 then parts[#parts + 1] = "..."; break end
			parts[#parts + 1] = describe(k, depth + 1) .. "=" .. describe(val, depth + 1)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	if tv == "userdata" then
		local isInstance = false
		pcall(function()
			if typeof(v) == "Instance" then
				tv = "Instance:" .. v:GetFullName()
				isInstance = true
			else
				tv = typeof(v)
			end
		end)
		return tv
	end
	return tv
end

-- ---------------------------------------------------------------------------
-- 4. Scan getgc untuk WORLD, STATE, INVENTORY, ITEMDB
-- ---------------------------------------------------------------------------
local worldTbl, stateFn, invTbl, itemDb

local function isWorldTbl(v)
	return type(rawget(v, "fg")) == "table" and type(rawget(v, "bg")) == "table"
		and type(rawget(v, "w")) == "number" and type(rawget(v, "h")) == "number"
		and rawget(v, "spawn") ~= nil
end

local function isInvTbl(v)
	return type(rawget(v, "slots")) == "table" and (rawget(v, "capacity") ~= nil or type(rawget(v, "count")) == "function")
end

local function isItemDb(v)
	if type(v) ~= "table" then return false end
	local count = 0
	for id, item in pairs(v) do
		if type(id) == "number" and type(item) == "table" and type(item.name) == "string" then
			count = count + 1
			if count > 20 then return true end
		end
	end
	return false
end

if getgc then
	local list = getgc(true)
	add("GC tables/functions", tostring(#list))

	for _, v in ipairs(list) do
		if type(v) == "table" then
			if not worldTbl then
				local ok, isW = pcall(isWorldTbl, v)
				if ok and isW then worldTbl = v end
			end
			if not invTbl then
				local ok, isI = pcall(isInvTbl, v)
				if ok and isI then invTbl = v end
			end
			if not itemDb then
				local ok, isD = pcall(isItemDb, v)
				if ok and isD then itemDb = v end
			end
			if not stateFn then
				local fn = rawget(v, "state")
				if type(fn) == "function" then
					local ok, s = pcall(fn)
					if ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" then
						stateFn = fn
					end
				end
			end
		end
	end
end

add("World table", worldTbl and ("ADA w=" .. tostring(worldTbl.w) .. " h=" .. tostring(worldTbl.h) .. " spawn=" .. describe(worldTbl.spawn)) or "TIDAK")
add("State function", stateFn and "ADA" or "TIDAK")
if stateFn then
	local ok, s = pcall(stateFn)
	if ok then
		add("State value", describe(s))
	else
		add("State value", "ERROR " .. tostring(s))
	end
end
add("Inventory table", invTbl and "ADA" or "TIDAK")
if invTbl then
	add("Inventory slots", tostring(#(invTbl.slots or {})))
	local cntFn = rawget(invTbl, "count")
	if type(cntFn) == "function" then
		local sample = {}
		local n = 0
		for _, slot in ipairs(invTbl.slots) do
			n = n + 1
			if n <= 15 and type(slot) == "table" then
				sample[#sample + 1] = describe(slot)
			end
		end
		add("Inventory sample", table.concat(sample, " | "))
	end
end
add("ItemDB", itemDb and "ADA" or "TIDAK")
if itemDb then
	local arr = {}
	for id, item in pairs(itemDb) do
		if type(id) == "number" and type(item) == "table" and type(item.name) == "string" then
			arr[#arr + 1] = tostring(id) .. ":" .. tostring(item.name)
			if #arr >= 30 then break end
		end
	end
	add("ItemDB sample", table.concat(arr, ", "))
end

-- ---------------------------------------------------------------------------
-- 5. Cari & hook fungsi punch / place / tile
-- ---------------------------------------------------------------------------
local function hasConst(fn, target)
	if not getconsts then return false end
	local ok, consts = pcall(getconsts, fn)
	if not ok or type(consts) ~= "table" then return false end
	for _, c in ipairs(consts) do
		if c == target then return true end
	end
	return false
end

local function hasConstPair(fn, a, b)
	if not getconsts then return false end
	local ok, consts = pcall(getconsts, fn)
	if not ok or type(consts) ~= "table" then return false end
	local hasA, hasB = false, false
	for _, c in ipairs(consts) do
		if c == a then hasA = true end
		if c == b then hasB = true end
		if hasA and hasB then return true end
	end
	return false
end

local hookLogs = {}
local function safeHook(fn, label)
	if not hookfn or type(fn) ~= "function" then return false end
	local orig = fn
	local ok = pcall(function()
		hookfn(orig, function(...)
			local args = { ... }
			local argStr = {}
			for i = 1, #args do argStr[#argStr + 1] = describe(args[i]) end
			local line = label .. "(" .. table.concat(argStr, ", ") .. ")"
			hookLogs[#hookLogs + 1] = line
			print("[Hook] " .. line)
			local results = { pcall(orig, ...) }
			if not results[1] then
				print("[Hook] " .. label .. " ERROR: " .. tostring(results[2]))
				hookLogs[#hookLogs + 1] = label .. " ERROR: " .. tostring(results[2])
			else
				local resStr = {}
				for i = 2, #results do resStr[#resStr + 1] = describe(results[i]) end
				if #resStr > 0 then
					print("[Hook] " .. label .. " -> " .. table.concat(resStr, ", "))
					hookLogs[#hookLogs + 1] = label .. " -> " .. table.concat(resStr, ", ")
				end
			end
			if results[1] then
				return unpack(results, 2)
			else
				error(results[2], 0)
			end
		end)
	end)
	return ok
end

local punchHooks = {}
local placeHooks = {}
local tileHooks = {}

if getgc then
	for _, v in ipairs(getgc(true)) do
		if type(v) == "function" then
			local ok, src = pcall(getinfo, v, "s")
			if ok and type(src) == "string" and src ~= "" and not src:find("GrowBlox_Probe", 1, true) then
				if #punchHooks < 6 and (hasConst(v, "punchEvent") or hasConstPair(v, "punch", "punch_miss") or hasConstPair(v, "punch", "newCrack") or hasConstPair(v, "punch", "HarvestProvider")) then
					table.insert(punchHooks, { fn = v, src = tostring(src) })
				end
				if #placeHooks < 6 and (hasConstPair(v, "placedAt", "flips") or hasConstPair(v, "cant_place_tile", "placedAt") or hasConstPair(v, "cant_place_tile", "flips")) then
					table.insert(placeHooks, { fn = v, src = tostring(src) })
				end
				if #tileHooks < 6 and (hasConst(v, "tileChanged") or hasConst(v, "tile_removed")) then
					table.insert(tileHooks, { fn = v, src = tostring(src) })
				end
			end
		end
	end
end

add("Punch candidates", tostring(#punchHooks))
for i, h in ipairs(punchHooks) do
	add("Punch" .. i, h.src)
	safeHook(h.fn, "PUNCH" .. i)
end
add("Place candidates", tostring(#placeHooks))
for i, h in ipairs(placeHooks) do
	add("Place" .. i, h.src)
	safeHook(h.fn, "PLACE" .. i)
end
add("Tile candidates", tostring(#tileHooks))
for i, h in ipairs(tileHooks) do
	add("Tile" .. i, h.src)
	safeHook(h.fn, "TILE" .. i)
end

-- ---------------------------------------------------------------------------
-- 6. Hook semua RemoteEvent/RemoteFunction juga
-- ---------------------------------------------------------------------------
local remotes = {}
local function collectRemotes(parent, depth)
	if depth > 4 then return end
	for _, c in ipairs(parent:GetChildren()) do
		if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
			remotes[#remotes + 1] = c
		end
		if c:IsA("Folder") or c:IsA("Configuration") or c:IsA("Model") then
			collectRemotes(c, depth + 1)
		end
	end
end
collectRemotes(ReplicatedStorage, 0)
local hookedRemote = 0
if hookfn then
	for _, r in ipairs(remotes) do
		if r:IsA("RemoteEvent") then
			pcall(function()
				local orig = r.FireServer
				hookfn(orig, function(self, ...)
					local args = { ... }
					local s = {}
					for i = 1, #args do s[#s + 1] = describe(args[i]) end
					print("[RemoteFire] " .. r:GetFullName() .. " (" .. table.concat(s, ", ") .. ")")
					return orig(self, ...)
				end)
				hookedRemote = hookedRemote + 1
			end)
		elseif r:IsA("RemoteFunction") then
			pcall(function()
				local orig = r.InvokeServer
				hookfn(orig, function(self, ...)
					local args = { ... }
					local s = {}
					for i = 1, #args do s[#s + 1] = describe(args[i]) end
					print("[RemoteInvoke] " .. r:GetFullName() .. " (" .. table.concat(s, ", ") .. ")")
					local results = { orig(self, ...) }
					local rs = {}
					for i = 1, #results do rs[#rs + 1] = describe(results[i]) end
					print("[RemoteInvoke] " .. r:GetFullName() .. " -> (" .. table.concat(rs, ", ") .. ")")
					return unpack(results)
				end)
				hookedRemote = hookedRemote + 1
			end)
		end
	end
end
add("Remotes hooked", tostring(hookedRemote))

-- ---------------------------------------------------------------------------
-- 7. GUI
-- ---------------------------------------------------------------------------
local report = table.concat(lines, "\n")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxProbe"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
pcall(function()
	local parent
	if type(gethui) == "function" then parent = gethui() end
	if not parent then parent = player:FindFirstChild("PlayerGui") end
	if not parent then parent = game:GetService("CoreGui") end
	screenGui.Parent = parent
end)

-- Frame kecil di pojok kiri-bawah, bisa digeser & ditutup.
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 310, 0, 190)
frame.Position = UDim2.new(0, 8, 1, -198)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 32)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 26)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "GrowBlox Probe (bisa ditutup)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local hideButton = Instance.new("TextButton")
hideButton.Size = UDim2.new(0, 26, 0, 22)
hideButton.Position = UDim2.new(1, -30, 0, 6)
hideButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
hideButton.BorderSizePixel = 0
hideButton.Text = "X"
hideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
hideButton.Font = Enum.Font.GothamBold
hideButton.TextSize = 11
hideButton.Parent = frame

local hideCorner = Instance.new("UICorner")
hideCorner.CornerRadius = UDim.new(0, 5)
hideCorner.Parent = hideButton

local copyButton = Instance.new("TextButton")
copyButton.Size = UDim2.new(0, 70, 0, 22)
copyButton.Position = UDim2.new(1, -104, 0, 6)
copyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
copyButton.BorderSizePixel = 0
copyButton.Text = "COPY"
copyButton.TextColor3 = Color3.fromRGB(0, 0, 0)
copyButton.Font = Enum.Font.GothamBold
copyButton.TextSize = 11
copyButton.Parent = frame

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 5)
copyCorner.Parent = copyButton

-- Toggle tampilkan/sembunyikan isi. Saat disembunyikan, GUI tidak menghalangi.
local contentVisible = true
local function setContentVisible(state)
	contentVisible = state
	frame.Size = state and UDim2.new(0, 310, 0, 190) or UDim2.new(0, 140, 0, 34)
	scroll.Visible = state
end

hideButton.MouseButton1Click:Connect(function()
	setContentVisible(not contentVisible)
	hideButton.Text = contentVisible and "X" or "+"
end)

copyButton.MouseButton1Click:Connect(function()
	pcall(function()
		if setclipboard then
			setclipboard(report)
			copyButton.Text = "OK"
			task.wait(1.5)
			copyButton.Text = "COPY"
		elseif writefile then
			writefile("GrowBlox_Probe.txt", report)
			copyButton.Text = "SAVED"
			task.wait(1.5)
			copyButton.Text = "COPY"
		end
	end)
end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -40)
scroll.Position = UDim2.new(0, 10, 0, 34)
scroll.BackgroundColor3 = Color3.fromRGB(22, 27, 48)
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 5
scroll.Parent = frame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 6)
scrollCorner.Parent = scroll

local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, -12, 0, 0)
text.Position = UDim2.new(0, 6, 0, 6)
text.BackgroundTransparency = 1
text.Text = report
text.TextColor3 = Color3.fromRGB(220, 235, 255)
text.Font = Enum.Font.Code
text.TextSize = 10
text.TextWrapped = true
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.RichText = true
text.Parent = scroll

task.spawn(function()
	task.wait(0.5)
	pcall(function()
		local h = text.TextBounds.Y + 16
		text.Size = UDim2.new(1, -12, 0, h)
		scroll.CanvasSize = UDim2.new(0, 0, 0, h)
	end)
end)

pcall(function()
	if writefile then writefile("GrowBlox_Probe.txt", report) end
end)

add("INFO", "GUI kecil di kiri-bawah. Tekan X untuk menyembunyikan. Sekarang lakukan manual: pukul/pecah tile, tanam seed, panen pohon. Hasil tetap tercetak di console dan tersimpan di GrowBlox_Probe.txt.")
