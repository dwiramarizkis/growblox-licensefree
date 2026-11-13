-- GrowBlox Input Probe (rekam tombol input game + remote, tanpa mengganggu layar)
-- Jalankan SETELAH masuk world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_InputProbe.lua"))()
--
-- Khusus ANDROID: GUI compact di kiri-bawah, tekan X untuk menyusut.
-- Cara pakai:
--   1. Jalankan script.
--   2. Tekan GUI X agar isi GUI menyusut (tidak menghalangi layar).
--   3. Lakukan manual di game: gerak kiri/kanan, lompat, pukul tile, klik tile kosong untuk tanam.
--   4. Console akan merekam nama tombol/input yang game baca.
--   5. Kirim hasilnya ke saya.
--
-- Script TIDAK mengirim input apa pun, hanya membaca.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local lines = {}
local function add(k, v)
	v = tostring(v)
	lines[#lines + 1] = k .. ": " .. v
	print("[InputProbe] " .. k .. ": " .. v)
end

add("PlaceId", tostring(game.PlaceId))
add("Player", tostring(player and player.Name))
add("Device", "ANDROID")
add("Touch", UIS.TouchEnabled and "ON" or "OFF")
add("Keyboard", UIS.KeyboardEnabled and "ON" or "OFF")
add("Gamepad", UIS.GamepadEnabled and "ON" or "OFF")
add("Platform", tostring(Enum.Platform and UIS:GetPlatform() or "?"))

-- ---------------------------------------------------------------------------
-- 1. Rekam input (keyboard/mouse/touch/gamepad) — tanpa mengubah apa pun
-- ---------------------------------------------------------------------------
local keyNames = {}
local function onInputBegan(input, gameProcessed)
	local t = input.UserInputType
	local line = "INPUT_BEGAN:" .. tostring(t)
	if t == Enum.UserInputType.Keyboard then
		line = line .. ":" .. input.KeyCode.Name
	elseif t == Enum.UserInputType.MouseButton1 then
		line = line .. ":LMB"
	elseif t == Enum.UserInputType.MouseButton2 then
		line = line .. ":RMB"
	elseif t == Enum.UserInputType.Touch then
		line = line .. ":TOUCH"
	elseif t == Enum.UserInputType.Gamepad1 then
		line = line .. ":GAMEPAD1:" .. tostring(input.KeyCode)
	end
	line = line .. (gameProcessed and " (game)" or " (raw)")
	keyNames[#keyNames + 1] = line
	print("[InputProbe] " .. line)
end
local function onInputEnded(input)
	local t = input.UserInputType
	local line = "INPUT_ENDED:" .. tostring(t)
	if t == Enum.UserInputType.Keyboard then
		line = line .. ":" .. input.KeyCode.Name
	elseif t == Enum.UserInputType.MouseButton1 then
		line = line .. ":LMB"
	elseif t == Enum.UserInputType.Touch then
		line = line .. ":TOUCH"
	elseif t == Enum.UserInputType.Gamepad1 then
		line = line .. ":GAMEPAD1:" .. tostring(input.KeyCode)
	end
	keyNames[#keyNames + 1] = line
	print("[InputProbe] " .. line)
end
UIS.InputBegan:Connect(onInputBegan)
UIS.InputEnded:Connect(onInputEnded)
add("Input recorder", "AKTIF (sentuh, keyboard, mouse, gamepad)")

-- ---------------------------------------------------------------------------
-- 2. Rekam keyboard "keyboard" yang game baca tiap frame? (hanya lihat InputBegan/Ended)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 3. Rekam nama tombol di PlayerGui (MobileGui, InventoryGui, MenuGui, dll)
-- ---------------------------------------------------------------------------
local function listButtons(parent, depth, maxCount)
	depth = depth or 0
	maxCount = maxCount or 60
	local out = {}
	local function walk(p, d)
		if d > 8 then return end
		for _, c in ipairs(p:GetChildren()) do
			if c:IsA("TextButton") or c:IsA("ImageButton") or c:IsA("TextLabel") or c:IsA("ImageLabel") then
				if #out < maxCount then
					local tag = ""
					if c:IsA("TextButton") or c:IsA("ImageButton") then
						tag = "[BTN]"
					else
						tag = "[LBL]"
					end
					local extra = ""
					pcall(function()
						if c:IsA("TextButton") or c:IsA("TextLabel") then
							extra = " text=" .. tostring(c.Text):sub(1, 30)
						end
					end)
					out[#out + 1] = c:GetFullName() .. tag .. extra
				end
			end
			if c:IsA("GuiObject") or c:IsA("Folder") then
				walk(c, d + 1)
			end
		end
	end
	walk(parent, depth)
	return out
end

pcall(function()
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		local buttons = listButtons(pg)
		add("PlayerGui buttons", tostring(#buttons))
		for i, b in ipairs(buttons) do
			add("PG" .. i, b)
		end
	else
		add("PlayerGui", "TIDAK ADA")
	end
end)

-- Rekam juga CoreGui (biasanya tempat GUI executor)
pcall(function()
	local cg = game:GetService("CoreGui")
	if cg then
		local buttons = listButtons(cg)
		add("CoreGui buttons", tostring(#buttons))
		for i, b in ipairs(buttons) do
			add("CG" .. i, b)
		end
	end
end)

-- ---------------------------------------------------------------------------
-- 4. Rekam Instance di workspace (mungkin ada camera/tile grid)
-- ---------------------------------------------------------------------------
add("Workspace top", (function()
	local names = {}
	for _, c in ipairs(workspace:GetChildren()) do
		names[#names + 1] = c.Name .. "[" .. c.ClassName .. "]"
	end
	return table.concat(names, " | ")
end)())

-- ---------------------------------------------------------------------------
-- 5. Rekam remote FireServer/InvokeServer yang terpanggil (cuma log, tanpa ubah)
-- ---------------------------------------------------------------------------
local function describe(v, depth)
	depth = depth or 0
	if depth > 3 then return "..." end
	local tv = type(v)
	if v == nil then return "nil" end
	if tv == "boolean" or tv == "number" then return tostring(v) end
	if tv == "string" then
		if #v > 80 then return ("%q"):format(v:sub(1, 80) .. "...") end
		return ("%q"):format(v)
	end
	if tv == "table" then
		local parts = {}
		local n = 0
		for k, val in pairs(v) do
			n = n + 1
			if n > 6 then parts[#parts + 1] = "..."; break end
			parts[#parts + 1] = describe(k, depth + 1) .. "=" .. describe(val, depth + 1)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	if tv == "userdata" then
		pcall(function()
			if typeof(v) == "Instance" then
				tv = "Instance:" .. v:GetFullName()
			else
				tv = typeof(v)
			end
		end)
		return tv
	end
	return tv
end

local hookfn = nil
pcall(function()
	if rawget(_G, "hookfunction") and type(rawget(_G, "hookfunction")) == "function" then
		hookfn = rawget(_G, "hookfunction")
	elseif type(getgenv) == "function" and type(getgenv().hookfunction) == "function" then
		hookfn = getgenv().hookfunction
	end
end)

local hooked = 0
if hookfn then
	local RS = game:GetService("ReplicatedStorage")
	local function collectRemotes(parent, depth)
		if depth > 4 then return end
		for _, c in ipairs(parent:GetChildren()) do
			if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
				if c:IsA("RemoteEvent") then
					pcall(function()
						local orig = c.FireServer
						if type(orig) == "function" then
							hookfn(orig, function(self, ...)
								local args = { ... }
								local s = {}
								for i = 1, #args do s[#s + 1] = describe(args[i]) end
								print("[RemoteFire] " .. c:GetFullName() .. " (" .. table.concat(s, ", ") .. ")")
								return orig(self, ...)
							end)
							hooked = hooked + 1
						end
					end)
				else
					pcall(function()
						local orig = c.InvokeServer
						if type(orig) == "function" then
							hookfn(orig, function(self, ...)
								local args = { ... }
								local s = {}
								for i = 1, #args do s[#s + 1] = describe(args[i]) end
								print("[RemoteInvoke] " .. c:GetFullName() .. " (" .. table.concat(s, ", ") .. ")")
								local results = { orig(self, ...) }
								local rs = {}
								for i = 1, #results do rs[#rs + 1] = describe(results[i]) end
								print("[RemoteInvoke] " .. c:GetFullName() .. " -> (" .. table.concat(rs, ", ") .. ")")
								return unpack(results)
							end)
							hooked = hooked + 1
						end
					end)
				end
			end
			if c:IsA("Folder") or c:IsA("Configuration") or c:IsA("Model") then
				collectRemotes(c, depth + 1)
			end
		end
	end
	collectRemotes(RS, 0)
end
add("Remotes hooked", tostring(hooked))

-- ---------------------------------------------------------------------------
-- 6. GUI kecil (tidak menghalangi)
-- ---------------------------------------------------------------------------
local report = table.concat(lines, "\n")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxInputProbe"
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
frame.Size = UDim2.new(0, 300, 0, 180)
frame.Position = UDim2.new(0, 4, 1, -184)
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
title.Text = "GrowBlox InputProbe"
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
			writefile("GrowBlox_InputProbe.txt", report)
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
	if writefile then writefile("GrowBlox_InputProbe.txt", report) end
end)

add("INFO", "Sekarang lakukan manual: gerak WASD, lompat, pukul tile, klik tile untuk tanam. Lihat console [InputProbe]/[RemoteFire].")
