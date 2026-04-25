--[[
	NPCEntity

	Server-authoritative NPC simulation object. The entity owns only the logical
	state and compact replicated pose; clients are responsible for local visuals.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPCContract = require(ReplicatedStorage.Shared.Classes.NPCS.NPCContract)
local NPCStateMachine = require(script.Parent.NPCStateMachine)
local NPCSensor = require(script.Parent.NPCSensor)

local NPCEntity = {}
NPCEntity.__index = NPCEntity

local DEFAULT_FORWARD = Vector3.new(0, 0, -1)

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function NPCEntity.new(id: number, npcType: string, archetype: { [string]: any }, cframe: CFrame)
	local self = setmetatable({}, NPCEntity)
	self.Id = id
	self.NpcType = npcType
	self.Archetype = archetype
	self.CFrame = cframe
	self.SpawnCFrame = cframe
	self.SpawnPosition = cframe.Position
	self.LeashRadius = archetype.LeashRadius or archetype.LeashSize or 50
	self.MoveDir = Vector3.zero
	self.State = NPCContract.State.Idle
	self.TargetPlayer = nil :: Player?
	self.StateTime = 0
	self.GreetCooldownEndsAt = 0
	self.LastSentState = self.State
	self.Dirty = true
	self.Destroyed = false
	self._lastGreetText = nil :: string?
	return self
end

function NPCEntity:Step(dt: number, players: { Player })
	if self.Destroyed then
		return nil
	end

	local target = NPCSensor.FindBestTarget(self, players)
	self.TargetPlayer = target
	local previousState = self.State

	local nextState = NPCStateMachine.Evaluate(self, target, dt)
	if nextState ~= self.State then
		self:SetState(nextState)
	else
		self.StateTime += dt
	end

	self.MoveDir = self:_computeMoveDir(target)
	self:_advancePose(dt)

	if previousState ~= self.State then
		self.Dirty = true
		if self.State == NPCContract.State.Greet then
			self._lastGreetText = self:PickGreetLine()
			return self._lastGreetText
		end
	end

	return nil
end

function NPCEntity:SetState(stateId: number)
	if self.State == stateId then
		return
	end
	self.State = stateId
	self.StateTime = 0
	self.Dirty = true
	if stateId == NPCContract.State.Greet then
		self.GreetCooldownEndsAt = os.clock() + (self.Archetype.GreetCD or 2.5)
	end
end

function NPCEntity:GetPosition(): Vector3
	return self.CFrame.Position
end

function NPCEntity:GetForward(): Vector3
	local look = flatten(self.CFrame.LookVector)
	if look.Magnitude <= 1e-4 then
		return DEFAULT_FORWARD
	end
	return look.Unit
end

function NPCEntity:GetTargetDistance(target: Player?): number?
	local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	return (root.Position - self:GetPosition()).Magnitude
end

function NPCEntity:IsWithinLeash(position: Vector3): boolean
	local offset = flatten(position - self.SpawnPosition)
	return offset.Magnitude <= self.LeashRadius
end

function NPCEntity:BuildSnapshot(): NPCContract.Snapshot
	return {
		id = self.Id,
		p = NPCContract.QuantizePosition(self.CFrame.Position),
		t = os.clock(),
	}
end

function NPCEntity:BuildSpawnPacket(): NPCContract.SpawnPacket
	local packet = self:BuildSnapshot()
	packet.npcType = self.NpcType
	return packet
end

function NPCEntity:BuildDespawnPacket(): NPCContract.DespawnPacket
	return {
		id = self.Id,
	}
end

function NPCEntity:PickGreetLine(): string
	local voice = self.Archetype.Voice
	if type(voice) ~= "table" or #voice == 0 then
		return self.Archetype.Name or self.NpcType
	end
	return voice[math.random(1, #voice)]
end

function NPCEntity:_computeMoveDir(target: Player?): Vector3
	local targetPosition = self.SpawnPosition
	if self.State == NPCContract.State.Chase then
		local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and self:IsWithinLeash(root.Position) then
			targetPosition = root.Position
		end
	end

	local offset = flatten(targetPosition - self.CFrame.Position)
	if offset.Magnitude <= 1e-4 then
		return Vector3.zero
	end
	return offset.Unit
end

function NPCEntity:_advancePose(dt: number)
	if self.MoveDir.Magnitude <= 1e-4 then
		return
	end

	local speed = self.Archetype.MoveSpeed or 12
	local unclampedPosition = self.CFrame.Position + self.MoveDir * speed * dt
	local position = self:_clampToLeash(unclampedPosition)
	self.CFrame = CFrame.lookAt(position, position + self.MoveDir)
	self.Dirty = true
end

function NPCEntity:_clampToLeash(position: Vector3): Vector3
	local center = self.SpawnPosition
	local horizontalOffset = flatten(position - center)
	if horizontalOffset.Magnitude <= self.LeashRadius then
		return position
	end

	local clampedOffset = horizontalOffset.Unit * self.LeashRadius
	return Vector3.new(center.X + clampedOffset.X, position.Y, center.Z + clampedOffset.Z)
end

return NPCEntity
