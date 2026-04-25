--[[
	StateManager

	Drives one character's state machine by
	enumerating state module definitions under ReplicatedStorage.Shared.States,
	instantiating them, and advancing transitions every Heartbeat while a
	character is attached.

	State module source of truth: ReplicatedStorage.Shared.States.
	Animation instances live under ReplicatedStorage.Assets.Animations.States
	and are preloaded by AnimationManager.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local STATES_FOLDER = ReplicatedStorage.Shared.Classes.States
local StateManager = {}
StateManager.__index = StateManager

function StateManager.new(Runtime)
	local self = setmetatable({}, StateManager)
	self._Controller = Runtime
	self.Name = "StateManager"
	self.State = nil
	self.States = {} :: { [string]: any }
	self.LockedUntil = 0
	self._previousStateName = nil
	self._exitLockTime = 0
	self._queuedState = nil

	self._subscribers = {} :: { [string]: (string, string?) -> () }
	self._disabledStates = {} :: { [string]: boolean }
	self._connections = {} :: { RBXScriptConnection }

	return self
end

--- Instantiates every state module that lives under STATES_FOLDER (recursive),
--- except BaseState. Ordering doesn't matter since priority governs selection.
function StateManager:Init()
	for _, desc in STATES_FOLDER:GetDescendants() do
		if desc:IsA("ModuleScript") and desc.Name:match("State$") and desc.Name ~= "BaseState" then
			local ok, stateClass = pcall(require, desc)
			if not ok then
				warn(`[{self.Name}] Failed to require state {desc:GetFullName()}: {stateClass}`)
				continue
			end

			local stateInstance = stateClass.new(self._Controller, desc)
			if stateInstance.Init then
				stateInstance:Init()
			end
			self.States[stateInstance.Name] = stateInstance
		end
	end
end

function StateManager:Start()
	table.insert(
		self._connections,
		RunService.Heartbeat:Connect(function(dT)
			self:Update(dT)
		end)
	)
end

function StateManager:OnCharacterRemoving()
	if self.State then
		pcall(function()
			self.State:Exit()
		end)
		self.State = nil
	end
	self._queuedState = nil
	self.LockedUntil = 0
end

function StateManager:_teardownAllStates()
	if self.State then
		pcall(function()
			self.State:Exit()
		end)
		self.State = nil
	end

	self._queuedState = nil
	self.LockedUntil = 0

	for _, stateInstance in self.States do
		if stateInstance.Destroy then
			pcall(function()
				stateInstance:Destroy()
			end)
		end
	end

	table.clear(self.States)
end

--[[ ========================================
	 Pub/Sub API
	======================================== ]]

function StateManager:Subscribe(subscriberId: string, callback: (string, string?) -> ())
	self._subscribers[subscriberId] = callback
	local currentName = self.State and self.State.Name or nil
	callback(currentName, nil)
end

function StateManager:Unsubscribe(subscriberId: string)
	self._subscribers[subscriberId] = nil
end

function StateManager:_fireStateChanged(newStateName: string, prevStateName: string?)
	for _, callback in self._subscribers do
		callback(newStateName, prevStateName)
	end
end

--[[ ========================================
	 Disabled States API
	======================================== ]]

function StateManager:DisableState(stateName: string)
	self._disabledStates[stateName] = true
end

function StateManager:EnableState(stateName: string)
	self._disabledStates[stateName] = nil
end

function StateManager:IsStateDisabled(stateName: string): boolean
	return self._disabledStates[stateName] == true
end

--[[ ========================================
	 Tick + Transitions
	======================================== ]]

function StateManager:Update(dT: number)
	if self._Controller:GetCharacter() == nil then
		return
	end
	if self._Controller:GetHumanoid() == nil then
		return
	end
	if self._Controller:GetRootPart() == nil then
		return
	end

	if self.LockedUntil > os.clock() then
		return
	end

	if self._queuedState then
		local deferred = self._queuedState
		self._queuedState = nil
		deferred:Enter()
		return
	end

	if self.State ~= nil then
		self.State:Update(dT)
	end

	self:CheckForTransitions()
end

function StateManager:CheckForTransitions()
	if self.LockedUntil > os.clock() then
		return
	end

	local eligibleStates = {}
	for name, stateInstance in pairs(self.States) do
		if self._disabledStates[name] then
			continue
		end
		if stateInstance:CanEnter() then
			table.insert(eligibleStates, {
				name = name,
				state = stateInstance,
				priority = stateInstance.Priority,
			})
		end
	end

	table.sort(eligibleStates, function(a, b)
		return a.priority > b.priority
	end)

	if #eligibleStates > 0 then
		local topCandidate = eligibleStates[1]
		if self.State and self.State.Name == topCandidate.name then
			return
		end
		self:TransitionToState(topCandidate.name)
	end
end

function StateManager:TransitionToState(stateName: string)
	local stateInstance = self.States[stateName]
	if stateInstance == nil then
		warn(`[StateManager]: State {stateName} does not exist!`)
		return
	end
	if self.State and self.State.Name == stateName then
		return
	end

	local prevName = self.State and self.State.Name or nil

	if self.State then
		self._previousStateName = self.State.Name
		self._exitLockTime = self.State:Exit() or 0
	else
		self._exitLockTime = 0
	end

	if self._exitLockTime > 0 then
		self:LockState(self._exitLockTime)
		self.State = stateInstance
		self._queuedState = stateInstance
		self:_fireStateChanged(stateName, prevName)
		return
	end
	self.State = stateInstance
	self.State:Enter()
	self:_fireStateChanged(stateName, prevName)
end

function StateManager:GetCurrentState(): string?
	if not self.State then
		return nil
	end
	return self.State.Name
end

function StateManager:LockState(duration: number)
	self.LockedUntil = os.clock() + duration
end

function StateManager:Destroy()
	for _, c in self._connections do
		c:Disconnect()
	end
	table.clear(self._connections)
	self:_teardownAllStates()
end

return StateManager
