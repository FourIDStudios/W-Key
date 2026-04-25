--[[
	JumpState

	Air impulse state with buffered input, coyote time, and multi-jump.
	Input is sourced from the runtime's InputProvider.
]]

local BaseState = require(script:FindFirstAncestor("States").BaseState)

local JumpState = setmetatable({}, { __index = BaseState })
JumpState.__index = JumpState
JumpState.Priority = 5
JumpState.Name = "JumpState"

local DEFAULT_CONFIG = {
	Impulse = 50,
	HoldTime = 0.1,
	BufferTime = 0.05,
	CoyoteTime = 0.08,
	AirDragFactor = 2.4,
	MaxJumps = 2,
	ForwardJumpImpulse = 0,
	MinUpwardVel = 5,
}

function JumpState.new(Controller, moduleRef)
	local self = setmetatable(BaseState.new(Controller, moduleRef), JumpState)
	self.Config = table.clone(DEFAULT_CONFIG)
	self._jumpTimer = 0
	self._jumpsUsed = 0
	self._lastPressTime = -math.huge
	self._lastGroundedTime = 0
	self._isJumping = false
	self._lastJumpName = nil
	self._lastJumpVariant = 1
	self._input = nil
	self._actionPressedConn = nil
	return self
end

function JumpState:Init()
	self._input = self:GetManager("InputProvider")
	if self._input and self._input.ActionPressed then
		self._actionPressedConn = self._input.ActionPressed:Connect(function(actionName)
			if actionName == "Jump" then
				self._lastPressTime = os.clock()
			end
		end)
	end
end

function JumpState:CanEnter(): boolean
	local rootPart = self._Controller:GetRootPart()
	if not rootPart then
		return false
	end

	local vel = rootPart.AssemblyLinearVelocity
	if self._isJumping and vel.Y > self.Config.MinUpwardVel then
		return true
	end

	local now = os.clock()

	local sensors = self:GetManager("SensorManager").Sensors
	local grounded = sensors["GroundSensor"] and sensors["GroundSensor"].SensedPart ~= nil
	local SM = self:GetManager("StateManager")
	local currentState = SM and SM:GetCurrentState() or nil
	if grounded and currentState ~= "FallState" and currentState ~= "JumpState" then
		self._lastGroundedTime = now
		self._jumpsUsed = 0
	end

	local timeSincePress = now - self._lastPressTime
	if timeSincePress > self.Config.BufferTime then
		return false
	end

	local withinCoyote = (now - self._lastGroundedTime) < self.Config.CoyoteTime
	local airJumpsAvailable = self._jumpsUsed < self.Config.MaxJumps

	return withinCoyote or airJumpsAvailable
end

function JumpState:Enter()
	self:_doJump()
end

function JumpState:_doJump()
	local rootPart = self._Controller:GetRootPart()
	local humanoid = self._Controller:GetHumanoid()
	if not rootPart or not humanoid then
		return
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

	local vel = rootPart.AssemblyLinearVelocity
	local hVel = Vector3.new(vel.X, 0, vel.Z)

	local forwardImpulse = Vector3.zero
	if self.Config.ForwardJumpImpulse ~= 0 then
		forwardImpulse = rootPart.CFrame.LookVector * self.Config.ForwardJumpImpulse
	end

	rootPart.AssemblyLinearVelocity = Vector3.new(hVel.X, self.Config.Impulse, hVel.Z) + forwardImpulse

	self._jumpsUsed += 1
	self._jumpTimer = self.Config.HoldTime
	self._lastPressTime = -math.huge
	self._isJumping = true

	self:_playJumpAnimation()
end

function JumpState:_playJumpAnimation()
	local animationManager = self:GetManager("AnimationManager")
	if not animationManager then
		return
	end

	if self._jumpsUsed > 1 then
		animationManager:StopPlayingAnimations()
		local folder = self._animationFolder
		if not folder then
			return
		end

		local prefix = "DoubleJump"
		local pool = {}
		for _, anim in folder:GetChildren() do
			if anim:IsA("Animation") and anim.Name:sub(1, #prefix) == prefix then
				table.insert(pool, anim)
			end
		end
		if #pool > 0 then
			animationManager:Play(pool[math.random(1, #pool)], Enum.AnimationPriority.Action4, true)
		end
		return
	end

	local animName = `Jump{self._lastJumpVariant}Animation`
	local anim = self:GetAnimation(animName)
	if anim then
		animationManager:Play(anim, Enum.AnimationPriority.Action2)
		self._lastJumpName = animName
	end
	self._lastJumpVariant = self._lastJumpVariant % 2 + 1
end

function JumpState:Update(dT: number)
	local rootPart = self._Controller:GetRootPart()
	if not rootPart then
		return
	end

	local vel = rootPart.AssemblyLinearVelocity
	local hVel = Vector3.new(vel.X, 0, vel.Z)
	local newHVel = hVel * (1 - self.Config.AirDragFactor * dT)
	rootPart.AssemblyLinearVelocity = Vector3.new(newHVel.X, vel.Y, newHVel.Z)

	self._jumpTimer -= dT
	local timeSincePress = os.clock() - self._lastPressTime
	if timeSincePress < self.Config.BufferTime and self._jumpsUsed < self.Config.MaxJumps then
		self:_doJump()
	end
end

--- Resets the remaining air jumps. Used by traversal states (e.g. WallRunState)
--- to restore extra jumps after exit.
function JumpState:SetExtraJumps(extraJumps: number?)
	local jumpsToGive = math.clamp(extraJumps or self.Config.MaxJumps, 0, self.Config.MaxJumps)
	self._jumpsUsed = self.Config.MaxJumps - jumpsToGive
	self._lastGroundedTime = os.clock()
end

function JumpState:Exit()
	local movementManager = self:GetManager("MovementManager")
	if movementManager then
		movementManager:SyncToPhysicsSpeed()
	end
	self._isJumping = false
end

function JumpState:Destroy()
	if self._actionPressedConn then
		self._actionPressedConn:Disconnect()
		self._actionPressedConn = nil
	end
end

return JumpState
