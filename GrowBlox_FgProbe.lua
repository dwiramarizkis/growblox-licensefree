-- GrowBlox FgProbe (bongkar isi world.fg/bg lebih dalam)
-- Jalankan di dalam world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_FgProbe.lua"))()
--
-- Tidak menebak. Dump semua key + tipe nilai fg/bg dan cari pola.

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
	print("[FgProbe] " .. line)
end

local World, StateFn
if getgc then
	for _, v in ipairs(getgc(true)) do
		if type(v) == "table" then
			if not World and type(rawget(v, "fg")) == "table" and type(rawget(v, "bg")) == "table" then
				World = v
			end
			if not StateFn then
				local fn = rawget(v, "state")
				if type(fn) == "function" then
					local okS, s = pcall(fn)
					if okS and type(s) == "table" and type(s.x) == "number" then
						StateFn = fn
					end
				end
			end
		end
	end
end

add("World=" .. tostring(World ~= nil) .. " State=" .. tostring(StateFn ~= nil))

if World then
	local fg = World.fg
	local bg = World.bg

	-- Semua key + tipe
	local keyTypes = {}
	local numKeys = {}
	local n = 0
	for k, v in pairs(fg) do
		n += 1
		if type(k) == "number" then
			numKeys[#numKeys + 1] = k
		end
		if n <= 50 then
			keyTypes[#keyTypes + 1] = tostring(k) .. ":" .. type(v) .. (type(v) == "number" and ("=" .. tostring(v)) or "")
		end
	end
	add("fg entries=" .. tostring(n))
	add("fg first entries: " .. table.concat(keyTypes, " "))

	if #numKeys > 0 then
		table.sort(numKeys)
		local sample = {}
		for i = 1, math.min(10, #numKeys) do
			local k = numKeys[i]
			sample[#sample + 1] = k .. "=" .. tostring(fg[k])
		end
		add("fg numKeys min: " .. table.concat(sample, " "))

		local sample2 = {}
		for i = math.max(1, #numKeys - 9), #numKeys do
			local k = numKeys[i]
			sample2[#sample2 + 1] = k .. "=" .. tostring(fg[k])
		end
		add("fg numKeys max: " .. table.concat(sample2, " "))

		-- Cek tipe nilai: semua number? atau table?
		local typeCount = {}
		for _, k in ipairs(numKeys) do
			local t = type(fg[k])
			typeCount[t] = (typeCount[t] or 0) + 1
		end
		local tc = {}
		for t, c in pairs(typeCount) do tc[#tc + 1] = t .. ":" .. c end
		add("fg value types: " .. table.concat(tc, " "))
	end

	-- bg
	n = 0
	keyTypes = {}
	for k, v in pairs(bg) do
		n += 1
		if n <= 20 then
			keyTypes[#keyTypes + 1] = tostring(k) .. ":" .. type(v) .. (type(v) == "number" and ("=" .. tostring(v)) or "")
		end
	end
	add("bg entries=" .. tostring(n))
	add("bg first: " .. table.concat(keyTypes, " "))
end

if StateFn then
	local ok, s = pcall(StateFn)
	if ok and type(s) == "table" then
		add("state raw: x=" .. tostring(s.x) .. " y=" .. tostring(s.y))
		-- Mungkin world punya fungsi/metode untuk membaca tile
		if World then
			for _, fnName in ipairs({ "tileAt", "getTile", "at", "get", "tile" }) do
				local fn = rawget(World, fnName)
				if type(fn) == "function" then
					add("World." .. fnName .. " ADA")
					pcall(function()
						local r1 = { fn(World, math.floor(s.x), math.floor(s.y - 0.475)) }
						local desc = {}
						for i = 1, math.min(3, #r1) do
							desc[#desc + 1] = tostring(r1[i])
						end
						add("  call(x,y) -> " .. table.concat(desc, ","))
					end)
				end
			end
		end
	end
end

add("Selesai")

-- Simpan + GUI COPY
local fullReport = table.concat(lines, "\n")
pcall(function()
	if writefile then writefile("GrowBlox_FgProbe.txt", fullReport) end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxFgProbe"
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
frame.Size = UDim2.new(0, 340, 0, 200)
frame.Position = UDim2.new(0.5, -170, 1, -204)
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
title.Text = "FgProbe"
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
