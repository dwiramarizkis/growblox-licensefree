-- GrowBlox InputProbe3 (cari module input + fungsi dengan konstanta key input + nama)
-- Jalankan di dalam world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_InputProbe3.lua"))()
--
-- Fokus: temukan module/script yang punya fungsi isDown, keyLeft, dsb.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:FindFirstChild("PlayerGui")

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
local getconstants = globalFn("getconstants")
local getupvalue = globalFn("getupvalue")
local getinfo = globalFn("getinfo")

local lines = {}
local function add(line)
	lines[#lines + 1] = line
	print("[InputProbe3] " .. line)
end

add("getgc=" .. tostring(getgc ~= nil))

-- 1. Cari semua module di PlayerGui yang punya fungsi apapun, tandai yang penting
local function walk(parent, depth)
	depth = depth or 0
	if depth > 6 then return end
	for _, c in ipairs(parent:GetChildren()) do
		if c:IsA("ModuleScript") then
			pcall(function()
				local mod = require(c)
				if type(mod) == "table" then
					local fns = {}
					local isInput = false
					for k, v in pairs(mod) do
						if type(v) == "function" then
							fns[#fns + 1] = tostring(k)
							if k == "isDown" or k == "isKeyDown" or k == "keyDown" or k == "keyLeft" then
								isInput = true
							end
						end
					end
					if isInput or #fns > 0 then
						add((isInput and "[INPUT] " or "[MOD] ") .. c:GetFullName() .. " fns: " .. table.concat(fns, ","))
					end
				end
			end)
		end
		if c:IsA("Folder") or c:IsA("Frame") or c:IsA("ScreenGui") or c:IsA("ScrollingFrame") or c:IsA("Model") then
			walk(c, depth + 1)
		end
	end
end
if PlayerGui then walk(PlayerGui, 0) else add("PlayerGui TIDAK ADA") end

-- 2. Cari fungsi dengan keyLeft/Right/Jump/Down, dump upvalue TANPA mengeksekusi
if getgc and getconstants then
	local found = 0
	for _, v in ipairs(getgc(true)) do
		if type(v) == "function" and found < 10 then
			local ok, consts = pcall(getconstants, v)
			if ok and type(consts) == "table" then
				local has = {}
				for _, c in pairs(consts) do
					if c == "keyLeft" or c == "keyRight" or c == "keyJump" or c == "keyDown" then
						has[#has + 1] = c
					end
				end
				if #has > 0 then
					found += 1
					-- nama konstanta unik
					local uniq = {}
					for _, h in ipairs(has) do
						uniq[h] = true
					end
					local ks = {}
					for k in pairs(uniq) do ks[#ks + 1] = k end

					-- source dari getinfo kalau ada
					local src = "?"
					if getinfo then
						pcall(function()
							local di = getinfo(v, "s")
							src = tostring(di)
						end)
					end

					add("Fn" .. found .. " keys: " .. table.concat(ks, ",") .. " src=" .. src)

					-- upvalue tables
					if getupvalue then
						for i = 1, 20 do
							local okU, name, val = pcall(getupvalue, v, i)
							if not okU then break end
							if type(val) == "table" then
								local keys = {}
								for k in pairs(val) do
									keys[#keys + 1] = tostring(k)
									if #keys >= 12 then break end
								end
								add("  up" .. i .. "(" .. tostring(name) .. ") table keys: " .. table.concat(keys, ","))
							elseif type(val) == "function" then
								-- jangan panggil, hanya info
								add("  up" .. i .. "(" .. tostring(name) .. ") = function")
							else
								add("  up" .. i .. "(" .. tostring(name) .. ") = " .. tostring(val))
							end
						end
					end
				end
			end
		end
	end
	add("Total fungsi key input: " .. tostring(found))
end

add("Selesai")

-- Simpan + GUI COPY
local fullReport = table.concat(lines, "\n")
pcall(function()
	if writefile then writefile("GrowBlox_InputProbe3.txt", fullReport) end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxInputProbe3"
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
title.Text = "InputProbe3"
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
