--[[
	MovementManager

	Manages a character's ground speed,
	acceleration, freeze/unfreeze, and constraint factories used by
	traversal states. Identical surface for the local player and for
	NPCs.

	States set a target speed via :SetBaseSpeed() and Update() ramps the
	humanoid's WalkSpeed toward that target using Accel_Rate / Decel_Rate.
]]

local RunService = game:GetService("RunService")

local MovementManager = {}
MovementManager.__index = MovementManager

local DEFAULT_CONFIG = {
	Accel_Rate = 40,
	Decel_Rate = 32,
	Walk_Speed = 14,
	Run_Speed = 32,
	Max_Speed = 80,
}

local CHARACTER_FRICTION = 0.1
local CHARACTER_FRICTION_WEIGHT = 1
local CHARACTER_DENSITY = 0.7
local CHARACTER_ELASTICITY = 0
local CHARACTER_ELASTICITY_WEIGHT = 1

local function flattenHorizontal(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function MovementManager.new(Runtime)
	local self = setmetatable({}, MovementManager)
	self._Controller = Runtime
	self.Name = "MovementManager"
	self._config = table.clone(DEFAULT_CONFIG)

	self._Character = nil :: Model?
	self._Humanoid = nil :: Humanoid?
	self._RootPart = nil :: BasePart?
	self._RootAttachment = nil :: Attachment?

	self._baseSpeed = 0
	self._currentSpeed = 0
	self._frozen = false
	self._frozenTarget = 0

	self._connections = {} :: { RBXScriptConnection }
	self._descendantAddedConn = nil :: RBXScriptConnection?
	return self
end

function MovementManager:Init() end

function MovementManager:Start()
	table.insert(
		self._connections,
		RunService.Heartbeat:Connect(function(dT)
			self:Update(dT)
		end)
	)
end

function MovementManager:Update(dT: number)
	if not self._Humanoid then
		return
	end
	if self._frozen then
		return
	end

	local target = self._baseSpeed
	if self._currentSpeed < target then
		self._currentSpeed = math.min(target, self._currentSpeed + self._config.Accel_Rate * dT)
	elseif self._currentSpeed > target then
		self._currentSpeed = math.max(target, self._currentSpeed - self._config.Decel_Rate * dT)
	end

	self._currentSpeed = math.clamp(self._currentSpeed, 0, self._config.Max_Speed)
	self._Humanoid.WalkSpeed = self._currentSpeed
end

--[[ ========================================
	 Speed API
	======================================== ]]

function MovementManager:SetBaseSpeed(speed: number)
	self._baseSpeed = math.clamp(speed, 0, self._config.Max_Speed)
	if self._frozen then
		self._frozenTarget = self._baseSpeed
	end
end

function MovementManager:GetTargetSpeed(): number
	return self._baseSpeed
end

function MovementManager:GetCurrentSpeed(): number
	return self._currentSpeed
end

function MovementManager:GetWalkSpeed(): number
	return self._config.Walk_Speed
end

function MovementManager:GetRunSpeed(): number
	return self._config.Run_Speed
end

function MovementManager:SetSpeedImmediate(speed: number)
	speed = math.clamp(speed, 0, self._config.Max_Speed)
	self._baseSpeed = speed
	self._currentSpeed = speed
	if not self._frozen and self._Humanoid then
		self._Humanoid.WalkSpeed = speed
	end
end

function MovementManager:SyncToPhysicsSpeed()
	self._currentSpeed = math.clamp(self:GetHorizontalSpeed(), 0, self._config.Max_Speed)
end

function MovementManager:SetMovementConfig(config: { [string]: number })
	for key, value in config do
		if DEFAULT_CONFIG[key] ~= nil and type(value) == "number" then
			self._config[key] = value
		end
	end
end

function MovementManager:ResetMovementConfig()
	self._config = table.clone(DEFAULT_CONFIG)
end

--[[ ========================================
	 Freeze / Unfreeze
	======================================== ]]

function MovementManager:FreezeMovement()
	self._frozen = true
	self._frozenTarget = self._baseSpeed
	self._currentSpeed = 0
	if self._Humanoid then
		self._Humanoid.WalkSpeed = 0
		self._Humanoid:Move(Vector3.zero)
	end
	if self._RootPart then
		local velocity = self._RootPart.AssemblyLinearVelocity
		self._RootPart.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
	end
end

function MovementManager:UnfreezeMovement()
	self._frozen = false
	self._baseSpeed = self._frozenTarget
	self._currentSpeed = math.clamp(self:GetHorizontalSpeed(), 0, self._config.Max_Speed)
	if self._Humanoid then
		self._Humanoid.WalkSpeed = self._currentSpeed
	end
end

function MovementManager:IsFrozen(): boolean
	return self._frozen
end

--[[ ========================================
	 Physics Readers / Writers
	======================================== ]]

function MovementManager:GetHorizontalSpeed(): number
	if not self._RootPart then
		return 0
	end
	return flattenHorizontal(self._RootPart.AssemblyLinearVelocity).Magnitude
end

function MovementManager:GetVelocity(): Vector3
	if not self._RootPart then
		return Vector3.zero
	end
	return self._RootPart.AssemblyLinearVelocity
end

--- Returns the world-space movement direction the character is currently
--- requesting. For players this is driven by Roblox input; for NPCs it is
--- driven by Humanoid:Move(...) called by the AI.
function MovementManager:GetMoveDirection(): Vector3
	if not self._Humanoid then
		return Vector3.zero
	end
	return self._Humanoid.MoveDirection
end

function MovementManager:SetVelocity(velocity: Vector3)
	if self._RootPart then
		self._RootPart.AssemblyLinearVelocity = velocity
	end
end

function MovementManager:ApplyImpulse(impulse: Vector3)
	if self._RootPart then
		self._RootPart:ApplyImpulse(impulse * self._RootPart.AssemblyMass)
	end
end

--[[ ========================================
	 Constraint Factories
	======================================== ]]

function MovementManager:GetRootAttachment(): Attachment?
	if self._RootAttachment and self._RootAttachment.Parent then
		return self._RootAttachment
	end

	if not self._RootPart then
		return nil
	end

	local existing = self._RootPart:FindFirstChild("RootAttachment")
		or self._RootPart:FindFirstChild("RootRigAttachment")
	if existing and existing:IsA("Attachment") then
		self._RootAttachment = existing
		return existing
	end

	local att = Instance.new("Attachment")
	att.Name = "RootAttachment"
	att.Parent = self._RootPart
	self._RootAttachment = att
	return att
end

function MovementManager:CreateLinearVelocity(config: { [string]: any }): LinearVelocity?
	local att = self:GetRootAttachment()
	if not att then
		return nil
	end

	local lv = Instance.new("LinearVelocity")
	lv.Name = config.Name or "StateLinearVelocity"
	lv.Attachment0 = att
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = config.MaxForce or 5000
	lv.VectorVelocity = config.Velocity or Vector3.zero
	return lv
end

function MovementManager:CreateVectorForce(config: { [string]: any }): VectorForce?
	local att = self:GetRootAttachment()
	if not att then
		return nil
	end

	local vf = Instance.new("VectorForce")
	vf.Name = config.Name or "StateVectorForce"
	vf.Attachment0 = att
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.ApplyAtCenterOfMass = true
	vf.Force = config.Force or Vector3.zero
	return vf
end

function MovementManager:CreateAlignOrientation(config: { [string]: any }): AlignOrientation?
	local att = self:GetRootAttachment()
	if not att then
		return nil
	end

	local ao = Instance.new("AlignOrientation")
	ao.Name = config.Name or "StateAlignOrientation"
	ao.Attachment0 = att
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.MaxTorque = config.MaxTorque or 100000
	ao.Responsiveness = config.Responsiveness or 20
	ao.CFrame = CFrame.lookAt(Vector3.zero, config.Direction or Vector3.new(0, 0, 1))
	return ao
end

--[[ ========================================
	 Character Lifecycle
	======================================== ]]

function MovementManager:OnCharacterAdded(character: Model)
	self._Character = character
	self._Humanoid = self._Controller:GetHumanoid()
	self._RootPart = self._Controller:GetRootPart()
	self._RootAttachment = nil

	self._baseSpeed = 0
	self._currentSpeed = 0
	self._frozen = false
	self._frozenTarget = 0

	if self._RootPart then
		self:GetRootAttachment()
	end

	self:_normalizeCharacterFriction(character)

	if self._descendantAddedConn then
		self._descendantAddedConn:Disconnect()
	end
	self._descendantAddedConn = character.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			self:_applyFrictionToPart(desc)
		end
	end)
end

function MovementManager:OnCharacterRemoving()
	if self._descendantAddedConn then
		self._descendantAddedConn:Disconnect()
		self._descendantAddedConn = nil
	end
	self._Character = nil
	self._Humanoid = nil
	self._RootPart = nil
	self._RootAttachment = nil
	self._baseSpeed = 0
	self._currentSpeed = 0
	self._frozen = false
end

function MovementManager:Destroy()
	for _, c in self._connections do
		c:Disconnect()
	end
	table.clear(self._connections)
	if self._descendantAddedConn then
		self._descendantAddedConn:Disconnect()
		self._descendantAddedConn = nil
	end
end

function MovementManager:_normalizeCharacterFriction(character: Model)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			self:_applyFrictionToPart(part)
		end
	end
end

function MovementManager:_applyFrictionToPart(part: BasePart)
	part.CustomPhysicalProperties = PhysicalProperties.new(
		CHARACTER_DENSITY,
		CHARACTER_FRICTION,
		CHARACTER_ELASTICITY,
		CHARACTER_FRICTION_WEIGHT,
		CHARACTER_ELASTICITY_WEIGHT
	)
end

return MovementManager
