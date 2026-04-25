--[[
	NPCStateMachine

	Pure transition rules for the server-side NPC behavior loop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPCContract = require(ReplicatedStorage.Shared.Classes.NPCS.NPCContract)

local NPCStateMachine = {}

function NPCStateMachine.Evaluate(entity, target: Player?, _dt: number): number
	local state = entity.State
	local distance = entity:GetTargetDistance(target)
	local greetRange = entity.Archetype.GreetRange or 5

	if state == NPCContract.State.Idle then
		return if target then NPCContract.State.Chase else NPCContract.State.Idle
	end

	if state == NPCContract.State.Chase then
		if not target then
			return NPCContract.State.Idle
		end
		if distance and distance <= greetRange then
			return NPCContract.State.Greet
		end
		return NPCContract.State.Chase
	end

	if state == NPCContract.State.Greet then
		if not target then
			return NPCContract.State.Idle
		end
		if os.clock() < entity.GreetCooldownEndsAt then
			return NPCContract.State.Greet
		end
		return NPCContract.State.Chase
	end

	return NPCContract.State.Idle
end

return NPCStateMachine
