--[[
	NpcRuntimeDriver

	Client-side visual host for one server-authoritative NPC. It clones a rig,
	attaches the generic CharacterRuntime/manager stack, and drives visuals from
	replicated snapshots only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterRuntime = require(ReplicatedStorage.Shared.Classes.CharacterRuntime)
local NPCRegistry = require(ReplicatedStorage.Shared.Classes.NPCS.NPCRegistry)

local SHARED_MANAGERS = ReplicatedStorage.Shared.Classes.Managers
local INTERPOLATION_DELAY = 0.1
local FOLLOW_DEADZONE = 1.5
local CORRECTION_DISTANCE = 12

local NpcRuntimeDriver = {}
NpcRuntimeDriver.__index = NpcRuntimeDriver

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function collectManagerModules(): { ModuleScript }
	local list = {}
	for _, child in SHARED_MANAGERS:GetChildren() do
		if child:IsA("ModuleScript") and child.Name:match("Manager$") then
			table.insert(list, child)
		end
	end

	local inputFolder = SHARED_MANAGERS:FindFirstChild("Input")
	local npcInput = inputFolder and inputFolder:FindFirstChild("NpcInputProvider")
	if npcInput and npcInput:IsA("ModuleScript") then
		table.insert(list, npcInput)
	end

	return list
end

local function normalizeModel(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanQuery = desc.Name == "HumanoidRootPart"
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
end

local function cloneModel(npcType: string): Model
	local archetype = NPCRegistry.Get(npcType)
	local modelName = archetype and archetype.Model or npcType
	local assets = ReplicatedStorage.Shared:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local source = models and models:FindFirstChild(modelName)

	if source and source:IsA("Model") then
		return source:Clone()
	end

	error(`[NpcRuntimeDriver]: Missing NPC model {modelName} for {npcType}`)
end

function NpcRuntimeDriver.new(packet)
	local self = setmetatable({}, NpcRuntimeDriver)
	self.Id = packet.id
	self.NpcType = packet.npcType
	self._snapshots = {}
	self._model = cloneModel(packet.npcType)
	self._model.Name = `NPC_{packet.id}_{packet.npcType}`
	normalizeModel(self._model)
	self._model.Parent = workspace

	self._runtime = CharacterRuntime.new({
		managerModules = collectManagerModules(),
		context = {
			kind = "npc",
			npcId = packet.id,
			npcType = packet.npcType,
		},
	})
	self._runtime:Initialize()
	self._runtime:AttachCharacter(self._model)

	self:_snapTo(packet.p)
	self:ApplySnapshot(packet)
	self:RenderStep(os.clock(), true)
	return self
end

function NpcRuntimeDriver:ApplySnapshot(snapshot)
	table.insert(self._snapshots, snapshot)
	while #self._snapshots > 2 do
		table.remove(self._snapshots, 1)
	end
end

function NpcRuntimeDriver:RenderStep(now: number, forceLatest: boolean?)
	local snapshot = self:_getRenderSnapshot(now, forceLatest)
	if not snapshot then
		return
	end

	local rootPart = self:GetRootPart()
	local humanoid = self:GetHumanoid()
	if not rootPart or not humanoid then
		return
	end

	local offset = flatten(snapshot.p - rootPart.Position)
	local distance = offset.Magnitude

	if distance > CORRECTION_DISTANCE then
		self:_snapTo(snapshot.p)
		humanoid:Move(Vector3.zero, false)
		return
	end

	if distance <= FOLLOW_DEADZONE then
		humanoid:Move(Vector3.zero, false)
		return
	end

	humanoid:Move(offset.Unit, false)
end

function NpcRuntimeDriver:GetRootPart(): BasePart?
	return self._runtime and self._runtime:GetRootPart() or nil
end

function NpcRuntimeDriver:GetHumanoid(): Humanoid?
	return self._runtime and self._runtime:GetHumanoid() or nil
end

function NpcRuntimeDriver:Destroy()
	if self._runtime then
		self._runtime:Destroy()
		self._runtime = nil
	end
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
	table.clear(self._snapshots)
end

function NpcRuntimeDriver:_snapTo(position: Vector3)
	if not self._model or not self._model.Parent then
		return
	end

	local rootPart = self:GetRootPart()
	local forward = rootPart and flatten(rootPart.CFrame.LookVector) or Vector3.new(0, 0, -1)
	if forward.Magnitude <= 1e-4 then
		forward = Vector3.new(0, 0, -1)
	end
	self._model:PivotTo(CFrame.lookAt(position, position + forward.Unit))
end

function NpcRuntimeDriver:_getRenderSnapshot(now: number, forceLatest: boolean?)
	if #self._snapshots == 0 then
		return nil
	end
	if forceLatest or #self._snapshots == 1 then
		return self._snapshots[#self._snapshots]
	end

	local older = self._snapshots[1]
	local newer = self._snapshots[2]
	local renderTime = now - INTERPOLATION_DELAY
	local span = math.max(newer.t - older.t, 1e-4)
	local alpha = math.clamp((renderTime - older.t) / span, 0, 1)

	return {
		id = newer.id,
		p = older.p:Lerp(newer.p, alpha),
		t = renderTime,
		npcType = newer.npcType,
	}
end

return NpcRuntimeDriver
