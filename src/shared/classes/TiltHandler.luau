--[[
	TiltHandler - Applies spine/root tilt based on horizontal velocity
	so the character leans into movement direction.

	Accepts an optional config table to control tilt intensity per-character.
	Defaults produce the original subtle lean for standard characters.
]]

local RunService = game:GetService("RunService")

local DEFAULT_CONFIG = {
	ForwardTilt = 0.2,
	SideTilt = 0.33,
	LerpAlpha = 0.1,
	SpeedThreshold = 2,
	SpeedScale = 30,
}

local TiltHandler = {}

--- Starts applying tilt to the character's root joint.
function TiltHandler.Start(character: Model, config: { [string]: number }?): () -> ()
	local cfg = {}
	for k, v in DEFAULT_CONFIG do
		cfg[k] = (config and config[k]) or v
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local rootJoint = root and root:FindFirstChild("RootJoint")

	if not (humanoid and root and rootJoint and rootJoint:IsA("Motor6D")) then
		return function() end
	end

	local originalC0 = rootJoint.C0

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not character.Parent or not root.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local vel = root.Velocity * Vector3.new(1, 0, 1)
		local forwardAngle = 0
		local sideAngle = 0

		if vel.Magnitude > cfg.SpeedThreshold then
			local dir = vel.Unit
			local speedFactor = math.clamp((vel.Magnitude - cfg.SpeedThreshold) / cfg.SpeedScale, 0, 1)
			sideAngle = root.CFrame.RightVector:Dot(dir) * speedFactor
			forwardAngle = root.CFrame.LookVector:Dot(dir) * speedFactor
		end

		local targetC0 = originalC0 * CFrame.Angles(forwardAngle * cfg.ForwardTilt, -sideAngle * cfg.SideTilt, 0)
		rootJoint.C0 = rootJoint.C0:Lerp(targetC0, cfg.LerpAlpha)
	end)

	return function()
		if connection then
			connection:Disconnect()
		end
	end
end

return TiltHandler
