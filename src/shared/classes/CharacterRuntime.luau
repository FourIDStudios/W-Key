--[[
	CharacterRuntime

	Generic per-character runtime host. Owns a single character's manager set
	and routes the manager lifecycle. Drives both the local player's character
	(from PlayerController) and every generic NPC
	over the identical manager pipeline.

	Manager contract (unchanged from prior PlayerController design):
	  .new(controller)             -- lean construction, no yields, no events
	  :Init()                      -- manager-local setup, no character deps
	  :Start()                     -- begin loops / event wiring (optional)
	  :OnCharacterAdded(char)      -- receive a live character (optional)
	  :OnCharacterRemoving(char)   -- clean up character refs (optional)
	  :Destroy()                   -- full teardown (optional)

	Construction:
	  CharacterRuntime.new({
	    managerModules = { ModuleScript, ... },  -- required, loaded in order
	    context        = { kind = "player" | "npc", ... } -- optional metadata
	  })

	The runtime does NOT bind Player.CharacterAdded itself. Host controllers
	(PlayerController / NPCController) feed characters in via
	:AttachCharacter(character) / :DetachCharacter(). This keeps the runtime
	reusable for non-Player entities.
]]

local CharacterRuntime = {}
CharacterRuntime.__index = CharacterRuntime

export type Config = {
	managerModules: { ModuleScript },
	context: { [string]: any }?,
}

function CharacterRuntime.new(config: Config)
	assert(config and typeof(config) == "table", "CharacterRuntime.new: config required")
	assert(config.managerModules, "CharacterRuntime.new: managerModules required")

	local self = setmetatable({}, CharacterRuntime)
	self._context = config.context or {}
	self._managerModules = config.managerModules
	self._managers = {} :: { [string]: any }
	self._managersOrder = {} :: { any }
	self._character = nil :: Model?
	self._humanoid = nil :: Humanoid?
	self._rootPart = nil :: BasePart?
	self._started = false
	self._destroyed = false
	return self
end

--[[ ========================================
	 Manager Lifecycle
	======================================== ]]

--- Instantiates every manager module, calls :Init then :Start. Idempotent.
function CharacterRuntime:Initialize()
	if self._started then
		return
	end
	self._started = true

	for _, moduleScript in self._managerModules do
		local ok, managerClass = pcall(require, moduleScript)
		if not ok then
			warn(`[CharacterRuntime] Failed to require {moduleScript:GetFullName()}: {managerClass}`)
			continue
		end

		local manager = managerClass.new(self)
		local name = manager.Name or moduleScript.Name
		self._managers[name] = manager
		table.insert(self._managersOrder, manager)
	end

	for _, manager in self._managersOrder do
		if manager.Init then
			manager:Init()
		end
	end

	for _, manager in self._managersOrder do
		if manager.Start then
			manager:Start()
		end
	end
end

--[[ ========================================
	 Character Lifecycle
	======================================== ]]

--- Host controller calls this once the character, Humanoid, and HumanoidRootPart
--- are confirmed present. Fans out :OnCharacterAdded(character) to every manager.
function CharacterRuntime:AttachCharacter(character: Model)
	assert(character, "CharacterRuntime:AttachCharacter: character required")

	if self._character == character then
		return
	end
	if self._character then
		self:DetachCharacter()
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		warn(`[CharacterRuntime] AttachCharacter missing Humanoid/RootPart on {character:GetFullName()}`)
		return
	end

	self._character = character
	self._humanoid = humanoid :: Humanoid
	self._rootPart = rootPart :: BasePart

	for _, manager in self._managersOrder do
		if manager.OnCharacterAdded then
			local ok, err = pcall(manager.OnCharacterAdded, manager, character)
			if not ok then
				warn(`[CharacterRuntime] {manager.Name or "?"}:OnCharacterAdded errored: {err}`)
			end
		end
	end
end

--- Fans out :OnCharacterRemoving to every manager and clears the character refs.
function CharacterRuntime:DetachCharacter()
	if not self._character then
		return
	end
	local character = self._character

	for _, manager in self._managersOrder do
		if manager.OnCharacterRemoving then
			local ok, err = pcall(manager.OnCharacterRemoving, manager, character)
			if not ok then
				warn(`[CharacterRuntime] {manager.Name or "?"}:OnCharacterRemoving errored: {err}`)
			end
		end
	end

	self._character = nil
	self._humanoid = nil
	self._rootPart = nil
end

--[[ ========================================
	 Public Accessors
	 Managers and states read through these; do not reach into _managers.
	======================================== ]]

function CharacterRuntime:GetManager(name: string)
	return self._managers[name]
end

function CharacterRuntime:GetCharacter(): Model?
	return self._character
end

function CharacterRuntime:GetHumanoid(): Humanoid?
	return self._humanoid
end

function CharacterRuntime:GetRootPart(): BasePart?
	return self._rootPart
end

--- Returns the context table this runtime was constructed with. Managers that
--- genuinely need to know their host (e.g. "am I a player or a companion")
--- read context.kind. Prefer polymorphism over branching on context.
function CharacterRuntime:GetContext(): { [string]: any }
	return self._context
end

--[[ ========================================
	 Teardown
	======================================== ]]

function CharacterRuntime:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	self:DetachCharacter()

	for _, manager in self._managersOrder do
		if manager.Destroy then
			pcall(manager.Destroy, manager)
		end
	end

	table.clear(self._managers)
	table.clear(self._managersOrder)
	setmetatable(self, nil)
end

return CharacterRuntime
