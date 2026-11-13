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
-- Cetak hasil
-- ---------------------------------------------------------------------------
print("[RefProbe] WORLD candidates: " .. tostring(#candidates.world))
for i, w in ipairs(candidates.world) do
	print(string.format("[RefProbe] WORLD%d: fg=%s bg=%s w=%s h=%s spawn=%s",
		i,
		type(rawget(w, "fg")),
		type(rawget(w, "bg")),
		tostring(rawget(w, "w")),
		tostring(rawget(w, "h")),
		describe(rawget(w, "spawn"))))
	-- sample fg
	pcall(function()
		local fg = w.fg
		if fg then
			local row = fg[1]
			if row then
				local s = {}
				for x = 1, math.min(8, #row) do s[#s + 1] = tostring(row[x]) end
				print("[RefProbe] WORLD" .. i .. ".fg[1] = " .. table.concat(s, ","))
			else
				print("[RefProbe] WORLD" .. i .. ".fg[1] = (bukan array per baris)")
			end
		end
	end)
end

print("[RefProbe] INV candidates: " .. tostring(#candidates.inv))
for i, inv in ipairs(candidates.inv) do
	print(string.format("[RefProbe] INV%d: slots=%s remove=%s count=%s capacity=%s",
		i,
		tostring(#(inv.slots or {})),
		type(rawget(inv, "remove")),
		type(rawget(inv, "count")),
		tostring(rawget(inv, "capacity"))))
	pcall(function()
		for j = 1, math.min(3, #(inv.slots or {})) do
			print("[RefProbe] INV" .. i .. ".slot" .. j .. " = " .. describe(inv.slots[j]))
		end
	end)
end

print("[RefProbe] STATE candidates: " .. tostring(#candidates.state))
for i, c in ipairs(candidates.state) do
	print("[RefProbe] STATE" .. i .. " = " .. describe(c.state, 1))
end

print("[RefProbe] Selesai. Kirim hasil ini ke saya.")
