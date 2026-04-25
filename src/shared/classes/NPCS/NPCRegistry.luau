--[[

    NPCRegistry

    Defines the variouse configurations for our npcs.
]]

local Registry = {
	-- Beggar
	Beggar = {
		Name = "Beggar",
		Model = "Beggar",
		VisionRange = 40,
		VisionAngle = 180,
		GreetRange = 3,

		TargetLockRange = 50,
		MoveSpeed = 18,
		GreetCD = 2.5,
		LeashRadius = 50,

		Voice = {
			"Do you have any spare change?",
			"Can you spare a coin?",
			"Can you spare a coin for a poor beggar?",
			"I'm just a poor beggar, can you spare a coin?",
		},
	},

	-- Guard
	Guard = {
		Name = "Guard",
		Model = "Guard",
		VisionRange = 40,
		VisionAngle = 180,
		GreetRange = 3,

		TargetLockRange = 50,
		MoveSpeed = 18,
		GreetCD = 2.5,
		LeashRadius = 50,

		Voice = {
			"Stay out of trouble!",
		},
	},

	-- Merchant
	Merchant = {
		Name = "Merchant",
		Model = "Merchant",
		VisionRange = 40,
		VisionAngle = 180,
		GreetRange = 3,

		TargetLockRange = 50,
		MoveSpeed = 18,
		GreetCD = 2.5,
		LeashRadius = 50,

		Voice = {
			"Hey!, Need anything?",
			"Need anything? I've got some great deals!",
			"I've got some great deals, need anything?",
		},
	},
}

function Registry.Get(npcType: string)
	return Registry[npcType]
end

return Registry
