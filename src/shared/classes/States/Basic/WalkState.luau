--[[
	WalkState

	Grounded and moving. Plays WalkAnimation and drives MovementManager toward
	the configured walk speed.
]]

local BaseState = require(script:FindFirstAncestor("States").BaseState)

local WalkState = setmetatable({}, { __index = BaseState })
WalkState.__index = WalkState
WalkState.Priority = 1
WalkState.Name = "WalkState"

function WalkState.new(Controller, moduleRef)
	local self = setmetatable(BaseState.new(Controller, moduleRef), WalkState)
	self.Config = {}
	return self
end

function WalkState:CanEnter(): boolean
	local sensors = self:GetManager("SensorManager").Sensors
	local grounded = sensors["GroundSensor"] and sensors["GroundSensor"].SensedPart ~= nil
	local humanoid = self._Controller:GetHumanoid()
	local moveDir = humanoid and humanoid.MoveDirection or Vector3.zero
	return grounded and moveDir.Magnitude > 0.1
end

function WalkState:Enter()
	local movementManager = self:GetManager("MovementManager")
	if movementManager then
		movementManager:SetBaseSpeed(movementManager:GetWalkSpeed())
	end

	local animationManager = self:GetManager("AnimationManager")
	if not animationManager then
		return
	end

	local anim = self:GetAnimation("WalkAnimation")
	if anim then
		animationManager:Play(anim, Enum.AnimationPriority.Movement)
	end
end

function WalkState:Update(dT: number) end
function WalkState:Exit() end

return WalkState
