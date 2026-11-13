-- GrowBlox Probe v3 (AMAN - tanpa getinfo, tanpa hook remote)
-- Jalankan SETELAH masuk world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_Probe.lua"))()
--
-- Hanya scan getgc. Tidak meng-hook apa pun, jadi tidak akan merusak game.
-- Tampilkan kandidat fungsi punch/place/tile + upvalue remote-nya.

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
local getconsts = globalFn("getconstants")
local getupval = globalFn("getupvalue")
local islclosure = globalFn("islclosure")

add("PlaceId", tostring(game.PlaceId))
add("Player", tostring(player and player.Name))
add("getgc", getgc and "ADA" or "TIDAK")
add("getconstants", getconsts and "ADA" or "TIDAK")
add("getupvalue", getupval and "ADA" or "TIDAK")
add("islclosure", islclosure and "ADA" or "TIDAK")

-- ---------------------------------------------------------------------------
-- Utilitas
-- ---------------------------------------------------------------------------
local function describe(v, depth)
	depth = depth or 0
	if depth > 3 then return "..." end
	local tv = type(v)
	if v == nil then return "nil" end
	if tv == "boolean" or tv == "number" then return tostring(v) end
	if tv == "string" then
		if #v > 50 then return ("%q"):format(v:sub(1, 50) .. "...") end
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
	if tv == "function" then
		return "function"
	end
	return tv
end

local function getConsts(fn)
	if not getconsts then return nil end
	local ok, consts = pcall(getconsts, fn)
	if not ok or type(consts) ~= "table" then return nil end
	return consts
end

local function hasConst(fn, target)
	local consts = getConsts(fn)
	if not consts then return false end
	for _, c in ipairs(consts) do
		if c == target then return true end
	end
	return false
end

local function hasConstPair(fn, a, b)
	local consts = getConsts(fn)
	if not consts then return false end
	local hasA, hasB = false, false
	for _, c in ipairs(consts) do
		if c == a then hasA = true end
		if c == b then hasB = true end
		if hasA and hasB then return true end
	end
	return false
end

local function countConstMatches(fn, keywords)
	local consts = getConsts(fn)
	if not consts then return 0 end
	local n = 0
	for _, c in ipairs(consts) do
		if type(c) == "string" then
			local lc = c:lower()
			for _, kw in ipairs(keywords) do
				if lc:find(kw, 1, true) then
					n = n + 1
					break
				end
			end
		end
	end
	return n
end

local function constPreview(fn, limit)
	limit = limit or 14
	if not getconsts then return "" end
	local ok, consts = pcall(getconsts, fn)
	if not ok or type(consts) ~= "table" then return "" end
	local seen = {}
	local out = {}
	for _, c in ipairs(consts) do
		if type(c) == "string" and #c < 40 and not seen[c] then
			seen[c] = true
			out[#out + 1] = c
			if #out >= limit then break end
		end
	end
	return table.concat(out, " | ")
end

local function upvaluePreview(fn, limit)
	limit = limit or 10
	if not getupval then return "" end
	local out = {}
	for i = 1, 40 do
		local ok, name, val = pcall(getupval, fn, i)
		if not ok then break end
		if val ~= nil then
			local remoteName = nil
			pcall(function()
				if typeof(val) == "Instance" and (val:IsA("RemoteEvent") or val:IsA("RemoteFunction")) then
					remoteName = val:GetFullName()
				end
			end)
			if remoteName then
				out[#out + 1] = i .. ":" .. tostring(name) .. "=REMOTE(" .. remoteName .. ")"
			elseif type(val) == "table" then
				out[#out + 1] = i .. ":" .. tostring(name) .. "=table"
			elseif type(val) == "function" then
				out[#out + 1] = i .. ":" .. tostring(name) .. "=function"
			else
				out[#out + 1] = i .. ":" .. tostring(name) .. "=" .. describe(val, 1)
			end
			if #out >= limit then break end
		end
	end
	return table.concat(out, " | ")
end

-- ---------------------------------------------------------------------------
-- Scan GC
-- ---------------------------------------------------------------------------
local punchCands = {}
local placeCands = {}
local tileCands = {}
local stateCands = {}
local interestingCands = {}

local INTERESTING = {
	"punch", "place", "break", "tile", "seed", "grow", "harvest",
	"farm", "plant", "water", "dirt", "sugarcane", "sugar", "cane",
	"collect", "drop", "world", "inventory", "tree", "crop",
	"wrench", "settile", "remote",
}

if getgc then
	local scanned = 0
	local allList = getgc(true)
	for _, v in ipairs(allList) do
		if type(v) == "function" then
			scanned = scanned + 1
			if #punchCands < 10 and (hasConst(v, "punchEvent") or hasConstPair(v, "punch", "punch_miss") or hasConstPair(v, "punch", "newCrack") or hasConstPair(v, "punch", "HarvestProvider") or hasConstPair(v, "punch", "punchFx")) then
				punchCands[#punchCands + 1] = v
			end
			if #placeCands < 10 and (hasConstPair(v, "placedAt", "flips") or hasConstPair(v, "cant_place_tile", "placedAt") or hasConstPair(v, "cant_place_tile", "flips")) then
				placeCands[#placeCands + 1] = v
			end
			if #tileCands < 10 and (hasConst(v, "tileChanged") or hasConst(v, "tile_removed")) then
				tileCands[#tileCands + 1] = v
			end
			if #stateCands < 5 and hasConst(v, "airJump") then
				stateCands[#stateCands + 1] = v
			end

			if #interestingCands < 30 then
				local n = countConstMatches(v, INTERESTING)
				if n >= 3 then
					interestingCands[#interestingCands + 1] = { fn = v, matches = n }
				end
			end
		end
	end
	add("GC functions scanned", tostring(scanned))
	add("GC total objects", tostring(#allList))
end

add("Punch candidates", tostring(#punchCands))
for i, fn in ipairs(punchCands) do
	add("PUNCH" .. i .. ".const", constPreview(fn))
	add("PUNCH" .. i .. ".upvalue", upvaluePreview(fn))
end

add("Place candidates", tostring(#placeCands))
for i, fn in ipairs(placeCands) do
	add("PLACE" .. i .. ".const", constPreview(fn))
	add("PLACE" .. i .. ".upvalue", upvaluePreview(fn))
end

add("Tile candidates", tostring(#tileCands))
for i, fn in ipairs(tileCands) do
	add("TILE" .. i .. ".const", constPreview(fn))
	add("TILE" .. i .. ".upvalue", upvaluePreview(fn))
end

add("State candidates", tostring(#stateCands))
for i, fn in ipairs(stateCands) do
	add("STATE" .. i .. ".const", constPreview(fn))
	add("STATE" .. i .. ".upvalue", upvaluePreview(fn))
end

add("Interesting candidates", tostring(#interestingCands))
for i, entry in ipairs(interestingCands) do
	add("INTERESTING" .. i .. ".matches", tostring(entry.matches))
	add("INTERESTING" .. i .. ".const", constPreview(entry.fn, 20))
	add("INTERESTING" .. i .. ".upvalue", upvaluePreview(entry.fn, 12))
end

-- ---------------------------------------------------------------------------
-- GUI kecil di kiri-bawah
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
title.Text = "GrowBlox Probe v3"
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

add("INFO", "Probe v3 aman: tanpa hook. Kirim hasil PUNCH/PLACE/TILE/STATE candidates (terutama .upvalue).")
