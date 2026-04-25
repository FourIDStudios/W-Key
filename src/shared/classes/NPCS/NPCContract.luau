--[[
    Defines the shared shape for our npcs.
]]

local Contract = {
	-- The Variouse States that the NPC can be in.
	State = {
		Idle = 1,
		Chase = 2,
		Greet = 3,
	},

	MessageKind = {
		Spawn = 1,
		Update = 2,
		Despawn = 3,
	},

	-- Performance Configuration
	Performance = {
		-- The rates at which the NPC will send data to the client.
		NearSendRate = 10,
		FarSendRate = 3,

		-- The Precision of our quantized data.
		PositionPrecision = 100,
	},
}

export type Snapshot = {
	id: number,
	p: Vector3,
	t: number,
}

export type SpawnPacket = Snapshot & {
	npcType: string,
}

export type DespawnPacket = {
	id: number,
}

export type SnapshotMessage = {
	kind: number,
	packets: { any },
}

export type GreetPacket = {
	id: number,
	text: string,
}

function Contract.QuantizePosition(position: Vector3)
	return Vector3.new(
		math.round(position.X * Contract.Performance.PositionPrecision) / Contract.Performance.PositionPrecision,
		math.round(position.Y * Contract.Performance.PositionPrecision) / Contract.Performance.PositionPrecision,
		math.round(position.Z * Contract.Performance.PositionPrecision) / Contract.Performance.PositionPrecision
	)
end

return Contract
