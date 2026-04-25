--[[
	KeybindController

	Single source of truth for client input bindings. Other controllers and
	the generic manager classes query this controller instead of
	polling UserInputService or wiring their own listeners.

	Public API:
		:GetBinding(actionName)            -> EnumItem?
		:SetBinding(actionName, binding)
		:IsActionPressed(actionName)       -> boolean
		:Matches(actionName, input)        -> boolean

	Signals:
		.ActionPressed  : (actionName: string, input: InputObject)
		.ActionReleased : (actionName: string, input: InputObject)

	Bindings accept Enum.KeyCode values (keyboard) or Enum.UserInputType
	values (mouse). Unknown actions resolve to nil / false.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.signal)

local DEFAULT_BINDINGS: { [string]: EnumItem } = {
	Jump = Enum.KeyCode.Space,
	Sprint = Enum.KeyCode.LeftShift,
	Slide = Enum.KeyCode.LeftControl,
	ShiftLock = Enum.KeyCode.LeftAlt,
	Dash = Enum.KeyCode.Q,
}

local KeybindController = Knit.CreateController({
	Name = "KeybindController",
})

function KeybindController:KnitInit()
	self._bindings = table.clone(DEFAULT_BINDINGS)
	self._connections = {} :: { RBXScriptConnection }
	self.ActionPressed = Signal.new()
	self.ActionReleased = Signal.new()
end

function KeybindController:KnitStart()
	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			local action = self:_actionFromInput(input)
			if action then
				self.ActionPressed:Fire(action, input)
			end
		end)
	)

	table.insert(
		self._connections,
		UserInputService.InputEnded:Connect(function(input)
			local action = self:_actionFromInput(input)
			if action then
				self.ActionReleased:Fire(action, input)
			end
		end)
	)
end

--[[ ========================================
	 Public API
	======================================== ]]

function KeybindController:GetBinding(actionName: string): EnumItem?
	return self._bindings[actionName]
end

--- Rebind an action. Pass an Enum.KeyCode or Enum.UserInputType value; any
--- other value clears the binding.
function KeybindController:SetBinding(actionName: string, binding: EnumItem?)
	if
		typeof(binding) == "EnumItem" and (binding.EnumType == Enum.KeyCode or binding.EnumType == Enum.UserInputType)
	then
		self._bindings[actionName] = binding
	else
		self._bindings[actionName] = nil
	end
end

--- Returns true if the binding for `actionName` is currently held down.
function KeybindController:IsActionPressed(actionName: string): boolean
	local binding = self._bindings[actionName]
	if not binding then
		return false
	end
	if binding.EnumType == Enum.KeyCode then
		return UserInputService:IsKeyDown(binding)
	end
	if binding.EnumType == Enum.UserInputType then
		return UserInputService:IsMouseButtonPressed(binding)
	end
	return false
end

--- Returns true if the given InputObject matches the binding for `actionName`.
function KeybindController:Matches(actionName: string, input: InputObject?): boolean
	local binding = self._bindings[actionName]
	if not binding or not input then
		return false
	end
	if binding.EnumType == Enum.KeyCode then
		return input.KeyCode == binding
	end
	if binding.EnumType == Enum.UserInputType then
		return input.UserInputType == binding
	end
	return false
end

--[[ ========================================
	 Internal
	======================================== ]]

function KeybindController:_actionFromInput(input: InputObject): string?
	for actionName, binding in self._bindings do
		if binding.EnumType == Enum.KeyCode and input.KeyCode == binding then
			return actionName
		end
		if binding.EnumType == Enum.UserInputType and input.UserInputType == binding then
			return actionName
		end
	end
	return nil
end

return KeybindController
