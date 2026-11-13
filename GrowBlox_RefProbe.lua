-- GrowBlox RefProbe (debug referensi world/state/inv)
-- Jalankan di dalam world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_RefProbe.lua"))()
--
-- Mencari kandidat world/state/inv dan mencetak strukturnya, supaya
-- deteksi di script utama bisa disesuaikan dengan versi game Anda.

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
print("[RefProbe] getgc=" .. tostring(getgc ~= nil))

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
-- Cari semua tabel yang MUNGKIN world / state / inventory
-- ---------------------------------------------------------------------------
local candidates = {
	world = {},
	inv = {},
	state = {},
}

if getgc then
	local all = getgc(true)
	print("[RefProbe] total objects=" .. tostring(#all))
	for _, v in ipairs(all) do
		if type(v) == "table" then
			local hasFg = type(rawget(v, "fg")) == "table"
			local hasBg = type(rawget(v, "bg")) == "table"
			local hasW = type(rawget(v, "w")) == "number"
			local hasH = type(rawget(v, "h")) == "number"

			if #candidates.world < 5 and (hasFg or hasBg or (hasW and hasH)) then
				candidates.world[#candidates.world + 1] = v
			end

			if #candidates.inv < 5 and type(rawget(v, "slots")) == "table" then
				candidates.inv[#candidates.inv + 1] = v
			end

			if #candidates.state < 5 then
				local fn = rawget(v, "state")
				if type(fn) == "function" then
					local okS, s = pcall(fn)
					if okS and type(s) == "table" then
						candidates.state[#candidates.state + 1] = { holder = v, state = s }
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Cetak hasil + simpan ke file + tampilkan di GUI agar mudah dicopy
-- ---------------------------------------------------------------------------
local report = {}
local function add(line)
	report[#report + 1] = line
	print("[RefProbe] " .. line)
end

add("WORLD candidates: " .. tostring(#candidates.world))
for i, w in ipairs(candidates.world) do
	add(string.format("WORLD%d: fg=%s bg=%s w=%s h=%s spawn=%s",
		i,
		type(rawget(w, "fg")),
		type(rawget(w, "bg")),
		tostring(rawget(w, "w")),
		tostring(rawget(w, "h")),
		describe(rawget(w, "spawn"))))
	pcall(function()
		local fg = w.fg
		if fg then
			local row = fg[1]
			if row then
				local s = {}
				for x = 1, math.min(8, #row) do s[#s + 1] = tostring(row[x]) end
				add("WORLD" .. i .. ".fg[1] = " .. table.concat(s, ","))
			else
				add("WORLD" .. i .. ".fg[1] = (bukan array per baris)")
			end
		end
	end)
end

add("INV candidates: " .. tostring(#candidates.inv))
for i, inv in ipairs(candidates.inv) do
	add(string.format("INV%d: slots=%s remove=%s count=%s capacity=%s",
		i,
		tostring(#(inv.slots or {})),
		type(rawget(inv, "remove")),
		type(rawget(inv, "count")),
		tostring(rawget(inv, "capacity"))))
	pcall(function()
		for j = 1, math.min(3, #(inv.slots or {})) do
			add("INV" .. i .. ".slot" .. j .. " = " .. describe(inv.slots[j]))
		end
	end)
end

add("STATE candidates: " .. tostring(#candidates.state))
for i, c in ipairs(candidates.state) do
	add("STATE" .. i .. " = " .. describe(c.state, 1))
end

add("Selesai.")

-- Simpan ke file executor (writefile) supaya bisa diambil.
pcall(function()
	if writefile then
		writefile("GrowBlox_RefProbe.txt", table.concat(report, "\n"))
	end
end)

-- GUI dengan tombol COPY
local fullReport = table.concat(report, "\n")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxRefProbe"
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
title.Text = "RefProbe"
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
