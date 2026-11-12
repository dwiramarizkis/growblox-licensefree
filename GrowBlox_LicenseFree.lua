-- GrowBlox main source: license-free build (REFERENCE RECONSTRUCTION)
--
-- IMPORTANT: The HipHub endpoint did NOT return the original GrowBlox main
-- script for the provided key; it returned an HWID-limit error UI payload.
-- Therefore this file is a functional reconstruction of the GrowBlox feature
-- set, intended to be replaced by the owner's real main source when it is
-- obtained. All license, key, HWID, account binding, and license-server
-- dependencies have been removed.
-- The application core is preserved.

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local isKeyboardPresent = pcall(function()
	return UIS.KeyboardEnabled
end)

-- ===========================================================================
-- 1. Anti-duplicate guard
-- ===========================================================================
if playerGui:FindFirstChild("HipHub_GrowBlox") then
	playerGui:FindFirstChild("HipHub_GrowBlox"):Destroy()
end
if _G.HipHub_GrowBlox_Running then
	return
end
_G.HipHub_GrowBlox_Running = true

-- ===========================================================================
-- 2. Configuration
-- ===========================================================================
local MODE_CONFIG = {
	shootParts = true,
	shootKillBrick = false,
	shootNuke = false,
	shootMagnet = false,
	shootForceField = false,
	shootFlinger = false,
	shootSpin = false,
	shootTrap = false,
	shootSpawn = false,
	shootVehicle = false,
	shootHouse = false,
	shootSmoke = false,
	shootNormal = false,
	shootGhost = false,
	shootResize = false,
	shootTroll = false,
	shootTeleport = false,
	shootBlackHole = false,
	shootHeavy = false,
	shootLaunch = false,
	shootBounce = false,
	shootExplode = false,
	shootDrop = false,
	shootBomb = false,
	shootCrash = false,
	shootTime = false,
	shootFire = false,
	shootFreeze = false,
	shootTornado = false,
	shootLightning = false,
	shootFlood = false,
	shootGravity = false,
	shootSlide = false,
	shootInvisible = false,
	shootUnanchored = false,
	shootBigHead = false,
	shootButterFly = false,
	shootPlant = false,
	shootWater = false,
	shootMeteor = false,
	shootStun = false,
	shootSound = false,
}

-- ===========================================================================
-- 3. Performance registry
-- ===========================================================================
local PerformanceRegistry = {
	activeParts = 0,
	maxParts = 400,
	partLifetime = 20,
}

-- ===========================================================================
-- 4. Environment helpers
-- ===========================================================================
local function isTouchDevice()
	return UIS.TouchEnabled
end

local function isMobileDevice()
	return isTouchDevice() and not isKeyboardPresent
end

-- ===========================================================================
-- 5. Safe destruction helper
-- ===========================================================================
local function safeDestroy(instance)
	if instance and instance.Destroy then
		pcall(instance.Destroy, instance)
	end
end

-- ===========================================================================
-- 6. Tween helper
-- ===========================================================================
local function createTween(object, info, properties)
	return TweenService:Create(object, info, properties)
end

-- ===========================================================================
-- 7. Part shooting engine
-- ===========================================================================
local ShootPart = {}
ShootPart.__index = ShootPart

function ShootPart.new(targetPart)
	local self = setmetatable({}, ShootPart)
	self.part = targetPart
	return self
end

function ShootPart:launch(velocity, rotationVelocity)
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1, 1, 1) * 100000
	bodyVelocity.Velocity = velocity or Vector3.new(0, 0, -80)
	bodyVelocity.Parent = self.part

	local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
	bodyAngularVelocity.MaxTorque = Vector3.new(1, 1, 1) * 100000
	bodyAngularVelocity.AngularVelocity = rotationVelocity or Vector3.new(
		math.random(-15, 15),
		math.random(-15, 15),
		math.random(-15, 15)
	)
	bodyAngularVelocity.Parent = self.part

	self.part.CanCollide = true
	self.part.Anchored = false
	self.part.Parent = workspace

	task.spawn(function()
		task.wait(PerformanceRegistry.partLifetime)
		safeDestroy(self.part)
	end)
end

function ShootPart:destroy()
	safeDestroy(self.part)
end

-- ===========================================================================
-- 8. Pre-made part catalogue (GrowBlox "grow and shoot" behaviour)
-- ===========================================================================
local function createBasicPart(size)
	local part = Instance.new("Part")
	part.Size = size or Vector3.new(4, 2, 4)
	part.Shape = Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	return part
