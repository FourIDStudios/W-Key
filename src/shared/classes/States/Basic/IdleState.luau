--[[
	IdleState

	Grounded, not moving. Plays IdleAnimation via AnimationManager.
]]

local BaseState = require(script:FindFirstAncestor("States").BaseState)

local IdleState = setmetatable({}, { __index = BaseState })
IdleState.__index = IdleState
IdleState.Priority = 0
IdleState.Name = "IdleState"

local DEFAULT_CONFIG = {}

function IdleState.new(Controller, moduleRef)
	local self = setmetatable(BaseState.new(Controller, moduleRef), IdleState)
	self.Config = table.clone(DEFAULT_CONFIG)
	return self
end

function IdleState:CanEnter(): boolean
	local sensors = self:GetManager("SensorManager").Sensors
	local grounded = sensors["GroundSensor"] and sensors["GroundSensor"].SensedPart ~= nil
	local humanoid = self._Controller:GetHumanoid()
	local moveDir = humanoid and humanoid.MoveDirection or Vector3.zero
	return grounded and moveDir.Magnitude < 0.1
end

function IdleState:Enter()
	local movementManager = self:GetManager("MovementManager")
	if movementManager then
		movementManager:SetBaseSpeed(0)
	end

	local animationManager = self:GetManager("AnimationManager")
	if not animationManager then
		return
	end

	local anim = self:GetAnimation("IdleAnimation")
	if anim then
		animationManager:Play(anim, Enum.AnimationPriority.Idle)
	end
end

function IdleState:Update(dT: number) end
function IdleState:Exit() end

return IdleState
