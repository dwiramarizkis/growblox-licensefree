-- GrowBlox Scanner v2 (remote & GC function discovery)
-- PENTING: jalankan SETELAH masuk world (karakter sudah muncul / bisa jalan).
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_Scanner2.lua"))()
--
-- Output: GUI + console. Teks lengkap juga disimpan ke workspace/executor:
--   writefile("GrowBlox_Scanner2.txt", report)

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local lines = {}
local function add(k, v)
	v = tostring(v)
	lines[#lines + 1] = k .. ": " .. v
	print("[GrowBloxScan2] " .. k .. ": " .. v)
end

local function has(name)
	local f = rawget(_G, name)
	if type(f) ~= "function" and type(getgenv) == "function" then
		pcall(function()
			f = getgenv()[name]
		end)
	end
	return type(f) == "function"
end

-- ---------------------------------------------------------------------------
-- 1. Status & kemampuan
-- ---------------------------------------------------------------------------
add("Game", tostring(game.PlaceId))
add("Character", player.Character and "ADA (OK)" or "TIDAK ADA - MASUK WORLD DULU")
add("CharacterRoot", player.Character and player.Character:FindFirstChild("HumanoidRootPart") and "ADA" or "TIDAK")

for _, n in ipairs({ "getgc", "getconstants", "getupvalue", "setupvalue", "getinfo", "debug",
	"hookfunction", "getconnections", "getnamecallmethod", "newcclosure", "getrawmetatable",
	"islclosure", "isexecutorclosure", "writefile", "setclipboard", "getthreadidentity",
	"setthreadidentity" }) do
	add("exec." .. n, has(n) and "ADA" or "tidak")
end

-- ---------------------------------------------------------------------------
-- 2. Daftar ModuleScript (rekursif)
-- ---------------------------------------------------------------------------
local modules = {}
local function collectModules(parent, depth)
	if depth > 4 then return end
	for _, c in ipairs(parent:GetChildren()) do
		if c:IsA("ModuleScript") then
			if #modules < 80 then
				modules[#modules + 1] = c:GetFullName()
			end
		end
		if c:IsA("Folder") or c:IsA("Configuration") or c:IsA("Model") then
			collectModules(c, depth + 1)
		end
	end
end
collectModules(ReplicatedStorage, 0)
add("Modules (" .. #modules .. ")", #modules > 0 and ("\n  " .. table.concat(modules, "\n  ")) or "(tidak ada)")

-- ---------------------------------------------------------------------------
-- 3. Daftar RemoteEvent/RemoteFunction (rekursif)
-- ---------------------------------------------------------------------------
local remotes = {}
local function collectRemotes(parent, depth)
	if depth > 4 then return end
	for _, c in ipairs(parent:GetChildren()) do
		if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
			remotes[#remotes + 1] = c
		end
		if c:IsA("Folder") or c:IsA("Configuration") or c:IsA("Model") then
			collectRemotes(c, depth + 1)
		end
	end
end
collectRemotes(ReplicatedStorage, 0)
add("Remotes (" .. #remotes .. ")", #remotes > 0 and ("\n  " .. table.concat(
	(function()
		local t = {}
		for _, r in ipairs(remotes) do
			t[#t + 1] = r:GetFullName() .. (r:IsA("RemoteFunction") and " [Function]" or " [Event]")
		end
		return t
	end)(),
	"\n  "
)) or "(tidak ada)")

-- ---------------------------------------------------------------------------
-- 4. Perekam remote (jika hookfunction tersedia)
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
			elseif typeof(v) == "buffer" then
				tv = "buffer(" .. tostring(v) .. ")"
			else
				tv = typeof(v)
			end
		end)
		return tv
	end
	return tv
end

local hookedFire = 0
local hookedInvoke = 0
if has("hookfunction") then
	for _, r in ipairs(remotes) do
		if r:IsA("RemoteEvent") then
			pcall(function()
				local orig = r.FireServer
				if type(orig) == "function" then
					hookfunction(orig, function(self, ...)
						local args = { ... }
						local s = {}
						for i = 1, #args do
							s[#s + 1] = describe(args[i])
						end
						print("[GrowBloxScan2][FireServer] " .. r:GetFullName() .. " (" .. table.concat(s, ", ") .. ")")
						return orig(self, ...)
					end)
					hookedFire = hookedFire + 1
				end
			end)
		elseif r:IsA("RemoteFunction") then
			pcall(function()
				local orig = r.InvokeServer
				if type(orig) == "function" then
					hookfunction(orig, function(self, ...)
						local args = { ... }
						local s = {}
						for i = 1, #args do
							s[#s + 1] = describe(args[i])
						end
						print("[GrowBloxScan2][InvokeServer] " .. r:GetFullName() .. " (" .. table.concat(s, ", ") .. ")")
						local results = { orig(self, ...) }
						local rs = {}
						for i = 1, #results do
							rs[#rs + 1] = describe(results[i])
						end
						print("[GrowBloxScan2][InvokeServer] " .. r:GetFullName() .. " -> (" .. table.concat(rs, ", ") .. ")")
						return unpack(results)
					end)
					hookedInvoke = hookedInvoke + 1
				end
			end)
		end
	end
end
add("HookedFireServer", tostring(hookedFire))
add("HookedInvokeServer", tostring(hookedInvoke))

-- ---------------------------------------------------------------------------
-- 5. Scan fungsi game via getgc
-- ---------------------------------------------------------------------------
local getconsts = getconstants or (debug and debug.getconstants)
local getupval = getupvalue or (debug and debug.getupvalue)
local getinfoFn = getinfo or (debug and debug.getinfo)

local KEYWORDS = {
	"harvest", "plant", "break", "place", "punch", "settile", "sugarcane",
	"cane", "dirt", "seed", "water", "collect", "drop", "pickup", "inventory",
	"world", "crop", "tree", "fruit", "farm", "tile", "grow", "vending",
}

local findings = {}
local seen = {}

local function scanGc()
	if not has("getgc") then
		add("getgc", "TIDAK ADA - tidak bisa scan")
		return
	end
	local list = getgc(true)
	local scanned = 0
	for _, f in ipairs(list) do
		if type(f) == "function" and not seen[f] then
			seen[f] = true
			scanned = scanned + 1

			local ok, consts = pcall(getconsts, f)
			if ok and type(consts) == "table" then
				local matched = {}
				local seenConst = {}
				local hasRemoteUpvalue = false
				local remoteUpvalues = {}
				local seenRemote = {}

				for _, c in ipairs(consts) do
					if type(c) == "string" then
						local lc = c:lower()
						for _, kw in ipairs(KEYWORDS) do
							if lc:find(kw, 1, true) then
								if not seenConst[c] then
									seenConst[c] = true
									matched[#matched + 1] = c
								end
								break
							end
						end
					end
				end

				if getupval then
					for i = 1, 25 do
						local ok2, name, val = pcall(getupval, f, i)
						if not ok2 then break end
						if val ~= nil then
							local isRemote = false
							pcall(function()
								if typeof(val) == "Instance" and (val:IsA("RemoteEvent") or val:IsA("RemoteFunction")) then
									isRemote = true
								end
							end)
							if isRemote then
								hasRemoteUpvalue = true
								local full = val:GetFullName()
								if not seenRemote[full] then
									seenRemote[full] = true
									remoteUpvalues[#remoteUpvalues + 1] = full
								end
							end
						end
					end
				end

				if #matched > 0 or hasRemoteUpvalue then
					local info = "?"
					pcall(function()
						local di = getinfoFn(f)
						if type(di) == "table" then
							info = tostring(di.short_src or di.source or "?") .. ":" .. tostring(di.linedefined or "?")
						else
							info = tostring(di)
						end
					end)
					findings[#findings + 1] = {
						info = info,
						consts = matched,
						remotes = remoteUpvalues,
					}
				end
			end
		end
		if #findings >= 120 then break end
	end
	add("GC_Functions_Scanned", tostring(scanned))
	add("GC_Findings", tostring(#findings))
end

scanGc()

-- Fungsi yang memegang remote lebih penting, cetak duluan.
table.sort(findings, function(a, b)
	if #a.remotes ~= #b.remotes then
		return #a.remotes > #b.remotes
	end
	return #a.consts > #b.consts
end)

for i, f in ipairs(findings) do
	add("F" .. i, f.info)
	if #f.remotes > 0 then
		add("F" .. i .. ".remote", table.concat(f.remotes, " | "))
	end
	if #f.consts > 0 then
		add("F" .. i .. ".const", table.concat(f.consts, " | "))
	end
end

-- ---------------------------------------------------------------------------
-- 6. GUI
-- ---------------------------------------------------------------------------
local report = table.concat(lines, "\n")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GrowBloxScanner2"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
	local parent
	if type(gethui) == "function" then parent = gethui() end
	if not parent then parent = player:FindFirstChild("PlayerGui") end
	if not parent then parent = game:GetService("CoreGui") end
	screenGui.Parent = parent
end)

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 460, 0, 430)
frame.Position = UDim2.new(0.5, -230, 0.5, -215)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 32)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -120, 0, 28)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Text = "GrowBlox Scanner v2"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local copyButton = Instance.new("TextButton")
copyButton.Size = UDim2.new(0, 100, 0, 26)
copyButton.Position = UDim2.new(1, -110, 0, 8)
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
	task.wait(0.5)
	pcall(function()
		local h = text.TextBounds.Y + 20
		text.Size = UDim2.new(1, -16, 0, h)
		scroll.CanvasSize = UDim2.new(0, 0, 0, h)
	end)
end)

-- Simpan otomatis
pcall(function()
	if writefile then
		writefile("GrowBlox_Scanner2.txt", report)
	end
end)

add("Report", "GUI tampil. Kalau writefile ada, tersimpan di GrowBlox_Scanner2.txt")