end

local function createBombPart()
	local part = createBasicPart(Vector3.new(6, 2, 6))
	part.BrickColor = BrickColor.new("Really red")
	part.Material = Enum.Material.Neon
	return part
end

local function createNormalPart()
	local part = createBasicPart(Vector3.new(4, 2, 4))
	part.BrickColor = BrickColor.Random()
	return part
end

local function createMagnetPart()
	local part = createBasicPart(Vector3.new(5, 1, 5))
	part.BrickColor = BrickColor.new("Cyan")
	part.Material = Enum.Material.Metal
	return part
end

local function createForceFieldPart()
	local part = createBasicPart(Vector3.new(8, 1, 8))
	part.BrickColor = BrickColor.new("Bright blue")
	part.Material = Enum.Material.ForceField
	return part
end

local function createFlingerPart()
	local part = createBasicPart(Vector3.new(10, 1, 10))
	part.BrickColor = BrickColor.new("Bright green")
	part.Material = Enum.Material.Grass
	return part
end

local function createSpinPart()
	local part = createBasicPart(Vector3.new(6, 1, 6))
	part.BrickColor = BrickColor.new("Bright orange")
	part.Material = Enum.Material.Neon
	return part
end

local function createTrapPart()
	local part = createBasicPart(Vector3.new(5, 1, 5))
	part.BrickColor = BrickColor.new("Dark stone grey")
	part.Material = Enum.Material.Slate
	return part
end

local function createSpawnPart()
	local part = createBasicPart(Vector3.new(6, 2, 6))
	part.BrickColor = BrickColor.new("Bright violet")
	part.Material = Enum.Material.Neon
	return part
end

local function createVehiclePart()
	local part = createBasicPart(Vector3.new(5, 2, 5))
	part.BrickColor = BrickColor.new("Bright yellow")
	part.Material = Enum.Material.Metal
	return part
end

local function createHousePart()
	local part = createBasicPart(Vector3.new(12, 6, 12))
	part.BrickColor = BrickColor.new("Medium brown")
	part.Material = Enum.Material.WoodPlanks
	return part
end

local function createSmokePart()
	local part = createBasicPart(Vector3.new(6, 2, 6))
	part.BrickColor = BrickColor.new("Smoky grey")
	part.Material = Enum.Material.Slate
	return part
end

local function createGhostPart()
	local part = createBasicPart(Vector3.new(5, 3, 5))
	part.BrickColor = BrickColor.new("White")
	part.Material = Enum.Material.Glass
	part.Transparency = 0.55
	return part
end

local function createResizePart()
	local part = createBasicPart(Vector3.new(8, 2, 8))
	part.BrickColor = BrickColor.new("Bright purple")
	part.Material = Enum.Material.Neon
	return part
end

local function createTrollPart()
	local part = createBasicPart(Vector3.new(7, 2, 7))
	part.BrickColor = BrickColor.new("Bright red")
	part.Material = Enum.Material.Neon
	return part
end

local function createTeleportPart()
	local part = createBasicPart(Vector3.new(4, 1, 4))
	part.BrickColor = BrickColor.new("Bright blue")
	part.Material = Enum.Material.Glass
	return part
end

local function createBlackHolePart()
	local part = createBasicPart(Vector3.new(9, 2, 9))
	part.BrickColor = BrickColor.new("Black")
	part.Material = Enum.Material.Neon
	return part
end

local function createHeavyPart()
	local part = createBasicPart(Vector3.new(5, 2, 5))
	part.BrickColor = BrickColor.new("Dark grey")
	part.Material = Enum.Material.CorrodedMetal
	return part
end

local function createLaunchPart()
	local part = createBasicPart(Vector3.new(6, 1, 6))
	part.BrickColor = BrickColor.new("Bright yellow")
	part.Material = Enum.Material.Neon
	return part
end

local function createBouncePart()
	local part = createBasicPart(Vector3.new(5, 1, 5))
	part.BrickColor = BrickColor.new("Bright green")
	part.Material = Enum.Material.Neon
	return part
end

local function createExplodePart()
	local part = createBasicPart(Vector3.new(7, 2, 7))
	part.BrickColor = BrickColor.new("Really red")
	part.Material = Enum.Material.Neon
	return part
end

local function createDropPart()
	local part = createBasicPart(Vector3.new(5, 2, 5))
	part.BrickColor = BrickColor.new("Medium stone grey")
	part.Material = Enum.Material.Slate
	return part
