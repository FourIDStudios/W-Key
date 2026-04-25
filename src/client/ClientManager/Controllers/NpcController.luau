--[[
	NpcController

	Client visual mirror for server-authoritative NPC entities. This controller
	receives compact snapshots, hosts one NpcRuntimeDriver per NPC, and shows
	greeting text via Roblox bubble chat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local NPCContract = require(ReplicatedStorage.Shared.Classes.NPCS.NPCContract)
local NpcRuntimeDriver = require(ReplicatedStorage.Shared.Classes.NPCS.NpcRuntimeDriver)

local NpcController = Knit.CreateController({
	Name = "NpcController",
})

function NpcController:KnitInit()
	self._drivers = {} :: { [number]: any }
	self._connections = {} :: { RBXScriptConnection }
	self._npcService = nil
end

function NpcController:KnitStart()
	self._npcService = Knit.GetService("NpcService")

	table.insert(
		self._connections,
		self._npcService.SnapshotStream:Connect(function(message)
			self:_handleSnapshotMessage(message)
		end)
	)

	table.insert(
		self._connections,
		self._npcService.NpcGreet:Connect(function(packet)
			self:_handleGreet(packet)
		end)
	)

	table.insert(
		self._connections,
		RunService.RenderStepped:Connect(function()
			local now = os.clock()
			for _, driver in self._drivers do
				driver:RenderStep(now)
			end
		end)
	)
end

function NpcController:_handleSnapshotMessage(message: NPCContract.SnapshotMessage)
	if type(message) ~= "table" or type(message.packets) ~= "table" then
		return
	end

	if message.kind == NPCContract.MessageKind.Spawn then
		for _, packet in message.packets do
			self:_spawnDriver(packet)
		end
	elseif message.kind == NPCContract.MessageKind.Update then
		for _, packet in message.packets do
			self:_updateDriver(packet)
		end
	elseif message.kind == NPCContract.MessageKind.Despawn then
		for _, packet in message.packets do
			self:_despawnDriver(packet.id)
		end
	end
end

function NpcController:_spawnDriver(packet)
	if self._drivers[packet.id] then
		self._drivers[packet.id]:Destroy()
	end
	self._drivers[packet.id] = NpcRuntimeDriver.new(packet)
end

function NpcController:_updateDriver(packet)
	local driver = self._drivers[packet.id]
	if not driver then
		return
	end
	driver:ApplySnapshot(packet)
end

function NpcController:_despawnDriver(id: number)
	local driver = self._drivers[id]
	if not driver then
		return
	end

	driver:Destroy()
	self._drivers[id] = nil
end

function NpcController:_handleGreet(packet: NPCContract.GreetPacket)
	local driver = self._drivers[packet.id]
	local rootPart = driver and driver:GetRootPart()
	if rootPart then
		local ok, err = pcall(function()
			TextChatService:DisplayBubble(rootPart, packet.text)
		end)
		if not ok then
			warn(`[NpcController]: DisplayBubble failed: {err}`)
		end
		return
	end

	print(`[NpcController]: NPC {packet.id}: {packet.text}`)
end

function NpcController:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)

	for id, driver in self._drivers do
		driver:Destroy()
		self._drivers[id] = nil
	end
end

return NpcController
