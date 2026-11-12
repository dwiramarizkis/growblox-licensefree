-- GrowBlox license-free test runner (Lune Luau runtime)
-- Uses a mocked Roblox executor environment and executes the target script
-- through require(). Run:  lune run test_runner.lua
-- Expected: the script initializes its UI without any license dependency.

local ENV = getfenv()

-- ---------------------------------------------------------------------------
-- Vector3 implementation with basic operators used by the script
-- ---------------------------------------------------------------------------
local MakeVector
local Vector3Metatable = {
	__add = function(a, b)
		return MakeVector(a.x + b.x, a.y + b.y, a.z + b.z)
	end,
	__sub = function(a, b)
		return MakeVector(a.x - b.x, a.y - b.y, a.z - b.z)
	end,
	__mul = function(a, b)
		if type(b) == "number" then
			return MakeVector(a.x * b, a.y * b, a.z * b)
		end
		return MakeVector(a.x * b.x, a.y * b.y, a.z * b.z)
	end,
	__unm = function(a)
		return MakeVector(-a.x, -a.y, -a.z)
	end,
}

MakeVector = function(x, y, z)
	local v = {
		x = x,
		y = y,
		z = z,
	}
	v.Unit = setmetatable({ x = x, y = y, z = z }, Vector3Metatable)
	return setmetatable(v, Vector3Metatable)
end

local NewVector = MakeVector

local MockTweenInfo = {
	new = function(a, b, c)
		return { duration = a, style = b, direction = c }
	end,
}

local MockTweenService = {
	Create = function(target, info, props)
		return { Play = function() return nil end }
	end,
}

local MockInstanceMeta = {
	__index = function(self, key)
		if key == "FindFirstChild" then
			return function(_, _name) return nil end
		elseif key == "FindFirstChildOfClass" then
			return function(_, _name) return nil end
		elseif key == "WaitForChild" then
			return function(_, _name) return nil end
		elseif key == "GetDescendants" then
			return function(_) return {} end
		elseif key == "IsA" then
			return function(_, _type) return false end
		elseif key == "GetMouse" then
			return function(_) return { Hit = { Position = NewVector(0, 0, -10) } } end
		elseif key == "PivotTo" then
			return function(_, _cf) return nil end
		elseif key == "MakeJoints" then
			return function(_) return nil end
		elseif key == "Clone" then
			return function(self)
				local c = MockInstance.new(self.ClassName)
				c.Name = self.Name
				return c
			end
		elseif key == "Destroy" then
			return function(self) self.Parent = nil end
		elseif key == "Connect" then
			return function(_, _event, _cb) return { Disconnect = function() end } end
		end
		if string.find(key, "Mouse") then
			return setmetatable({
				Connect = function(_, _cb) return { Disconnect = function() end } end,
			}, {
				__index = function(_, _k)
					return function() return nil end
				end,
			})
		end
		return nil
	end,
}

MockInstance = {
	new = function(className)
		local obj = {
			ClassName = className,
			Name = className,
			Parent = nil,
			Anchored = false,
			CanCollide = true,
			Transparency = 0,
			Size = NewVector(1, 1, 1),
			Position = NewVector(0, 0, 0),
			CFrame = { LookVector = NewVector(0, 0, -1) },
			BrickColor = "Medium grey",
			Material = "SmoothPlastic",
		}
		return setmetatable(obj, MockInstanceMeta)
	end,
}

local services
services = {
	Players = {
		LocalPlayer = {
			Name = "TestPlayer",
			UserId = 0,
			PlayerGui = {
				Name = "PlayerGui",
				FindFirstChild = function(_, _name) return nil end,
			},
			Character = {
				Name = "TestCharacter",
				FindFirstChild = function(_, name)
					if name == "HumanoidRootPart" then
						return {
							ClassName = "Part",
							Name = "HumanoidRootPart",
							Position = NewVector(0, 5, 0),
							CFrame = {
								LookVector = NewVector(0, 0, -1),
								Position = NewVector(0, 5, 0),
							},
						}
					elseif name == "Humanoid" then
						return {
							ClassName = "Humanoid",
							Name = "Humanoid",
							WalkSpeed = 16,
							Parent = nil,
						}
					end
					return nil
				end,
				FindFirstChildOfClass = function(_, className)
					if className == "Humanoid" then
						return {
							ClassName = "Humanoid",
							Name = "Humanoid",
							WalkSpeed = 16,
							Parent = nil,
						}
					end
					return nil
				end,
			},
			WaitForChild = function(_, childName)
				if childName == "PlayerGui" then
					return services.Players.LocalPlayer.PlayerGui
				end
				return nil
			end,
			GetMouse = function()
				return { Hit = { Position = NewVector(0, 0, -10) } }
			end,
		},
	},
	HttpService = {
		UrlEncode = function(s)
			s = tostring(s)
			s = s:gsub("\n", "\r\n")
			s = s:gsub("([^%w%-_%.%~])", function(c)
				return string.format("%%%02X", string.byte(c))
			end)
			return s
		end,
	},
	TweenService = MockTweenService,
	RunService = {
		IsStudio = false,
	},
	UserInputService = {
		TouchEnabled = false,
		KeyboardEnabled = true,
		InputBegan = { Connect = function(_, _cb) return { Disconnect = function() end } end },
	},
}