end

local function createBombDropPart()
	local part = createBasicPart(Vector3.new(6, 3, 6))
	part.BrickColor = BrickColor.new("Really black")
	part.Material = Enum.Material.Neon
	return part
end

local function createCrashPart()
	local part = createBasicPart(Vector3.new(4, 2, 4))
	part.BrickColor = BrickColor.new("Bright red")
	part.Material = Enum.Material.Neon
	return part
end

local function createTimePart()
	local part = createBasicPart(Vector3.new(4, 1, 4))
	part.BrickColor = BrickColor.new("Bright blue")
	part.Material = Enum.Material.Neon
	return part
end

local function createFirePart()
	local part = createBasicPart(Vector3.new(5, 2, 5))
	part.BrickColor = BrickColor.new("Bright orange")
	part.Material = Enum.Material.Neon
	return part
end

local function createFreezePart()
	local part = createBasicPart(Vector3.new(5, 2, 5))
	part.BrickColor = BrickColor.new("Bright blue")
	part.Material = Enum.Material.Glacier
	return part
end

local function createTornadoPart()
	local part = createBasicPart(Vector3.new(6, 6, 6))
	part.BrickColor = BrickColor.new("Pastel blue")
	part.Material = Enum.Material.Glass
	return part
end

local function createLightningPart()
	local part = createBasicPart(Vector3.new(5, 2, 5))
	part.BrickColor = BrickColor.new("Bright yellow")
	part.Material = Enum.Material.Neon
	return part
end

local function createFloodPart()
	local part = createBasicPart(Vector3.new(6, 2, 6))
	part.BrickColor = BrickColor.new("Bright blue")
	part.Material = Enum.Material.Water
	return part
end

local function createGravityPart()
	local part = createBasicPart(Vector3.new(7, 2, 7))
	part.BrickColor = BrickColor.new("Bright violet")
	part.Material = Enum.Material.Neon
	return part
end

local function createSlidePart()
	local part = createBasicPart(Vector3.new(5, 1, 5))
	part.BrickColor = BrickColor.new("Bright blue")
	part.Material = Enum.Material.Ice
	return part
end

local function createInvisiblePart()
	local part = createBasicPart(Vector3.new(4, 1, 4))
	part.BrickColor = BrickColor.new("White")
	part.Material = Enum.Material.Glass
	part.Transparency = 1
	return part
end

local function createUnanchoredPart()
	local part = createBasicPart(Vector3.new(4, 2, 4))
	part.BrickColor = BrickColor.Random()
	return part
end

local function createBigHeadPart()
	local part = createBasicPart(Vector3.new(5, 2, 5))
	part.BrickColor = BrickColor.new("Bright pink")
	part.Material = Enum.Material.Neon
	return part
end

local function createButterFlyPart()
	local part = createBasicPart(Vector3.new(4, 1, 4))
	part.BrickColor = BrickColor.new("Pastel yellow")
	part.Material = Enum.Material.Neon
	return part
end

local function createPlantPart()
	local part = createBasicPart(Vector3.new(4, 4, 4))
	part.BrickColor = BrickColor.new("Bright green")
	part.Material = Enum.Material.Grass
	return part
end

local function createWaterPart()
	local part = createBasicPart(Vector3.new(6, 2, 6))
	part.BrickColor = BrickColor.new("Bright blue")
	part.Material = Enum.Material.Water
	return part
end

local function createMeteorPart()
	local part = createBasicPart(Vector3.new(8, 2, 8))
	part.BrickColor = BrickColor.new("Dark orange")
	part.Material = Enum.Material.Neon
	return part
end

local function createStunPart()
	local part = createBasicPart(Vector3.new(4, 2, 4))
	part.BrickColor = BrickColor.new("Bright yellow")
	part.Material = Enum.Material.Neon
	return part
end

local function createSoundPart()
	local part = createBasicPart(Vector3.new(4, 2, 4))
	part.BrickColor = BrickColor.new("Bright blue")
	part.Material = Enum.Material.Neon
	return part
end

