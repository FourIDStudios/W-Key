--[[
	InputProviderBase

	Shared contract for anything the StateManager's states treat as "input".
	The player's InputProvider forwards the real KeybindController; a
	companion's InputProvider stores transient Press/Hold flags that its
	CompanionIntentApplier writes based on traversalUtil decisions.

	States never reach through to KeybindController directly - they go
	through runtime:GetManager("InputProvider") so the player-vs-AI plumbing
	is swappable in one place.

	Contract:
	  :IsPressed(action)          -> boolean   (current state)
	  :WasPressed(action, window) -> boolean   (pressed within the last
	                                             `window` seconds)
	  .ActionPressed : Signal(action) fired on a rising edge
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.signal)

local InputProviderBase = {}
InputProviderBase.__index = InputProviderBase

function InputProviderBase.new(Runtime)
	local self = setmetatable({}, InputProviderBase)
	self._Controller = Runtime
	self.Name = "InputProvider"
	self.ActionPressed = Signal.new()
	self._lastPressedAt = {} :: { [string]: number }
	return self
end

function InputProviderBase:Init() end
function InputProviderBase:Start() end
function InputProviderBase:OnCharacterAdded(_character: Model) end
function InputProviderBase:OnCharacterRemoving(_character: Model) end

--- Subclasses override this. Base returns false.
function InputProviderBase:IsPressed(_action: string): boolean
	return false
end

--- Returns true when an edge-fire landed within the last `window` seconds.
--- Works identically for player-bound and AI providers since both write to
--- `_lastPressedAt` when they surface an ActionPressed event.
function InputProviderBase:WasPressed(action: string, window: number): boolean
	local at = self._lastPressedAt[action]
	if not at then
		return false
	end
	return (os.clock() - at) <= window
end

--- Subclasses call this internally on rising edges so `WasPressed` and any
--- `ActionPressed` listeners stay in sync.
function InputProviderBase:_recordPress(action: string)
	self._lastPressedAt[action] = os.clock()
	self.ActionPressed:Fire(action)
end

function InputProviderBase:Destroy()
	if self.ActionPressed then
		self.ActionPressed:Destroy()
		self.ActionPressed = nil
	end
	table.clear(self._lastPressedAt)
end

return InputProviderBase
