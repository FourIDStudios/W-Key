--[[
	RunState

	Grounded + moving + Sprint input held. Input comes from the runtime's
	InputProvider.
]]

local BaseState = require(script:FindFirstAncestor("States").BaseState)

local RunState = setmetatable({}, { __index = BaseState })
RunState.__index = RunState
RunState.Priority = 2
RunState.Name = "RunState"

function RunState.new(Controller, moduleRef)
	local self = setmetatable(BaseState.new(Controller, moduleRef), RunState)
	self.Config = {}
	self._input = nil
	return self
end

function RunState:Init()
	self._input = self:GetManager("InputProvider")
end

function RunState:CanEnter(): boolean
	local sensors = self:GetManager("SensorManager").Sensors
	local grounded = sensors["GroundSensor"] and sensors["GroundSensor"].SensedPart ~= nil
	if not grounded then
		return false
	end

	local humanoid = self._Controller:GetHumanoid()
	local moveDir = humanoid and humanoid.MoveDirection or Vector3.zero
	if moveDir.Magnitude <= 0.1 then
		return false
	end

	if not self._input then
		return false
	end
	return self._input:IsPressed("Sprint")
end

function RunState:Enter()
	local movementManager = self:GetManager("MovementManager")
	if movementManager then
		movementManager:SetBaseSpeed(movementManager:GetRunSpeed())
	end

	local animationManager = self:GetManager("AnimationManager")
	if not animationManager then
		return
	end

	local anim = self:GetAnimation("RunAnimation")
	if anim then
		animationManager:Play(anim, Enum.AnimationPriority.Movement)
	end
end

function RunState:Update(dT: number) end
function RunState:Exit() end

return RunState