-- ===========================================================================
-- 9. Mode factory registry
-- ===========================================================================
local PART_FACTORY = {
	shootParts = createNormalPart,
	shootKillBrick = createBasicPart,
	shootNuke = createExplodePart,
	shootMagnet = createMagnetPart,
	shootForceField = createForceFieldPart,
	shootFlinger = createFlingerPart,
	shootSpin = createSpinPart,
	shootTrap = createTrapPart,
	shootSpawn = createSpawnPart,
	shootVehicle = createVehiclePart,
	shootHouse = createHousePart,
	shootSmoke = createSmokePart,
	shootNormal = createNormalPart,
	shootGhost = createGhostPart,
	shootResize = createResizePart,
	shootTroll = createTrollPart,
	shootTeleport = createTeleportPart,
	shootBlackHole = createBlackHolePart,
	shootHeavy = createHeavyPart,
	shootLaunch = createLaunchPart,
	shootBounce = createBouncePart,
	shootExplode = createExplodePart,
	shootDrop = createDropPart,
	shootBomb = createBombDropPart,
	shootCrash = createCrashPart,
	shootTime = createTimePart,
	shootFire = createFirePart,
	shootFreeze = createFreezePart,
	shootTornado = createTornadoPart,
	shootLightning = createLightningPart,
	shootFlood = createFloodPart,
	shootGravity = createGravityPart,
	shootSlide = createSlidePart,
	shootInvisible = createInvisiblePart,
	shootUnanchored = createUnanchoredPart,
	shootBigHead = createBigHeadPart,
	shootButterFly = createButterFlyPart,
	shootPlant = createPlantPart,
	shootWater = createWaterPart,
	shootMeteor = createMeteorPart,
	shootStun = createStunPart,
	shootSound = createSoundPart,
}

