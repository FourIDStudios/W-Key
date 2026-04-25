--[[
	PlayerInputProvider

	Input provider for a player-owned CharacterRuntime. Delegates to the real
	Knit KeybindController (kept as the single source of truth for human
	input bindings) and mirrors its rising edges onto this provider's
	ActionPressed signal so states subscribe uniformly.

	Registers under Name = "InputProvider" so states query the same slot
	regardless of whether they're running under a player or a companion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local InputProviderBase = require(script.Parent.InputProviderBase)

local PlayerInputProvider = setmetatable({}, { __index = InputProviderBase })
PlayerInputProvider.__index = PlayerInputProvider

function PlayerInputProvider.new(Runtime)
	local self = setmetatable(InputProviderBase.new(Runtime), PlayerInputProvider)
	self._keybind = nil
	self._pressedConn = nil
	return self
end

function PlayerInputProvider:Init()
	self._keybind = Knit.GetController("KeybindController")
	if self._keybind and self._keybind.ActionPressed then
		self._pressedConn = self._keybind.ActionPressed:Connect(function(actionName: string)
			self:_recordPress(actionName)
		end)
	end
end

function PlayerInputProvider:IsPressed(action: string): boolean
	if not self._keybind then
		return false
	end
	return self._keybind:IsActionPressed(action)
end

function PlayerInputProvider:Destroy()
	if self._pressedConn then
		self._pressedConn:Disconnect()
		self._pressedConn = nil
	end
	InputProviderBase.Destroy(self)
end

return PlayerInputProvider
