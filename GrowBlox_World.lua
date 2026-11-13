-- GrowBlox World Dump (baca world grid, state, inventory, ItemDB)
-- Jalankan SETELAH masuk world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_World.lua"))()
--
-- Tidak meng-hook apa pun. Hanya membaca data game lewat getgc.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local lines = {}
local function add(k, v)
	v = tostring(v)
	lines[#lines + 1] = k .. ": " .. v
	print("[World] " .. k .. ": " .. v)
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

add("PlaceId", tostring(game.PlaceId))
add("Player", tostring(player and player.Name))
add("getgc", getgc and "ADA" or "TIDAK")

-- ---------------------------------------------------------------------------
-- Deskripsi nilai (tabel/instance/vector)
-- ---------------------------------------------------------------------------
local function describe(v, depth)
	depth = depth or 0
	if depth > 2 then return "..." end
	local tv = type(v)
	if v == nil then return "nil" end
	if tv == "boolean" or tv == "number" then return tostring(v) end
	if tv == "string" then
		if #v > 40 then return ("%q"):format(v:sub(1, 40) .. "...") end
		return ("%q"):format(v)
	end
	if tv == "table" then
		local parts = {}
		local n = 0
		for k, val in pairs(v) do
			n = n + 1
			if n > 8 then parts[#parts + 1] = "..."; break end
			parts[#parts + 1] = describe(k, depth + 1) .. "=" .. describe(val, depth + 1)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	if tv == "userdata" then
		pcall(function()
			if typeof(v) == "Instance" then
				tv = "Instance:" .. v:GetFullName()
			elseif typeof(v) == "Vector2" then
				tv = "Vector2(" .. v.X .. "," .. v.Y .. ")"
			elseif typeof(v) == "Vector3" then
				tv = "Vector3(" .. v.X .. "," .. v.Y .. "," .. v.Z .. ")"
			else
				tv = typeof(v)
			end
		end)
		return tv
	end
	if tv == "function" then return "function" end
	return tv
end

-- ---------------------------------------------------------------------------
-- Cari world table, state, inventory, itemdb
-- ---------------------------------------------------------------------------
local worldTbl, stateFn, stateHolder, invTbl, itemDb

local function isWorldTbl(v)
	return type(rawget(v, "fg")) == "table" and type(rawget(v, "bg")) == "table"
		and type(rawget(v, "w")) == "number" and type(rawget(v, "h")) == "number"
		and rawget(v, "spawn") ~= nil
end

local function isInvTbl(v)
	return type(rawget(v, "slots")) == "table"
		and (rawget(v, "capacity") ~= nil or type(rawget(v, "count")) == "function")
end

local function isItemDb(v)
	if type(v) ~= "table" then return false end
	local count = 0
	for id, item in pairs(v) do
		if type(id) == "number" and type(item) == "table" and type(item.name) == "string" then
			count = count + 1
		end
	end
	return count > 20
end

if getgc then
	local all = getgc(true)
	add("GC objects", tostring(#all))
	for _, v in ipairs(all) do
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
			if not stateHolder then
				local fn = rawget(v, "state")
				if type(fn) == "function" then
					local ok, s = pcall(fn)
					if ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" then
						stateHolder = v
						stateFn = fn
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 1. World table
-- ---------------------------------------------------------------------------
add("World table", worldTbl and "ADA" or "TIDAK")
if worldTbl then
	add("World w", tostring(worldTbl.w))
	add("World h", tostring(worldTbl.h))
	add("World spawn", describe(worldTbl.spawn))

	-- Coba baca fg/bg sebagai array 2D [y][x] atau [x][y]
	local fg = worldTbl.fg
	local bg = worldTbl.bg
	add("fg type", type(fg) .. (fg and " len=" .. tostring(#fg) or ""))
	add("bg type", type(bg) .. (bg and " len=" .. tostring(#bg) or ""))

	-- Sample baris pertama fg
	pcall(function()
		local row = fg[1]
		if row then
			local sample = {}
			for x = 1, math.min(12, #row) do
				sample[#sample + 1] = tostring(x) .. ":" .. tostring(row[x])
			end
			add("fg row1", table.concat(sample, " "))
		end
	end)
	-- Sample kolom pertama fg
	pcall(function()
		local col = {}
		for y = 1, math.min(12, #fg) do
			local row = fg[y]
			if row then
				col[#col + 1] = tostring(y) .. ":" .. tostring(row[1])
			end
		end
		add("fg col1", table.concat(col, " "))
	end)
	-- Coba fg sebagai flat array
	pcall(function()
		local sample = {}
		for i = 1, math.min(12, #fg) do
			sample[#sample + 1] = tostring(i) .. ":" .. tostring(fg[i])
		end
		add("fg flat sample", table.concat(sample, " "))
	end)
end

-- ---------------------------------------------------------------------------
-- 2. State
-- ---------------------------------------------------------------------------
add("State holder", stateHolder and "ADA" or "TIDAK")
if stateFn then
	local ok, s = pcall(stateFn)
	if ok and type(s) == "table" then
		add("State", describe(s, 1))
		if type(s.x) == "number" and type(s.y) == "number" then
			add("PlayerTileXY", "x=" .. tostring(s.x) .. " y=" .. tostring(s.y) .. " facing=" .. tostring(s.facing))
		end
	else
		add("State error", tostring(s))
	end
end

-- ---------------------------------------------------------------------------
-- 3. Inventory
-- ---------------------------------------------------------------------------
add("Inventory", invTbl and "ADA" or "TIDAK")
if invTbl then
	pcall(function()
		local slots = invTbl.slots
		add("Inventory slots", tostring(#slots))
		for i = 1, math.min(20, #slots) do
			local slot = slots[i]
			if slot then
				add("Slot" .. i, describe(slot, 1))
			end
		end
	end)
	pcall(function()
		if type(invTbl.count) == "function" then
			add("Inventory capacity", tostring(invTbl.capacity))
			add("Inventory count", tostring(invTbl:count()))
		end
	end)
end

-- ---------------------------------------------------------------------------
-- 4. ItemDB (TAMPILKAN SEMUA - total item sedikit)
-- ---------------------------------------------------------------------------
add("ItemDB", itemDb and "ADA" or "TIDAK")
if itemDb then
	local items = {}
	for id, item in pairs(itemDb) do
		if type(id) == "number" and type(item) == "table" then
			items[#items + 1] = { id = id, item = item }
		end
	end
	table.sort(items, function(a, b) return a.id < b.id end)
	add("ItemDB total", tostring(#items))
	for _, entry in ipairs(items) do
		local id = entry.id
		local item = entry.item
		local name = type(item.name) == "string" and item.name or "?"
		local kind = type(item.kind) == "string" and item.kind or "?"
		local desc = type(item.desc) == "string" and item.desc:sub(1, 40) or ""
		add("Item" .. id, name .. " | kind=" .. kind .. " | " .. desc)
	end
end

-- ---------------------------------------------------------------------------
-- 5. Sample fg/bg di sekitar karakter
-- ---------------------------------------------------------------------------
pcall(function()
	if worldTbl and stateFn then
		local ok, s = pcall(stateFn)
		if ok and type(s) == "table" and type(s.x) == "number" and type(s.y) == "number" then
			local px = math.floor(s.x + 0.5)
			local py = math.floor(s.y + 0.5)
			add("Player tile", "x=" .. px .. " y=" .. py .. " facing=" .. tostring(s.facing))
			local fg = worldTbl.fg
			local bg = worldTbl.bg
			local linesFg = {}
			local linesBg = {}
			for y = py - 3, py + 3 do
				local rowFg = {}
				local rowBg = {}
				for x = px - 5, px + 5 do
					local fgVal = "?"
					local bgVal = "?"
					pcall(function()
						local r = fg[y]
						if r then fgVal = tostring(r[x]) end
						local rb = bg[y]
						if rb then bgVal = tostring(rb[x]) end
					end)
					rowFg[#rowFg + 1] = string.format("%2d:%-4s", x, fgVal)
					rowBg[#rowBg + 1] = string.format("%2d:%-4s", x, bgVal)
				end
				linesFg[#linesFg + 1] = "y=" .. y .. " fg " .. table.concat(rowFg, " ")
				linesBg[#linesBg + 1] = "y=" .. y .. " bg " .. table.concat(rowBg, " ")
			end
			for _, l in ipairs(linesFg) do add("FG", l) end
			for _, l in ipairs(linesBg) do add("BG", l) end
		end
	end
end)

-- ---------------------------------------------------------------------------
-- GUI kecil
-- ---------------------------------------------------------------------------
local report = table.concat(lines, "\n")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxWorld"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 2147483647
pcall(function()
	-- Prioritaskan PlayerGui agar pasti terlihat di layar.
	local parent = player:FindFirstChild("PlayerGui")
	if not parent and type(gethui) == "function" then
		parent = gethui()
	end
	if not parent then
		parent = game:GetService("CoreGui")
	end
	screenGui.Parent = parent
	add("GUI parent", parent and parent:GetFullName() or "TIDAK ADA")
end)

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 180)
frame.Position = UDim2.new(0.5, -150, 1, -184)
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
title.Size = UDim2.new(1, -70, 0, 26)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "GrowBlox World"
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
	frame.Size = state and UDim2.new(0, 300, 0, 180) or UDim2.new(0, 130, 0, 34)
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
			writefile("GrowBlox_World.txt", report)
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
	if writefile then writefile("GrowBlox_World.txt", report) end
end)

add("INFO", "Kirim hasil ini ke saya. Terutama: World w/h, PlayerTileXY, ItemDB relevant, fg row1/col1.")
