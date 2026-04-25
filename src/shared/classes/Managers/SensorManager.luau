--[[
	SensorManager

	Drives the character's ControllerPartSensor
	folder by performing raycasts / spherecasts each Heartbeat and writing the
	results back onto the sensor instances.

    Alone, this manager does nothing but is the core for the character's sensor system.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local IGNORE_SENSOR_TAG = "SENSOR_IGNORE"

local RaycastVisualizer = require(game:GetService("ReplicatedStorage").Shared.Classes.Util.RaycastVisualizer)
local RayVisualizer = RaycastVisualizer.new({
	AUTO_CLEANUP = true,
	MAX_VISUALIZERS = 25,
	LOG_MESSAGES = false,
})

local SensorManager = {}
SensorManager.__index = SensorManager

function SensorManager.new(Runtime)
	local self = setmetatable({}, SensorManager)
	self._Controller = Runtime
	self.Name = "SensorManager"
	self.Sensors = {} :: { [string]: any }
	self.DebugEnabled = false

	self._Character = nil :: Model?
	self._Humanoid = nil :: Humanoid?
	self._RootPart = nil :: BasePart?
	self._SensorDir = nil :: Instance?
	self._RaycastParams = nil :: RaycastParams?

	self._connections = {} :: { RBXScriptConnection }

	self.RAY_LENGTHS = {
		Ground = 4,
		Forward = 4,
		Wall = 3,
		Step = 2.5,
	}
	self.FORWARD_OFFSETS = {
		Head = 1.5,
		Chest = 0,
		Feet = -1.5,
	}

	-- FForwardDownSensor: cast a long downward ray from a point WELL above the
	-- character, ahead of the root. Origin sits above any reachable climb
	-- height so a single ray sees both climbable ledge tops (positive stepDelta
	-- relative to GroundSensor) AND deep drops / gaps below (negative stepDelta
	-- or no hit at all). Consumed by traversalUtil.
	self.FORWARD_DOWN = {
		Forward = 2.5, -- studs ahead of root
		OriginY = 4.0, -- studs above root; above max STEP_UP_CLIMB so ledge tops are visible
		Down = 10.0, -- long enough to also reach gap floors
	}

	return self
end

function SensorManager:Init() end

function SensorManager:Start()
	table.insert(
		self._connections,
		RunService.Heartbeat:Connect(function(dT)
			self:Update(dT)
		end)
	)
end

--[[ ========================================
	 Debug
	======================================== ]]

function SensorManager:SetDebugEnabled(enabled: boolean)
	self.DebugEnabled = enabled and true or false
end

function SensorManager:ToggleDebug()
	self.DebugEnabled = not self.DebugEnabled
end

--[[ ========================================
	 Sensor Handling
	======================================== ]]

function SensorManager:GetRaycastParams(): RaycastParams?
	return self._RaycastParams
end

function SensorManager:RegisterSensors()
	if not self._SensorDir then
		return
	end
	for _, sensor in self._SensorDir:GetChildren() do
		if sensor.Name:match("Sensor$") then
			self.Sensors[sensor.Name] = sensor
		end
	end
end

function SensorManager:Update(dT: number)
	if self._Character == nil then
		return
	end
	if self._RootPart == nil or not self._RootPart.Parent then
		return
	end
	self:HandleGroundSensor(self.Sensors["GroundSensor"])
	self:HandleForwardSensor(self.Sensors["FHeadSensor"], self.FORWARD_OFFSETS.Head)
	self:HandleForwardSensor(self.Sensors["FChestSensor"], self.FORWARD_OFFSETS.Chest)
	self:HandleForwardSensor(self.Sensors["FFeetSensor"], self.FORWARD_OFFSETS.Feet)
	self:HandleWallSensor(self.Sensors["LWallSensor"], -1)
	self:HandleWallSensor(self.Sensors["RWallSensor"], 1)
	self:HandleForwardDownSensor(self.Sensors["FForwardDownSensor"])
	self:HandleStepSensor(self.Sensors["FStepSensor"])
end

function SensorManager:HandleGroundSensor(sensor)
	if not sensor then
		return
	end

	local direction = Vector3.new(0, -self.RAY_LENGTHS.Ground, 0)
	local origin = self._RootPart.Position

	local result = workspace:Spherecast(origin, 1, direction, self._RaycastParams)
	if self.DebugEnabled then
		RayVisualizer:Draw(
			origin,
			result and result.Position or origin + direction,
			Color3.new(result and 1 or 0.5, 0, 0)
		)
	end

	if result then
		sensor.SensedPart = result.Instance
		sensor.HitNormal = result.Normal
		sensor.HitFrame = CFrame.new(result.Position)
	else
		sensor.SensedPart = nil
	end
end

function SensorManager:HandleForwardSensor(sensor, heightOffset: number)
	if not sensor then
		return
	end

	local origin = self._RootPart.Position + Vector3.new(0, heightOffset, 0)
	local direction = self._RootPart.CFrame.LookVector * self.RAY_LENGTHS.Forward

	local result = workspace:Raycast(origin, direction, self._RaycastParams)
	if self.DebugEnabled then
		RayVisualizer:Draw(
			origin,
			result and result.Position or origin + direction,
			Color3.new(0, result and 1 or 0.5, 0)
		)
	end

	if result then
		sensor.SensedPart = result.Instance
		sensor.HitNormal = result.Normal
		sensor.HitFrame = CFrame.new(result.Position)
	else
		sensor.SensedPart = nil
	end
end

--- Forward-down probe. Origin sits ahead of the character and slightly
--- above root; fires straight down. Consumers compare HitFrame.Y against
--- GroundSensor.HitFrame.Y to distinguish slope / drop / step-up.
function SensorManager:HandleForwardDownSensor(sensor)
	if not sensor then
		return
	end

	local rootCFrame = self._RootPart.CFrame
	local look = rootCFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 1e-4 then
		flatLook = flatLook.Unit
	else
		flatLook = look
	end

	local origin = self._RootPart.Position
		+ flatLook * self.FORWARD_DOWN.Forward
		+ Vector3.new(0, self.FORWARD_DOWN.OriginY, 0)
	local direction = Vector3.new(0, -self.FORWARD_DOWN.Down, 0)

	local result = workspace:Raycast(origin, direction, self._RaycastParams)
	if self.DebugEnabled then
		RayVisualizer:Draw(
			origin,
			result and result.Position or origin + direction,
			Color3.new(1, result and 1 or 0.4, 0)
		)
	end

	if result then
		sensor.SensedPart = result.Instance
		sensor.HitNormal = result.Normal
		sensor.HitFrame = CFrame.new(result.Position)
	else
		sensor.SensedPart = nil
	end
end

--- Forward probe at feet height. Lets traversalUtil distinguish vault
--- (hit near feet) from climb (hit higher up / nothing at feet). Uses a
--- slightly longer reach than FFeetSensor for lookahead.
function SensorManager:HandleStepSensor(sensor)
	if not sensor then
		return
	end

	local origin = self._RootPart.Position + Vector3.new(0, self.FORWARD_OFFSETS.Feet, 0)
	local direction = self._RootPart.CFrame.LookVector * self.RAY_LENGTHS.Step

	local result = workspace:Raycast(origin, direction, self._RaycastParams)
	if self.DebugEnabled then
		RayVisualizer:Draw(
			origin,
			result and result.Position or origin + direction,
			Color3.new(1, result and 0.6 or 0.3, 1)
		)
	end

	if result then
		sensor.SensedPart = result.Instance
		sensor.HitNormal = result.Normal
		sensor.HitFrame = CFrame.new(result.Position)
	else
		sensor.SensedPart = nil
	end
end

function SensorManager:HandleWallSensor(sensor, sign: number)
	if not sensor then
		return
	end

	local origin = self._RootPart.Position
	local direction = self._RootPart.CFrame.RightVector * sign * self.RAY_LENGTHS.Wall

	local result = workspace:Raycast(origin, direction, self._RaycastParams)
	if self.DebugEnabled then
		RayVisualizer:Draw(
			origin,
			result and result.Position or origin + direction,
			Color3.new(0, result and 1 or 0.5, result and 1 or 0.5)
		)
	end

	if result then
		sensor.SensedPart = result.Instance
		sensor.HitNormal = result.Normal
		sensor.HitFrame = CFrame.new(result.Position)
	else
		sensor.SensedPart = nil
	end
end

--[[ ========================================
	 Character Lifecycle
	======================================== ]]

function SensorManager:OnCharacterAdded(character: Model)
	self._Character = character
	self._Humanoid = self._Controller:GetHumanoid()
	self._RootPart = self._Controller:GetRootPart()
	self._SensorDir = character:FindFirstChild("Sensors") or character:WaitForChild("Sensors", 5)

	self._RaycastParams = RaycastParams.new()
	self._RaycastParams.FilterDescendantsInstances = {
		character,
		table.unpack(CollectionService:GetTagged(IGNORE_SENSOR_TAG)),
	}
	self._RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self._RaycastParams.IgnoreWater = false

	table.clear(self.Sensors)
	self:RegisterSensors()
end

function SensorManager:OnCharacterRemoving()
	self._Character = nil
	self._Humanoid = nil
	self._RootPart = nil
	self._SensorDir = nil
	self._RaycastParams = nil
	table.clear(self.Sensors)
end

function SensorManager:Destroy()
	for _, c in self._connections do
		c:Disconnect()
	end
	table.clear(self._connections)
end

return SensorManager