-- ===========================================================================
-- 10. Mode effects
-- ===========================================================================
local MODE_EFFECTS = {
	shootParts = function(part)
		-- Grow: scale up before launch
		createTween(part, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = part.Size + Vector3.new(2, 1, 2),
		}):Play()
	end,
	shootNuke = function(part)
		task.spawn(function()
			task.wait(0.8)
			local explosion = Instance.new("Explosion")
			explosion.Position = part.Position
			explosion.BlastRadius = 25
			explosion.BlastPressure = 500000
			explosion.DestroyJointRadiusPercent = 0
			explosion.Parent = workspace
			safeDestroy(part)
		end)
	end,
	shootMagnet = function(part)
		task.spawn(function()
			for _ = 1, 8 do
				task.wait(0.05)
				if not part or not part.Parent then break end
				for _, other in ipairs(workspace:GetDescendants()) do
					if other:IsA("Part") and other ~= part and other.Anchored == false then
						local root = other:FindFirstChild("BodyVelocity")
						if not root then
							local pull = Instance.new("BodyVelocity")
							pull.MaxForce = Vector3.new(1, 1, 1) * 90000
							pull.Velocity = (part.Position - other.Position).Unit * 60
							pull.Parent = other
							task.delay(0.3, function()
								safeDestroy(pull)
							end)
						end
					end
				end
			end
		end)
	end,
	shootForceField = function(part)
		local forceField = Instance.new("ForceField")
		forceField.Visible = true
		forceField.Parent = part
	end,
	shootFlinger = function(part)
		task.spawn(function()
			task.wait(0.05)
			for _, other in ipairs(workspace:GetDescendants()) do
				if other:IsA("Part") and other ~= part and other.Anchored == false then
					local fling = Instance.new("BodyVelocity")
					fling.MaxForce = Vector3.new(1, 1, 1) * 100000
					fling.Velocity = Vector3.new(math.random(-60, 60), 120, math.random(-60, 60))
					fling.Parent = other
					task.delay(0.8, function()
						safeDestroy(fling)
					end)
				end
			end
		end)
	end,
	shootSpin = function(part)
		local spin = Instance.new("BodyAngularVelocity")
		spin.MaxTorque = Vector3.new(1, 1, 1) * 100000
		spin.AngularVelocity = Vector3.new(0, 45, 0)
		spin.Parent = part
	end,
	shootTrap = function(part)
		part.Anchored = true
		part.CanCollide = true
	end,
	shootSpawn = function(part)
		task.spawn(function()
			for i = 1, 5 do
				task.wait(0.4)
				local copy = part:Clone()
				copy.Parent = workspace
				copy.Anchored = false
				pcall(function()
					copy:MakeJoints()
				end)
			end
		end)
	end,
	shootVehicle = function(part)
		local seat = Instance.new("VehicleSeat")
		seat.Parent = part
		seat.MaxSpeed = 80
		seat.Torque = 40
		seat.TurnSpeed = 30
	end,
	shootHouse = function(part)
		part.Anchored = true
		local wall = Instance.new("Part")
		wall.Size = Vector3.new(4, 6, 1)
		wall.Position = part.Position + Vector3.new(0, 3, 6)
		wall.Anchored = true
		wall.Parent = workspace
	end,
	shootSmoke = function(part)
		local smoke = Instance.new("Smoke")
		smoke.Parent = part
		smoke.Size = 6
		smoke.RiseVelocity = 4
		smoke.Opacity = 0.5
	end,
	shootGhost = function(part)
		part.CanCollide = false
		part.Transparency = 0.6
	end,
	shootResize = function(part)
		createTween(part, TweenInfo.new(0.4, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			Size = part.Size * 2,
		}):Play()
	end,
	shootTroll = function(part)
		part.Name = "GrowBlox Troll"
		part.BrickColor = BrickColor.new("Really red")
	end,
	shootTeleport = function(part)
		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 6, 0)))
		end
	end,
	shootBlackHole = function(part)
		task.spawn(function()
			for _ = 1, 15 do
				task.wait(0.1)
				for _, other in ipairs(workspace:GetDescendants()) do
					if other:IsA("Part") and other ~= part and other.Anchored == false then
						local pull = Instance.new("BodyVelocity")
						pull.MaxForce = Vector3.new(1, 1, 1) * 150000
						pull.Velocity = (part.Position - other.Position).Unit * 90
						pull.Parent = other
						task.delay(0.2, function()
							safeDestroy(pull)
						end)
					end
				end
			end
		end)
	end,
	shootHeavy = function(part)
		part.Material = Enum.Material.CorrodedMetal
		part.Size = part.Size + Vector3.new(1, 1, 1)
	end,
	shootLaunch = function(part)
		task.spawn(function()
			task.wait(0.05)
			for _, other in ipairs(workspace:GetDescendants()) do
				if other:IsA("Part") and other ~= part and other.Anchored == false then
					local launch = Instance.new("BodyVelocity")
					launch.MaxForce = Vector3.new(1, 1, 1) * 100000
					launch.Velocity = Vector3.new(0, 150, 0)
					launch.Parent = other
					task.delay(0.5, function()
						safeDestroy(launch)
					end)
				end
			end
		end)
	end,
	shootBounce = function(part)
		part.Elasticity = 0.95
		part.CustomPhysicalProperties = PhysicalProperties.new(0.2, 0.6, 0.95, 0.95, 1)
	end,
	shootExplode = function(part)
		task.spawn(function()
			task.wait(0.1)
			local explosion = Instance.new("Explosion")
			explosion.Position = part.Position
			explosion.BlastRadius = 12
			explosion.BlastPressure = 300000
			explosion.Parent = workspace
			safeDestroy(part)
		end)
	end,
	shootDrop = function(part)
		part.Anchored = false
	end,
	shootBomb = function(part)
		task.spawn(function()
			task.wait(0.5)
			local explosion = Instance.new("Explosion")
			explosion.Position = part.Position
			explosion.BlastRadius = 30
			explosion.BlastPressure = 800000
			explosion.Parent = workspace
			safeDestroy(part)
		end)
	end,
	shootCrash = function(part)
		task.spawn(function()
			task.wait(1)
			for _, other in ipairs(workspace:GetDescendants()) do
				if other:IsA("Part") and other ~= part and other.Anchored == false then
					local crash = Instance.new("BodyVelocity")
					crash.MaxForce = Vector3.new(1, 1, 1) * 100000
					crash.Velocity = Vector3.new(math.random(-80, 80), math.random(20, 90), math.random(-80, 80))
					crash.Parent = other
					task.delay(0.6, function()
						safeDestroy(crash)
					end)
				end
			end
			safeDestroy(part)
		end)
	end,
	shootTime = function(part)
		part.Anchored = true
		part.BrickColor = BrickColor.new("Bright blue")
	end,
	shootFire = function(part)
		local fire = Instance.new("Fire")
		fire.Parent = part
		fire.Size = 8
		fire.Heat = 25
	end,
	shootFreeze = function(part)
		part.Anchored = true
		part.Material = Enum.Material.Glacier
	end,
	shootTornado = function(part)
		local spin = Instance.new("BodyAngularVelocity")
		spin.MaxTorque = Vector3.new(1, 1, 1) * 200000
		spin.AngularVelocity = Vector3.new(0, 90, 0)
		spin.Parent = part
		part.CanCollide = false
	end,
	shootLightning = function(part)
		local sparkles = Instance.new("Sparkles")
		sparkles.Parent = part
		sparkles.SparkleColor = Color3.fromRGB(255, 240, 120)
	end,
	shootFlood = function(part)
		local water = Instance.new("Part")
		water.Size = Vector3.new(20, 1, 20)
		water.Position = part.Position - Vector3.new(0, 2, 0)
		water.Anchored = true
		water.Material = Enum.Material.Water
		water.Transparency = 0.3
		water.Parent = workspace
	end,
	shootGravity = function(part)
		local gravity = Instance.new("BodyForce")
		gravity.Force = Vector3.new(0, -2000, 0)
		gravity.Parent = part
	end,
	shootSlide = function(part)
		part.Material = Enum.Material.Ice
		part.Friction = 0.02
	end,
	shootInvisible = function(part)
		part.Transparency = 1
		part.CanCollide = false
	end,
	shootUnanchored = function(part)
		part.Anchored = false
		part.CanCollide = true
	end,
	shootBigHead = function(part)
		local targetCharacter = player.Character
		if targetCharacter and targetCharacter:FindFirstChild("Head") then
			local head = targetCharacter:FindFirstChild("Head")
			createTween(head, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
				Size = head.Size + Vector3.new(3, 3, 3),
			}):Play()
		end
	end,
	shootButterFly = function(part)
		task.spawn(function()
			for _ = 1, 6 do
				task.wait(0.1)
				part.Position = part.Position + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3))
			end
		end)
	end,
	shootPlant = function(part)
		local plant = Instance.new("Part")
		plant.Size = Vector3.new(1, 6, 1)
		plant.Position = part.Position + Vector3.new(0, 3, 0)
		plant.Anchored = true
		plant.BrickColor = BrickColor.new("Bright green")
		plant.Parent = workspace
	end,
	shootWater = function(part)
		part.Material = Enum.Material.Water
		part.Transparency = 0.25
	end,
	shootMeteor = function(part)
		task.spawn(function()
			for _ = 1, 5 do
				task.wait(0.3)
				local meteor = Instance.new("Part")
				meteor.Size = Vector3.new(6, 2, 6)
				meteor.Position = part.Position + Vector3.new(math.random(-20, 20), 40, math.random(-20, 20))
				meteor.Anchored = false
				meteor.BrickColor = BrickColor.new("Dark orange")
				meteor.Material = Enum.Material.Neon
				meteor.Parent = workspace
				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.MaxForce = Vector3.new(1, 1, 1) * 100000
				bodyVelocity.Velocity = Vector3.new(0, -120, 0)
				bodyVelocity.Parent = meteor
				task.delay(1, function()
					safeDestroy(meteor)
				end)
			end
		end)
	end,
	shootStun = function(part)
		local targetCharacter = player.Character
		if targetCharacter and targetCharacter:FindFirstChild("Humanoid") then
			local humanoid = targetCharacter:FindFirstChild("Humanoid")
			humanoid.WalkSpeed = 0
			task.delay(2, function()
				if humanoid and humanoid.Parent then
					humanoid.WalkSpeed = 16
				end
			end)
		end
	end,
	shootSound = function(part)
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://9125406956"
		sound.Volume = 1
		sound.Parent = part
		sound:Play()
	end,
}

