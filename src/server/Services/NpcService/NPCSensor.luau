--[[
	NPCSensor

	Server-side target selection for lightweight NPC entities.
]]

local NPCSensor = {}

local function getRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function NPCSensor.IsTargetValid(entity, player: Player?, useLockRange: boolean?): boolean
	if not player or not isAlive(player) then
		return false
	end

	local root = getRootPart(player)
	if not root then
		return false
	end
	if entity.IsWithinLeash and not entity:IsWithinLeash(root.Position) then
		return false
	end

	local offset = flatten(root.Position - entity:GetPosition())
	local range = if useLockRange then entity.Archetype.TargetLockRange else entity.Archetype.VisionRange
	range = range or entity.Archetype.VisionRange or 40
	if offset.Magnitude > range then
		return false
	end

	if useLockRange then
		return true
	end

	if offset.Magnitude <= 1e-4 then
		return true
	end

	local halfAngle = math.rad(entity.Archetype.VisionAngle or 45)
	local forward = entity:GetForward()
	local dot = forward:Dot(offset.Unit)
	return dot >= math.cos(halfAngle)
end

function NPCSensor.FindBestTarget(entity, players: { Player }): Player?
	if NPCSensor.IsTargetValid(entity, entity.TargetPlayer, true) then
		return entity.TargetPlayer
	end

	local bestPlayer = nil
	local bestDistSq = math.huge
	local origin = entity:GetPosition()

	for _, player in players do
		if not NPCSensor.IsTargetValid(entity, player, false) then
			continue
		end

		local root = getRootPart(player)
		if not root then
			continue
		end

		local delta = flatten(root.Position - origin)
		local distSq = delta:Dot(delta)
		if distSq < bestDistSq then
			bestDistSq = distSq
			bestPlayer = player
		end
	end

	return bestPlayer
end

return NPCSensor
