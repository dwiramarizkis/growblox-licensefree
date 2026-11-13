-- GrowBlox GridProbe (temukan rumus index world.fg)
-- Jalankan di dalam world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_GridProbe.lua"))()
--
-- Dump nilai fg di sekitar pemain untuk beberapa rumus index yang mungkin.

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
	print("[GridProbe] " .. line)
end

-- Cari world + state
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

if not (World and StateFn) then
	add("GAGAL: jalankan di dalam world")
else
	local ok, s = pcall(StateFn)
	if ok and type(s) == "table" then
		local px = math.floor(s.x)
		local py = math.floor(s.y - 0.475)
		add("player tile: x=" .. px .. " y=" .. py)

		local fg = World.fg
		local bg = World.bg

		-- Coba berbagai width
		local widths = { 50, 60, 80, 100, 128, 200, 512 }
		for _, W in ipairs(widths) do
			local idx0 = py * W + px         -- 0-based
			local idx1 = py * W + px + 1     -- 1-based
			local out0 = {}
			local out1 = {}
			for d = -2, 2 do
				out0[#out0 + 1] = (idx0 + d) .. "=" .. tostring(fg[idx0 + d])
				out1[#out1 + 1] = (idx1 + d) .. "=" .. tostring(fg[idx1 + d])
			end
			add("W=" .. W .. " 0-based: " .. table.concat(out0, " "))
			add("W=" .. W .. " 1-based: " .. table.concat(out1, " "))
		end

		-- Dump semua key fg yang number dan nilainya integer (mungkin tile id)
		local ints = {}
		local n = 0
		for k, v in pairs(fg) do
			if type(k) == "number" and type(v) == "number" and v == math.floor(v) and v >= 0 and v < 10000 then
				n += 1
				if n <= 40 then
					ints[#ints + 1] = k .. "=" .. tostring(v)
				end
			end
		end
		add("fg integer entries=" .. tostring(n) .. " sample: " .. table.concat(ints, " "))

		-- Dump bg juga
		local bints = {}
		n = 0
		for k, v in pairs(bg) do
			if type(k) == "number" and type(v) == "number" and v == math.floor(v) and v >= 0 and v < 10000 then
				n += 1
				if n <= 20 then
					bints[#bints + 1] = k .. "=" .. tostring(v)
				end
			end
		end
		add("bg integer entries=" .. tostring(n) .. " sample: " .. table.concat(bints, " "))
	end
end

add("Selesai")

-- Simpan + GUI COPY
local fullReport = table.concat(lines, "\n")
pcall(function()
	if writefile then writefile("GrowBlox_GridProbe.txt", fullReport) end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxGridProbe"
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
title.Text = "GridProbe"
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
