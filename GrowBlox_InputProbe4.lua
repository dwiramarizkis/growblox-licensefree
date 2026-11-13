-- GrowBlox InputProbe4 (cek nama fungsi dari getinfo secara aman)
-- Jalankan di dalam world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_InputProbe4.lua"))()
--
-- getinfo(v) gagal di probe sebelumnya, kita coba getinfo(v, "n") dan "s".

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
local getconstants = globalFn("getconstants")
local getupvalue = globalFn("getupvalue")
local getinfo = globalFn("getinfo")

local lines = {}
local function add(line)
	lines[#lines + 1] = line
	print("[InputProbe4] " .. line)
end

-- Cek getinfo
add("getinfo=" .. tostring(getinfo ~= nil))

if getinfo then
	-- Test getinfo pada fungsi test
	local function testFn() return 1 end
	for _, mode in ipairs({ "n", "s", "a", "f" }) do
		local ok, res = pcall(getinfo, testFn, mode)
		add("getinfo(test, " .. mode .. ") -> " .. tostring(res))
	end
end

-- Cari fungsi key input dan coba getinfo
if getgc and getconstants then
	local found = 0
	for _, v in ipairs(getgc(true)) do
		if type(v) == "function" and found < 5 then
			local ok, consts = pcall(getconstants, v)
			if ok and type(consts) == "table" then
				local hasKey = false
				for _, c in pairs(consts) do
					if c == "keyLeft" or c == "keyRight" or c == "keyJump" or c == "keyDown" then
						hasKey = true
						break
					end
				end
				if hasKey then
					found += 1
					if getinfo then
						local info = {}
						for _, mode in ipairs({ "n", "s", "a" }) do
							local okI, res = pcall(getinfo, v, mode)
							if okI then
								local resType = type(res)
								if resType == "string" then
									info[#info + 1] = mode .. "=" .. res
								elseif resType == "table" then
									local name = res.name or res.short_src or res.source or "?"
									info[#info + 1] = mode .. "=" .. tostring(name)
								else
									info[#info + 1] = mode .. "=" .. tostring(res)
								end
							else
								info[#info + 1] = mode .. "=ERR:" .. tostring(res)
							end
						end
						add("Fn" .. found .. " " .. table.concat(info, " "))
					else
						add("Fn" .. found .. " (no getinfo)")
					end

					-- Dump upvalue 8 (function) - coba lihat nama dengan getinfo
					if getupvalue then
						for i = 1, 12 do
							local okU, name, val = pcall(getupvalue, v, i)
							if not okU then break end
							if type(val) == "function" and getinfo then
								local okI, res = pcall(getinfo, val, "n")
								add("  up" .. i .. " fn name=" .. tostring(res))
							elseif type(val) == "table" then
								-- Coba cek isi table yang penting (f.g. state, world, inventory)
								local keys = {}
								for k in pairs(val) do
									keys[#keys + 1] = tostring(k)
									if #keys >= 8 then break end
								end
								add("  up" .. i .. " table keys: " .. table.concat(keys, ","))
							end
						end
					end
				end
			end
		end
	end
end

add("Selesai")

-- Simpan + GUI COPY
local fullReport = table.concat(lines, "\n")
pcall(function()
	if writefile then writefile("GrowBlox_InputProbe4.txt", fullReport) end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxInputProbe4"
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
title.Text = "InputProbe4"
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
