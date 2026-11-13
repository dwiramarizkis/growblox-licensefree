-- GrowBlox Dump (struktur world grid + inventory lengkap)
-- Jalankan di dalam world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_Dump.lua"))()
--
-- Menyimpan hasil ke GrowBlox_Dump.txt (writefile) + GUI COPY.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
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
local lines = {}
local function add(line)
	lines[#lines + 1] = line
	print("[Dump] " .. line)
end

add("getgc=" .. tostring(getgc ~= nil))

-- ---------------------------------------------------------------------------
-- 1. Cari world table (fg/bg) dan inventory (slots+capacity)
-- ---------------------------------------------------------------------------
local World, Inv
if getgc then
	for _, v in ipairs(getgc(true)) do
		if type(v) == "table" then
			if not World and type(rawget(v, "fg")) == "table" and type(rawget(v, "bg")) == "table" then
				World = v
			end
			if not Inv and type(rawget(v, "slots")) == "table" and rawget(v, "capacity") ~= nil then
				Inv = v
			end
		end
	end
end

add("World=" .. tostring(World ~= nil))
add("Inv=" .. tostring(Inv ~= nil))

-- ---------------------------------------------------------------------------
-- 2. Dump struktur world.fg
-- ---------------------------------------------------------------------------
if World then
	add("World keys: " .. (function()
		local k = {}
		for key in pairs(World) do k[#k + 1] = tostring(key) end
		table.sort(k)
		return table.concat(k, ",")
	end)())

	local fg = World.fg
	add("fg type=" .. type(fg) .. " len=" .. tostring(#fg))

	-- Cari index maksimum fg
	local maxIdx = 0
	for k in pairs(fg) do
		if type(k) == "number" and k > maxIdx then maxIdx = k end
	end
	add("fg max index=" .. tostring(maxIdx))

	-- Coba fg[1], fg[2], fg[maxIdx]
	for _, idx in ipairs({ 1, 2, maxIdx }) do
		local v = fg[idx]
		if type(v) == "table" then
			local len = #v
			local maxK = 0
			for k in pairs(v) do
				if type(k) == "number" and k > maxK then maxK = k end
			end
			-- sample 6 nilai pertama
			local sample = {}
			for i = 1, math.min(6, maxK) do
				sample[#sample + 1] = i .. "=" .. tostring(v[i])
			end
			add("fg[" .. idx .. "] table len=" .. tostring(len) .. " maxK=" .. tostring(maxK) .. " sample: " .. table.concat(sample, " "))
		else
			add("fg[" .. idx .. "] = " .. tostring(v))
		end
	end

	-- Kalau fg flat 1D (index 1..N berisi number), cari dimensi
	local flatCount = 0
	for k, v in pairs(fg) do
		if type(k) == "number" and type(v) == "number" then
			flatCount += 1
			if flatCount > 5 then break end
		end
	end
	add("fg flat-number count sample=" .. tostring(flatCount))
end

-- ---------------------------------------------------------------------------
-- 3. Dump inventory lengkap
-- ---------------------------------------------------------------------------
if Inv then
	add("Inv slots=" .. tostring(#(Inv.slots or {})))
	add("Inv capacity=" .. tostring(Inv.capacity))
	for i, slot in ipairs(Inv.slots or {}) do
		if type(slot) == "table" then
			add("slot" .. i .. ": id=" .. tostring(slot.id) .. " n=" .. tostring(slot.n))
		else
			add("slot" .. i .. ": " .. tostring(slot))
		end
	end
end

add("Selesai")

-- ---------------------------------------------------------------------------
-- Simpan + GUI
-- ---------------------------------------------------------------------------
local fullReport = table.concat(lines, "\n")
pcall(function()
	if writefile then writefile("GrowBlox_Dump.txt", fullReport) end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxDump"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
	local parent
	if type(gethui) == "function" then parent = gethui() end
	if not parent then parent = player:FindFirstChild("PlayerGui") end
	if not parent then parent = game:GetService("CoreGui") end
	screenGui.Parent = parent
end)

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 200)
frame.Position = UDim2.new(0.5, -160, 1, -204)
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
title.Size = UDim2.new(1, -70, 0, 24)
title.Position = UDim2.new(0, 10, 0, 4)
title.BackgroundTransparency = 1
title.Text = "GrowBlox Dump"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local copyBtn = Instance.new("TextButton")
copyBtn.Size = UDim2.new(0, 60, 0, 20)
copyBtn.Position = UDim2.new(1, -68, 0, 4)
copyBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
copyBtn.BorderSizePixel = 0
copyBtn.Text = "COPY"
copyBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.TextSize = 10
copyBtn.Parent = frame

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 4)
copyCorner.Parent = copyBtn

copyBtn.MouseButton1Click:Connect(function()
	pcall(function()
		if setclipboard then
			setclipboard(fullReport)
			copyBtn.Text = "OK"
			task.wait(1)
			copyBtn.Text = "COPY"
		end
	end)
end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -34)
scroll.Position = UDim2.new(0, 10, 0, 28)
scroll.BackgroundColor3 = Color3.fromRGB(22, 27, 48)
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 5
scroll.Parent = frame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 5)
scrollCorner.Parent = scroll

local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, -12, 0, 0)
text.Position = UDim2.new(0, 6, 0, 6)
text.BackgroundTransparency = 1
text.Text = fullReport
text.TextColor3 = Color3.fromRGB(220, 235, 255)
text.Font = Enum.Font.Code
text.TextSize = 10
text.TextWrapped = true
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.RichText = true
text.Parent = scroll

task.spawn(function()
	task.wait(0.3)
	pcall(function()
		local h = text.TextBounds.Y + 16
		text.Size = UDim2.new(1, -12, 0, h)
		scroll.CanvasSize = UDim2.new(0, 0, 0, h)
	end)
end)
