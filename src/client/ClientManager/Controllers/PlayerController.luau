--[[
	PlayerController

	Thin Knit controller for the local player's character runtime. Delegates
	everything character-related to a shared CharacterRuntime so NPC companions
	can use the identical pipeline; retains only the player-specific bindings:
	Players.LocalPlayer.CharacterAdded hook, camera-coupled TiltHandler, and
	the debug hotkey for SensorManager (which is input-dependent).

	All per-character logic (movement, animation, sensors, states, look-at)
	lives in ReplicatedStorage.Shared.Classes.Managers and is loaded into the
	runtime's manager list here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local TiltHandler = require(ReplicatedStorage.Shared.Classes.TiltHandler)

local CharacterRuntime = require(ReplicatedStorage.Shared.Classes.CharacterRuntime)

local SHARED_MANAGERS = ReplicatedStorage.Shared.Classes.Managers

local PlayerController = Knit.CreateController({
	Name = "PlayerController",
})

--[[ ========================================
	 Lifecycle
	======================================== ]]

function PlayerController:KnitInit()
	self._runtime = nil :: any?
	self._tiltStop = nil :: (() -> ())?
	self._connections = {} :: { RBXScriptConnection }
	self._cameraEffects = nil
end

function PlayerController:KnitStart()
	self._runtime = CharacterRuntime.new({
		managerModules = self:_collectManagerModules(),
		context = { kind = "player" },
	})
	self._runtime:Initialize()

	local player = Players.LocalPlayer
	table.insert(
		self._connections,
		player.CharacterAdded:Connect(function(character)
			self:_onCharacterAdded(character)
		end)
	)
	table.insert(
		self._connections,
		player.CharacterRemoving:Connect(function(character)
			self:_onCharacterRemoving(character)
		end)
	)

	local existing = player.Character
	if existing then
		task.spawn(function()
			self:_onCharacterAdded(existing)
		end)
	end

	self:_bindDebugHotkeys()
end

--[[ ========================================
	 Character Lifecycle (player-specific)
	======================================== ]]

function PlayerController:_collectManagerModules(): { ModuleScript }
	local list = {}
	for _, child in SHARED_MANAGERS:GetChildren() do
		if child:IsA("ModuleScript") and child.Name:match("Manager$") then
			table.insert(list, child)
		end
	end
	-- Player runtime uses the KeybindController-backed input provider so
	-- states that gate on Slide/Jump/Sprint behave exactly as before.
	local inputFolder = SHARED_MANAGERS:FindFirstChild("Input")
	if inputFolder then
		local playerInput = inputFolder:FindFirstChild("PlayerInputProvider")
		if playerInput and playerInput:IsA("ModuleScript") then
			table.insert(list, playerInput)
		end
	end
	return list
end

function PlayerController:_onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not humanoid or not rootPart then
		warn(`[{script.Name}] Missing Humanoid or HumanoidRootPart on spawn`)
		return
	end

	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	local defaultAnimate = character:FindFirstChild("Animate")
	if defaultAnimate then
		defaultAnimate:Destroy()
	end

	if self._tiltStop then
		self._tiltStop()
	end
	self._tiltStop = TiltHandler.Start(character)

	self._runtime:AttachCharacter(character)
end

function PlayerController:_onCharacterRemoving(_character: Model)
	if self._runtime then
		self._runtime:DetachCharacter()
	end
	if self._tiltStop then
		self._tiltStop()
		self._tiltStop = nil
	end
end

--[[ ========================================
	 Debug input binding (local-player only)
	======================================== ]]

function PlayerController:_bindDebugHotkeys()
	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == Enum.KeyCode.J then
				local sensors = self._runtime and self._runtime:GetManager("SensorManager")
				if sensors then
					sensors:ToggleDebug()
				end
			end
		end)
	)
end

--[[ ========================================
	 Public API
	======================================== ]]

function PlayerController:GetManager(name: string)
	if not self._runtime then
		return nil
	end
	return self._runtime:GetManager(name)
end

function PlayerController:GetCharacter(): Model?
	if not self._runtime then
		return nil
	end
	return self._runtime:GetCharacter()
end

function PlayerController:GetHumanoid(): Humanoid?
	if not self._runtime then
		return nil
	end
	return self._runtime:GetHumanoid()
end

function PlayerController:GetRootPart(): BasePart?
	if not self._runtime then
		return nil
	end
	return self._runtime:GetRootPart()
end

function PlayerController:GetRuntime()
	return self._runtime
end

function PlayerController:RestartTilt(config: { [string]: number }?)
	if self._tiltStop then
		self._tiltStop()
	end
	local character = self:GetCharacter()
	if character then
		self._tiltStop = TiltHandler.Start(character, config)
	end
end

function PlayerController:GetCameraEffects()
	if not self._cameraEffects then
		local ok, camController = pcall(function()
			return Knit.GetController("CameraController")
		end)
		if ok and camController then
			self._cameraEffects = camController:GetEffects()
		end
	end
	return self._cameraEffects
end

return PlayerController