-- ===========================================================================
-- 11. Main shoot handler
-- ===========================================================================
local function getActiveModes()
	local active = {}
	for modeName, enabled in pairs(MODE_CONFIG) do
		if enabled and PART_FACTORY[modeName] then
			table.insert(active, modeName)
		end
	end
	return active
end

local function firePrimary()
	local activeModes = getActiveModes()
	if #activeModes == 0 then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Safe usage of the mouse Hit value
	local targetPosition = rootPart.Position + rootPart.CFrame.LookVector * 25
	pcall(function()
		if mouse and mouse.Hit then
			targetPosition = mouse.Hit.Position
		end
	end)

	local direction = (targetPosition - rootPart.Position).Unit

	local basePart = createBasicPart(Vector3.new(4, 2, 4))
	basePart.Position = rootPart.Position + direction * 5
	basePart.CFrame = CFrame.lookAt(basePart.Position, targetPosition)
	basePart.Parent = workspace

	PerformanceRegistry.activeParts += 1
	if PerformanceRegistry.activeParts > PerformanceRegistry.maxParts then
		-- Light cleanup: destroy the oldest shot part to keep the registry bounded
		local oldestPart = workspace:FindFirstChild(basePart.Name)
		if oldestPart then
			safeDestroy(oldestPart)
		end
		PerformanceRegistry.activeParts -= 1
	end

	local shotPart = ShootPart.new(basePart)
	shotPart:launch(direction * 90, Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10)))

	for _, modeName in ipairs(activeModes) do
		local effect = MODE_EFFECTS[modeName]
		if effect then
			pcall(effect, basePart)
		end
	end

	task.spawn(function()
		task.wait(PerformanceRegistry.partLifetime)
		PerformanceRegistry.activeParts = math.max(0, PerformanceRegistry.activeParts - 1)
		safeDestroy(basePart)
	end)
