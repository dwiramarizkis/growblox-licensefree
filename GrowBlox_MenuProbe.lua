-- GrowBlox MenuProbe (cari modul input game untuk gerakan)
-- Jalankan di dalam world:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/dwiramarizkis/growblox-licensefree/main/GrowBlox_MenuProbe.lua"))()
--
-- Mencari module/script di PlayerGui yang punya fungsi input (isDown, dsb.)

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local PlayerGui = player:FindFirstChild("PlayerGui")

print("[MenuProbe] PlayerGui=" .. tostring(PlayerGui ~= nil))

local function walk(parent, depth)
	depth = depth or 0
	if depth > 5 then return end
	for _, c in ipairs(parent:GetChildren()) do
		local tag = ""
		if c:IsA("ModuleScript") then tag = " [Module]" end
		if c:IsA("LocalScript") then tag = " [LocalScript]" end
		if c:IsA("Script") then tag = " [Script]" end
		print("[MenuProbe] " .. string.rep("  ", depth) .. c.Name .. " [" .. c.ClassName .. "]" .. tag)

		if c:IsA("ModuleScript") then
			pcall(function()
				local mod = require(c)
				if type(mod) == "table" then
					local keys = {}
					for k, v in pairs(mod) do
						if type(v) == "function" then
							keys[#keys + 1] = tostring(k)
						end
					end
					if #keys > 0 then
						print("[MenuProbe]   functions: " .. table.concat(keys, ", "))
					end
				end
			end)
		end

		if c:IsA("Folder") or c:IsA("Frame") or c:IsA("ScreenGui") or c:IsA("ScrollingFrame") or c:IsA("Model") or c:IsA("Configuration") then
			walk(c, depth + 1)
		end
	end
end

if PlayerGui then
	walk(PlayerGui, 0)
else
	print("[MenuProbe] PlayerGui belum ada")
end

-- Cari fungsi di getgc yang menerima "keyLeft"
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
if getgc then
	local found = 0
	for _, v in ipairs(getgc(true)) do
		if type(v) == "function" then
			local ok, consts = pcall(globalFn("getconstants") or getconstants, v)
			if ok and type(consts) == "table" then
				local hasKeyLeft = false
				for _, c in pairs(consts) do
					if c == "keyLeft" then hasKeyLeft = true break end
				end
				if hasKeyLeft then
					found += 1
					if found <= 10 then
						-- cari upvalue yang berupa table
						local gu = globalFn("getupvalue")
						if gu then
							for i = 1, 12 do
								local okU, name, val = pcall(gu, v, i)
								if not okU then break end
								if type(val) == "table" then
									local keys = {}
									for k in pairs(val) do
										keys[#keys + 1] = tostring(k)
										if #keys >= 12 then break end
									end
									print("[MenuProbe] Fn" .. found .. " up" .. i .. "(" .. tostring(name) .. ") table keys: " .. table.concat(keys, ","))
								end
							end
						end
					end
				end
			end
		end
	end
	print("[MenuProbe] Fungsi dengan konstanta keyLeft: " .. tostring(found))
end

print("[MenuProbe] Selesai")
