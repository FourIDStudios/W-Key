--[[
	NpcInputProvider

	AI-backed implementation of the generic InputProvider contract. The MVP
	keeps actions false, but the setter allows future NPC intent to drive states
	like Run/Jump without states knowing the host is not a player.
]]

local InputProviderBase = require(script.Parent.InputProviderBase)

local NpcInputProvider = setmetatable({}, { __index = InputProviderBase })
NpcInputProvider.__index = NpcInputProvider

function NpcInputProvider.new(Runtime)
	local self = setmetatable(InputProviderBase.new(Runtime), NpcInputProvider)
	self._pressed = {} :: { [string]: boolean }
	return self
end

function NpcInputProvider:SetIntent(action: string, pressed: boolean)
	local isPressed = pressed == true
	local wasPressed = self._pressed[action] == true
	self._pressed[action] = isPressed

	if isPressed and not wasPressed then
		self:_recordPress(action)
	end
end

function NpcInputProvider:IsPressed(action: string): boolean
	return self._pressed[action] == true
end

function NpcInputProvider:Clear()
	table.clear(self._pressed)
end

function NpcInputProvider:Destroy()
	self:Clear()
	InputProviderBase.Destroy(self)
end

return NpcInputProvider