ENV.game = {
	GameId = 0,
	PlaceId = 0,
	GetService = function(_, name)
		return services[name]
	end,
	IsLoaded = function() return true end,
	HttpGet = function(_, url)
		print("[MOCK game:HttpGet]", url)
		return ""
	end,
}
ENV.workspace = MockInstance.new("Workspace")
ENV.workspace.GetDescendants = function(_) return {} end
ENV.workspace.FindFirstChild = function(_, _n) return nil end

ENV.Instance = MockInstance
ENV.task = {
	wait = function(_) return nil end,
	spawn = function(f) return f() end,
	delay = function(_, f) return f() end,
}
ENV.warn = function(msg)
	print("[WARN]", tostring(msg))
end
ENV.shared = {}
ENV.getgenv = function() return {} end
ENV.gethui = nil
ENV.isfile = function() return false end
ENV.readfile = function() return nil end
ENV.setclipboard = nil
ENV.identifyexecutor = nil
ENV.getexecutorname = nil
ENV.gethwid = nil
ENV.loadstring = function(s, chunkName)
	local f, err = load(s, chunkName or "loadstring")
	if not f then
		error(err, 0)
	end
	return f
end

ENV.Color3 = {
	fromRGB = function(r, g, b) return { r = r, g = g, b = b } end,
}
ENV.UDim2 = {
	new = function(a, b, c, d) return { a, b, c, d } end,
}
ENV.UDim = {
	new = function(a, b) return { a, b } end,
}
ENV.TweenInfo = MockTweenInfo
ENV.Enum = {
	Font = { GothamBold = "GothamBold", Gotham = "Gotham" },
	TextXAlignment = { Left = "Left" },
	TextYAlignment = { Top = "Top" },
	PartType = { Block = "Block" },
	SurfaceType = { Smooth = "Smooth" },
	Material = {
		SmoothPlastic = "SmoothPlastic",
		Neon = "Neon",
		Metal = "Metal",
		ForceField = "ForceField",
		Grass = "Grass",
		Slate = "Slate",
		WoodPlanks = "WoodPlanks",
		Glass = "Glass",
		CorrodedMetal = "CorrodedMetal",
		Glacier = "Glacier",
		Water = "Water",
		Ice = "Ice",
	},
	EasingStyle = { Quad = "Quad", Bounce = "Bounce" },
	EasingDirection = { Out = "Out" },
	UserInputType = { MouseButton1 = "MouseButton1" },
	AutomaticSize = { Y = "Y" },
	HorizontalAlignment = { Center = "Center" },
	ScrollingDirection = { Y = "Y" },
	SortOrder = { LayoutOrder = "LayoutOrder" },
}
ENV.BrickColor = {
	new = function(_s) return "BrickColor" end,
	Random = function() return "RandomColor" end,
}
ENV.Vector3 = {
	new = NewVector,
}
ENV.CFrame = {
	lookAt = function(pos, target)
		return { pos = pos, target = target, LookVector = NewVector(0, 0, -1) }
	end,
	new = function(x, y, z) return { x = x, y = y, z = z, LookVector = NewVector(0, 0, -1) } end,
}
ENV.PhysicalProperties = {
	new = function() return {} end,
}

-- ---------------------------------------------------------------------------
-- Execute the target script
-- ---------------------------------------------------------------------------
print("=== GrowBlox License-Free Test Run ===")
local ok, err = pcall(function()
	require("./GrowBlox_LicenseFree")
end)
print("SCRIPT_PCALL_OK", ok)
if not ok then
	print("SCRIPT_ERROR", err)
else
	print("SCRIPT_EXECUTED_SUCCESSFULLY")
end

-- Sanity checks after execution
print("RUNNING_FLAG", _G.HipHub_GrowBlox_Running)
print("ACTIVE_MODE", _G.GrowBlox and _G.GrowBlox.getActiveMode())
print("SET_MODE_OK", _G.GrowBlox and _G.GrowBlox.setMode("shootNuke"))
local fireOk, fireErr = pcall(_G.GrowBlox.fire)
print("FIRE_OK", fireOk, fireErr)
print("DONE")