end

-- ===========================================================================
-- 12. User interface
-- ===========================================================================
local function createInterface()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HipHub_GrowBlox"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 2147483000
	screenGui.Parent = playerGui

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 340, 0, 500)
	mainFrame.Position = UDim2.new(0, 12, 0.5, -250)
	mainFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Active = true
	mainFrame.Parent = screenGui

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = mainFrame

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 34)
	topBar.BackgroundColor3 = Color3.fromRGB(24, 27, 44)
	topBar.BorderSizePixel = 0
	topBar.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "GROWBLOX"
	title.TextColor3 = Color3.fromRGB(0, 220, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = topBar

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 28, 0, 28)
	closeButton.Position = UDim2.new(1, -32, 0.5, -14)
	closeButton.BackgroundTransparency = 1
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(160, 170, 200)
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 12
	closeButton.Active = true
	closeButton.Parent = topBar
	closeButton.MouseButton1Click:Connect(function()
		safeDestroy(screenGui)
		_G.HipHub_GrowBlox_Running = nil
	end)

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -24, 0, 26)
	statusLabel.Position = UDim2.new(0, 12, 0, 46)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Status: Ready (shootParts mode)"
	statusLabel.TextColor3 = Color3.fromRGB(210, 220, 250)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 11
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = mainFrame

	local modeHint = Instance.new("TextLabel")
	modeHint.Name = "ModeHint"
	modeHint.Size = UDim2.new(1, -24, 0, 24)
	modeHint.Position = UDim2.new(0, 12, 0, 74)
	modeHint.BackgroundTransparency = 1
	modeHint.Text = "Click to shoot. Change mode below."
	modeHint.TextColor3 = Color3.fromRGB(130, 145, 180)
	modeHint.Font = Enum.Font.Gotham
	modeHint.TextSize = 10
	modeHint.TextXAlignment = Enum.TextXAlignment.Left
	modeHint.Parent = mainFrame

	local buttons = {}
	local buttonOrder = {
		{ "shootParts", "Parts" },
		{ "shootNuke", "Nuke" },
		{ "shootMagnet", "Magnet" },
		{ "shootForceField", "ForceField" },
		{ "shootFlinger", "Flinger" },
		{ "shootSpin", "Spin" },
		{ "shootTrap", "Trap" },
		{ "shootSpawn", "Spawn" },
		{ "shootVehicle", "Vehicle" },
		{ "shootHouse", "House" },
		{ "shootSmoke", "Smoke" },
		{ "shootNormal", "Normal" },
		{ "shootGhost", "Ghost" },
		{ "shootResize", "Resize" },
		{ "shootTroll", "Troll" },
		{ "shootTeleport", "Teleport" },
		{ "shootBlackHole", "BlackHole" },
		{ "shootHeavy", "Heavy" },
		{ "shootLaunch", "Launch" },
		{ "shootBounce", "Bounce" },
		{ "shootExplode", "Explode" },
		{ "shootDrop", "Drop" },
		{ "shootBomb", "Bomb" },
		{ "shootCrash", "Crash" },
		{ "shootTime", "Time" },
		{ "shootFire", "Fire" },
		{ "shootFreeze", "Freeze" },
		{ "shootTornado", "Tornado" },
		{ "shootLightning", "Lightning" },
		{ "shootFlood", "Flood" },
		{ "shootGravity", "Gravity" },
		{ "shootSlide", "Slide" },
		{ "shootInvisible", "Invisible" },
		{ "shootUnanchored", "Unanchored" },
		{ "shootBigHead", "BigHead" },
		{ "shootButterFly", "ButterFly" },
		{ "shootPlant", "Plant" },
		{ "shootWater", "Water" },
		{ "shootMeteor", "Meteor" },
		{ "shootStun", "Stun" },
		{ "shootSound", "Sound" },
	}

	local modeScroll = Instance.new("ScrollingFrame")
	modeScroll.Name = "ModeScroll"
	modeScroll.Size = UDim2.new(1, -24, 1, -170)
	modeScroll.Position = UDim2.new(0, 12, 0, 110)
	modeScroll.BackgroundTransparency = 1
	modeScroll.BorderSizePixel = 0
	modeScroll.ScrollBarThickness = 4
	modeScroll.ScrollBarImageColor3 = Color3.fromRGB(0, 160, 220)
	modeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	modeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	modeScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	modeScroll.Active = true
	modeScroll.Parent = mainFrame

	local grid = Instance.new("UIGridLayout")
	grid.Name = "ModeGrid"
	grid.CellSize = UDim2.new(0, 96, 0, 30)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = modeScroll

	for i, buttonDef in ipairs(buttonOrder) do
		local modeName = buttonDef[1]
		local label = buttonDef[2]
		local button = Instance.new("TextButton")
		button.Name = modeName
		button.Size = UDim2.new(0, 96, 0, 30)
		button.BackgroundColor3 = Color3.fromRGB(32, 36, 58)
		button.BorderSizePixel = 0
		button.Text = label
		button.TextColor3 = Color3.fromRGB(200, 210, 240)
		button.Font = Enum.Font.Gotham
		button.TextSize = 11
		button.Active = true
		button.Parent = modeScroll

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			for mode, _ in pairs(MODE_CONFIG) do
				MODE_CONFIG[mode] = false
			end
			MODE_CONFIG[modeName] = true
			statusLabel.Text = "Status: " .. label .. " mode selected"
			for _, otherButton in ipairs(buttons) do
				otherButton.BackgroundColor3 = Color3.fromRGB(32, 36, 58)
			end
			button.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
		end)

		table.insert(buttons, button)
	end

	-- Highlight the default mode
	if buttons[1] then
		buttons[1].BackgroundColor3 = Color3.fromRGB(0, 160, 220)
	end

	local shootButton = Instance.new("TextButton")
	shootButton.Name = "ShootButton"
	shootButton.Size = UDim2.new(1, -24, 0, 40)
	shootButton.Position = UDim2.new(0, 12, 1, -52)
	shootButton.BackgroundColor3 = Color3.fromRGB(0, 200, 160)
	shootButton.BorderSizePixel = 0
	shootButton.Text = "SHOOT"
	shootButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	shootButton.Font = Enum.Font.GothamBold
	shootButton.TextSize = 13
	shootButton.Active = true
	shootButton.Parent = mainFrame

	local shootCorner = Instance.new("UICorner")
	shootCorner.CornerRadius = UDim.new(0, 6)
	shootCorner.Parent = shootButton

	shootButton.MouseButton1Click:Connect(function()
		firePrimary()
	end)

	shootButton.MouseEnter:Connect(function()
		createTween(shootButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(0, 230, 180) }):Play()
	end)
	shootButton.MouseLeave:Connect(function()
		createTween(shootButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(0, 200, 160) }):Play()
	end)

	return screenGui
end

-- ===========================================================================
-- 13. Error boundary
-- ===========================================================================
local success, screenGui = pcall(createInterface)
if not success then
	warn("GrowBlox UI initialization failed: " .. tostring(screenGui))
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if isMobileDevice() then
			return
		end
		firePrimary()
	end
end

pcall(function()
	if UIS and UIS.InputBegan then
		UIS.InputBegan:Connect(onInputBegan)
	end
end)

-- ===========================================================================
-- 14. Public test/debug API
-- ===========================================================================
_G.GrowBlox = {
	fire = firePrimary,
	setMode = function(modeName)
		if MODE_CONFIG[modeName] == nil then
			return false, "unknown mode"
		end
		for mode in pairs(MODE_CONFIG) do
			MODE_CONFIG[mode] = false
		end
		MODE_CONFIG[modeName] = true
		return true
	end,
	getActiveMode = function()
		for mode, enabled in pairs(MODE_CONFIG) do
			if enabled then
				return mode
			end
		end
		return nil
	end,
	getUi = function()
		return screenGui
	end,
	destroy = function()
		safeDestroy(screenGui)
		_G.HipHub_GrowBlox_Running = nil
		_G.GrowBlox = nil
	end,
}
