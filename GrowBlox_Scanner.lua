-- GrowBlox Scanner
-- Menampilkan info game + executor untuk debugging GrowBlox.
-- Jalankan:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_Scanner.lua"))()
--
-- Hasil muncul di GUI dan di console (print/warn).

local function safe(fn, fallback)
	local ok, res = pcall(fn)
	if ok then
		return res
	end
	return fallback
end

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local lines = {}
local function add(label, value)
	lines[#lines + 1] = tostring(label) .. ": " .. tostring(value)
	print("[GrowBloxScanner] " .. tostring(label) .. ": " .. tostring(value))
end

-- ---------------------------------------------------------------------------
-- 1. Info dasar
-- ---------------------------------------------------------------------------
add("Game", tostring(game.PlaceId) .. " / GameId " .. tostring(game.GameId))
add("PlaceName", safe(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end, "?"))
add("Player", player.Name)
add("Character", player.Character and "ada" or "TIDAK ADA")

-- ---------------------------------------------------------------------------
-- 2. Kemampuan executor
-- ---------------------------------------------------------------------------
local function cap(name)
	local f = rawget(_G, name)
	if type(f) ~= "function" and type(getgenv) == "function" then
		f = safe(function() return getgenv()[name] end, nil)
	end
	return type(f) == "function"
end

local caps = {
	"getgc",
	"getgenv",
	"getconstants",
	"getupvalue",
	"setupvalue",
	"getinfo",
	"getthreadidentity",
	"setthreadidentity",
	"fireclickdetector",
	"fireproximityprompt",
	"firesignal",
	"firetouchinterest",
	"gethui",
	"writefile",
	"setclipboard",
	"request",
	"http_request",
}
for _, name in ipairs(caps) do
	add("exec." .. name, cap(name) and "ADA" or "tidak")
end

-- ---------------------------------------------------------------------------
-- 3. Isi ReplicatedStorage
-- ---------------------------------------------------------------------------
local function listChildren(parent, maxCount)
	maxCount = maxCount or 40
	local children = safe(function() return parent:GetChildren() end, {})
	local names = {}
	for i, c in ipairs(children) do
		if i > maxCount then
			names[#names + 1] = "... (+" .. (#children - maxCount) .. ")"
			break
		end
		local tag = ""
		if c:IsA("RemoteEvent") then
			tag = "[RemoteEvent]"
		elseif c:IsA("RemoteFunction") then
			tag = "[RemoteFunction]"
		elseif c:IsA("BindableEvent") then
			tag = "[BindableEvent]"
		elseif c:IsA("BindableFunction") then
			tag = "[BindableFunction]"
		elseif c:IsA("ModuleScript") then
			tag = "[Module]"
		elseif c:IsA("Folder") then
			tag = "[Folder]"
		end
		names[#names + 1] = c.Name .. tag
	end
	if #names == 0 then
		return "(kosong)"
	end
	return table.concat(names, ", ")
end

add("ReplicatedStorage", listChildren(ReplicatedStorage, 60))

-- ---------------------------------------------------------------------------
-- 4. Remote di ReplicatedStorage (rekursif, maks 80)
-- ---------------------------------------------------------------------------
local remotes = {}
local function collectRemotes(parent, depth)
	if depth > 3 then
		return
	end
	for _, c in ipairs(safe(function() return parent:GetChildren() end, {})) do
		if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
			if #remotes < 80 then
				remotes[#remotes + 1] = c:GetFullName()
			end
		end
		if c:IsA("Folder") or c:IsA("Configuration") or c:IsA("Model") then
			collectRemotes(c, depth + 1)
		end
	end
end
collectRemotes(ReplicatedStorage, 0)
add("Remotes (" .. #remotes .. ")", #remotes > 0 and ("\n  " .. table.concat(remotes, "\n  ")) or "(tidak ada)")

-- ---------------------------------------------------------------------------
-- 5. Objek interaktif di Workspace (ClickDetector / ProximityPrompt)
-- ---------------------------------------------------------------------------
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local center = root and root.Position or Vector3.new(0, 0, 0)

local interactives = {}
for _, d in ipairs(safe(function() return Workspace:GetDescendants() end, {})) do
	local ok, isClick, isPrompt = pcall(function()
		return d:IsA("ClickDetector"), d:IsA("ProximityPrompt")
	end)
	if ok and (isClick or isPrompt) then
		local parent = d.Parent
		local dist = "?"
		if root and parent and parent:IsA("BasePart") then
			dist = tostring(math.floor((parent.Position - center).Magnitude + 0.5))
		end
		interactives[#interactives + 1] = string.format(
			"%s %s | parent=%s | jarak=%s",
			isClick and "[Click]" or "[Prompt]",
			d.Name,
			parent and parent:GetFullName() or "?",
			dist
		)
		if #interactives >= 50 then
			interactives[#interactives + 1] = "... terpotong di 50"
			break
		end
	end
end
add("Interaktif (" .. #interactives .. ")", #interactives > 0 and ("\n  " .. table.concat(interactives, "\n  ")) or "(tidak ada)")

-- ---------------------------------------------------------------------------
-- 6. BasePart di sekitar karakter (max 60)
-- ---------------------------------------------------------------------------
local parts = {}
if root then
	for _, d in ipairs(safe(function() return Workspace:GetDescendants() end, {})) do
		local ok, isPart = pcall(function() return d:IsA("BasePart") end)
		if ok and isPart then
			local dist = (d.Position - center).Magnitude
			if dist <= 60 then
				parts[#parts + 1] = string.format("%s [%s] %.0f studs", d.Name, d.ClassName, dist)
				if #parts >= 60 then
					break
				end
			end
		end
	end
	table.sort(parts, function(a, b) return a < b end)
end
add("BasePart dekat (" .. #parts .. ")", #parts > 0 and ("\n  " .. table.concat(parts, "\n  ")) or "(tidak ada)")

-- ---------------------------------------------------------------------------
-- 7. LocalPlayer: PlayerGui dan Backpack
-- ---------------------------------------------------------------------------
add("PlayerGui", listChildren(safe(function() return player:FindFirstChild("PlayerGui") end, nil), 40))
add("Backpack", listChildren(safe(function() return player:FindFirstChild("Backpack") end, nil), 40))
add("Character children", listChildren(player.Character, 40))

-- ---------------------------------------------------------------------------
-- 8. Tampilkan di GUI
-- ---------------------------------------------------------------------------
local report = table.concat(lines, "\n")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxScanner"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
	local parent
	if type(gethui) == "function" then
		parent = gethui()
	end
	if not parent then
		parent = safe(function() return player:WaitForChild("PlayerGui") end, nil)
	end
	if not parent then
		parent = game:GetService("CoreGui")
	end
	screenGui.Parent = parent
end)

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 420, 0, 420)
frame.Position = UDim2.new(0.5, -210, 0.5, -210)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 32)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 28)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Text = "GrowBlox Scanner"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local copyButton = Instance.new("TextButton")
copyButton.Size = UDim2.new(0, 90, 0, 26)
copyButton.Position = UDim2.new(1, -100, 0, 8)
copyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
copyButton.BorderSizePixel = 0
copyButton.Text = "COPY"
copyButton.TextColor3 = Color3.fromRGB(0, 0, 0)
copyButton.Font = Enum.Font.GothamBold
copyButton.TextSize = 12
copyButton.Parent = frame

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 5)
copyCorner.Parent = copyButton

copyButton.MouseButton1Click:Connect(function()
	pcall(function()
		if setclipboard then
			setclipboard(report)
			copyButton.Text = "OK"
			task.wait(1.5)
			copyButton.Text = "COPY"
		elseif writefile then
			writefile("GrowBlox_Scanner.txt", report)
			copyButton.Text = "SAVED"
			task.wait(1.5)
			copyButton.Text = "COPY"
		end
	end)
end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -24, 1, -48)
scroll.Position = UDim2.new(0, 12, 0, 40)
scroll.BackgroundColor3 = Color3.fromRGB(22, 27, 48)
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 6
scroll.Parent = frame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 6)
scrollCorner.Parent = scroll

local text = Instance.new("TextLabel")
text.Size = UDim2.new(1, -16, 0, 0)
text.Position = UDim2.new(0, 8, 0, 8)
text.BackgroundTransparency = 1
text.Text = report
text.TextColor3 = Color3.fromRGB(220, 235, 255)
text.Font = Enum.Font.Code
text.TextSize = 11
text.TextWrapped = true
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.RichText = true
text.Parent = scroll

task.spawn(function()
	local width = scroll.AbsoluteCanvasSize.X
	local height = text.TextBounds.Y + 20
	scroll.CanvasSize = UDim2.new(0, 0, 0, height)
	text.Size = UDim2.new(1, -16, 0, height)
end)

task.wait(0.5)
pcall(function()
	text.Size = UDim2.new(1, -16, 0, text.TextBounds.Y + 20)
	scroll.CanvasSize = UDim2.new(0, 0, 0, text.TextBounds.Y + 20)
end)

add("Selesai", "scroll GUI untuk lihat semua hasil")
