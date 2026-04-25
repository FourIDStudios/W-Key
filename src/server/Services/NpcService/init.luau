--[[
	NpcService

	Server-authoritative NPC simulation.

	Authoring convention:
	- Create a Workspace.NPCs folder in Studio.
	- Add BaseParts under it.
	- Set each part's `NpcType` attribute to a key in
	  ReplicatedStorage.Shared.Classes.NPCS.NPCRegistry.
	- The part CFrame becomes the NPC spawn pose. The source part is destroyed
	  after this service consumes it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local NPCContract = require(ReplicatedStorage.Shared.Classes.NPCS.NPCContract)
local NPCRegistry = require(ReplicatedStorage.Shared.Classes.NPCS.NPCRegistry)
local NPCEntity = require(script.NPCEntity)

local NpcService = Knit.CreateService({
	Name = "NpcService",
	Client = {
		SnapshotStream = Knit.CreateSignal(),
		NpcGreet = Knit.CreateSignal(),
	},
})

local FIXED_DT = 1 / NPCContract.Performance.NearSendRate
local RELEVANCE_BUFFER = 25

function NpcService:KnitInit()
	self._entities = {} :: { [number]: any }
	self._nextId = 0
	self._accumulator = 0
	self._playerKnown = {} :: { [Player]: { [number]: boolean } }
	self:_consumeWorkspaceSources()

	Players.PlayerRemoving:Connect(function(player)
		self._playerKnown[player] = nil
	end)
end

function NpcService:KnitStart()
	RunService.Heartbeat:Connect(function(dt)
		self._accumulator += dt
		while self._accumulator >= FIXED_DT do
			self._accumulator -= FIXED_DT
			self:_step(FIXED_DT)
		end
	end)
	print("[NpcService]: Started")
end

function NpcService:Spawn(npcType: string, cframe: CFrame)
	local archetype = NPCRegistry.Get(npcType)
	if not archetype then
		warn(`[NpcService]: Unknown NpcType "{npcType}"`)
		return nil
	end

	self._nextId += 1
	local entity = NPCEntity.new(self._nextId, npcType, archetype, cframe)
	self._entities[entity.Id] = entity
	return entity
end

function NpcService:Despawn(id: number)
	local entity = self._entities[id]
	if not entity then
		return
	end

	entity.Destroyed = true
	self._entities[id] = nil

	local packet = entity:BuildDespawnPacket()
	for _, player in Players:GetPlayers() do
		local known = self._playerKnown[player]
		if known and known[id] then
			known[id] = nil
			self.Client.SnapshotStream:Fire(player, {
				kind = NPCContract.MessageKind.Despawn,
				packets = { packet },
			})
		end
	end
end

function NpcService:GetEntity(id: number)
	return self._entities[id]
end

function NpcService:_consumeWorkspaceSources()
	local folder = workspace:FindFirstChild("NPCs")
	if not folder then
		warn("[NpcService]: Workspace.NPCs not found; no Studio-authored NPC sources consumed")
		return
	end

	for _, child in folder:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end

		local npcType = child:GetAttribute("NpcType")
		if type(npcType) ~= "string" or npcType == "" then
			warn(`[NpcService]: {child:GetFullName()} missing string NpcType attribute`)
			continue
		end

		self:Spawn(npcType, child.CFrame)
		child:Destroy()
	end
end

function NpcService:_step(dt: number)
	local players = Players:GetPlayers()
	local greetEvents = {}

	for _, entity in self._entities do
		local greetText = entity:Step(dt, players)
		if greetText then
			table.insert(greetEvents, {
				entity = entity,
				text = greetText,
			})
		end
	end

	self:_replicate(players)

	for _, event in greetEvents do
		self:_fireGreet(event.entity, event.text)
	end
end

function NpcService:_replicate(players: { Player })
	for _, player in players do
		local known = self._playerKnown[player]
		if not known then
			known = {}
			self._playerKnown[player] = known
		end

		local spawnPackets = {}
		local updatePackets = {}
		local despawnPackets = {}

		for id, entity in self._entities do
			local relevant = self:_isRelevant(player, entity)
			local wasKnown = known[id] == true

			if relevant and not wasKnown then
				known[id] = true
				table.insert(spawnPackets, entity:BuildSpawnPacket())
			elseif relevant and wasKnown then
				table.insert(updatePackets, entity:BuildSnapshot())
			elseif not relevant and wasKnown then
				known[id] = nil
				table.insert(despawnPackets, entity:BuildDespawnPacket())
			end
		end

		self:_fireSnapshotBatch(player, NPCContract.MessageKind.Spawn, spawnPackets)
		self:_fireSnapshotBatch(player, NPCContract.MessageKind.Update, updatePackets)
		self:_fireSnapshotBatch(player, NPCContract.MessageKind.Despawn, despawnPackets)
	end
end

function NpcService:_fireSnapshotBatch(player: Player, kind: number, packets: { any })
	if #packets == 0 then
		return
	end
	self.Client.SnapshotStream:Fire(player, {
		kind = kind,
		packets = packets,
	})
end

function NpcService:_fireGreet(entity, text: string)
	for _, player in Players:GetPlayers() do
		if self:_isRelevant(player, entity) then
			self.Client.NpcGreet:Fire(player, {
				id = entity.Id,
				text = text,
			})
		end
	end
end

function NpcService:_isRelevant(player: Player, entity): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end

	local range = (entity.Archetype.TargetLockRange or entity.Archetype.VisionRange or 50) + RELEVANCE_BUFFER
	local delta = root.Position - entity:GetPosition()
	return delta:Dot(delta) <= range * range
end

return NpcService
