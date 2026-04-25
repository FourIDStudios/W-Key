--[[
	BaseState

	Abstract base for all player states. States only hold transition/enter/exit
	logic. Animation assets live in a parallel tree under
	ReplicatedStorage.Assets.Animations.States mirrored by state module path.

	Contract for subclasses:
	  MyState.Name     = "MyState"
	  MyState.Priority = <number>
	  MyState.new(controller, moduleRef)
	  :CanEnter(): boolean
	  :Enter()
	  :Update(dT)
	  :Exit()

	The StateManager passes the state's ModuleScript as moduleRef so BaseState
	can resolve the mirrored animation folder without subclasses caring.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local instanceUtil = require(ReplicatedStorage.Shared.Classes.Util.instanceUtil)

local STATES_ROOT_NAME = "States"

local function getAnimationsRoot(): Instance?
	local assets = ReplicatedStorage.Shared:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	return animations and animations:FindFirstChild(STATES_ROOT_NAME) or nil
end

local BaseState = {}
BaseState.__index = BaseState
BaseState.Priority = 0
BaseState.Name = "BaseState"
BaseState.Config = {}

function BaseState.new(Controller, moduleRef: Instance?)
	local self = setmetatable({}, BaseState)
	self._Controller = Controller
	self._module = moduleRef
	self._animationFolder = instanceUtil.ResolveFolder(moduleRef, STATES_ROOT_NAME, getAnimationsRoot())
	self.Config = {}
	return self
end

function BaseState:CanEnter(): boolean
	return false
end
function BaseState:Enter() end
function BaseState:Update(dT: number) end
function BaseState:Exit() end

--[[ ========================================
	 Manager / asset accessors
	======================================== ]]

function BaseState:GetManager(name: string)
	if not self._Controller then
		return nil
	end
	return self._Controller:GetManager(name)
end

function BaseState:GetAnimation(animName: string): Animation?
	local folder = self._animationFolder
	if not folder then
		return nil
	end
	local anim = folder:FindFirstChild(animName)
	return if anim and anim:IsA("Animation") then anim else nil
end

--[[ ========================================
	 Config overrides
	======================================== ]]

--- Merges override values into this state's Config table. Animation overrides
--- rewrite the AnimationId on matching Animation instances inside the mirrored
--- animation folder.
function BaseState:ApplyOverrides(overrides: { [string]: any })
	for key, value in overrides do
		if key == "Animations" then
			local folder = self._animationFolder
			if folder then
				for animName, animId in value do
					local anim = folder:FindFirstChild(animName)
					if anim and anim:IsA("Animation") then
						anim.AnimationId = animId
					end
				end
			end
		else
			self.Config[key] = value
		end
	end
end

function BaseState:Destroy() end

return BaseState
