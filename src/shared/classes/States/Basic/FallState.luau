--[[
	FallState

	Ungrounded with no other higher-priority state active. Provides air
	steer, drag, uncontrolled-fall swap, and a simple landing roll.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BaseState = require(script:FindFirstAncestor("States").BaseState)

local FallState = setmetatable({}, { __index = BaseState })
FallState.__index = FallState
FallState.Priority = 3
FallState.Name = "FallState"

local DEFAULT_CONFIG = {
	AirSteerAccel = 5,
	AirMaxSteer = 70,
	AirSteerCapMultiplier = 1,
	AirDragFactor = 2.4,
	AirFallResistance = 0,
	TrackedFallMinSpeed = 2,
	UncontrolledFallTime = 0.25,
	LandedRollTime = 0.45,
	LandedLockTime = 0.2,
}

local LANDING_BYPASS_STATES: { [string]: boolean } = {
	WallRunState = true,
	WallClimbState = true,
}

local function isTrackedFallVelocity(yVel: number, minSpeed: number): boolean
	return yVel <= -math.max(0, minSpeed)
end

function FallState.new(Controller, moduleRef)
	local self = setmetatable(BaseState.new(Controller, moduleRef), FallState)
	self.Config = table.clone(DEFAULT_CONFIG)
	self._fallTime = 0
	self._isUncontrolled = false
	return self
end

function FallState:CanEnter(): boolean
	local sensors = self:GetManager("SensorManager").Sensors
	local grounded = sensors["GroundSensor"] and sensors["GroundSensor"].SensedPart ~= nil
	return not grounded
end

function FallState:Enter()
	self._fallTime = 0
	self._isUncontrolled = false

	local animationManager = self:GetManager("AnimationManager")
	local anim = self:GetAnimation("FallAnimation")
	if animationManager and anim then
		animationManager:Play(anim, Enum.AnimationPriority.Movement)
	end
end

function FallState:Update(dT: number)
	local rootPart = self._Controller:GetRootPart()
	local humanoid = self._Controller:GetHumanoid()
	if not rootPart or not humanoid then
		return
	end

	local movementManager = self:GetManager("MovementManager")
	local animationManager = self:GetManager("AnimationManager")
	if not movementManager then
		return
	end

	local moveDir = movementManager:GetMoveDirection()
	local inputDir = Vector3.new(moveDir.X, 0, moveDir.Z)

	local vel = rootPart.AssemblyLinearVelocity
	local hVel = Vector3.new(vel.X, 0, vel.Z)
	local newHVel = hVel
	local newYVel = vel.Y

	if newYVel < 0 then
		newYVel = newYVel * (1 - self.Config.AirFallResistance * dT)
		newYVel = math.max(newYVel, -150)
	end

	local steerCap = movementManager:GetRunSpeed() * self.Config.AirSteerCapMultiplier
	if self.Config.AirMaxSteer > 0 then
		steerCap = math.min(steerCap, self.Config.AirMaxSteer)
	end

	if moveDir.Magnitude > 0.1 then
		local nudge = inputDir * self.Config.AirSteerAccel * dT
		newHVel = hVel + nudge
		local newSpeed = newHVel.Magnitude
		if newSpeed > math.max(hVel.Magnitude, steerCap) then
			newHVel = newHVel.Unit * math.max(hVel.Magnitude, steerCap)
		end
	end

	newHVel = newHVel * (1 - self.Config.AirDragFactor * dT)
	rootPart.AssemblyLinearVelocity = Vector3.new(newHVel.X, newYVel, newHVel.Z)
	humanoid:Move(inputDir, false)
	movementManager:SetBaseSpeed(steerCap)

	local yVel = vel.Y
	if isTrackedFallVelocity(yVel, self.Config.TrackedFallMinSpeed) then
		self._fallTime += dT
		if self._fallTime >= self.Config.UncontrolledFallTime and not self._isUncontrolled then
			self._isUncontrolled = true
			local uncontrolled = self:GetAnimation("UncontrolledFallAnimation")
			if animationManager and uncontrolled then
				animationManager:Play(uncontrolled, Enum.AnimationPriority.Action4)
			end
		end
	elseif yVel >= 0 then
		self._fallTime = 0
	end
end

function FallState:Exit()
	local SM = self:GetManager("StateManager")
	local MM = self:GetManager("MovementManager")
	if SM then
		SM._previousStateName = self.Name
	end
	if MM then
		MM:SyncToPhysicsSpeed()
	end

	local sensors = self:GetManager("SensorManager").Sensors
	local grounded = sensors.GroundSensor and sensors.GroundSensor.SensedPart ~= nil
	local nextStateName = SM and SM._pendingStateName or nil
	local fallTime = self._fallTime
	self._fallTime = 0

	if not grounded or LANDING_BYPASS_STATES[nextStateName] then
		return
	end
	if fallTime <= 0 then
		return
	end

	if fallTime >= self.Config.LandedRollTime then
		local animationManager = self:GetManager("AnimationManager")
		local roll = self:GetAnimation("RollAnimation")
		if animationManager and roll then
			animationManager:Play(roll, Enum.AnimationPriority.Action4)
		end
		return self.Config.LandedLockTime
	end
end

return FallState
