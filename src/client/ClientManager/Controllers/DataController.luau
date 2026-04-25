--[[
    DataController - Read-only client cache of the local player's replicated data.
    Observes DataService.GlobalProfile (slots, sessionSlot, metaData); fires immediately and on every change.
    Use GetGlobalProfile() for full data; GetProfile() for the active slot's Profile; Observe(callback) to react to changes. Do not mutate returned data.
    @module DataController
--]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Player = Players.LocalPlayer

local DataController = Knit.CreateController({
	-- Public Properties
	Name = "DataController",
	Data = {},
	Events = {
		OnDataChanged = {},
	},

	-- Private Properies
	_dataService = nil,
	_oldData = {},
	_dubugEnabled = false,
})

function DataController:KnitInit() end

--[[
	Starts The DataController, And Observes The DataService.Data Property.
	When The DataService.Data Property Changes, The DataController Will Fire The OnDataChanged Event.
]]
function DataController:KnitStart()
	self._dataService = Knit.GetService("PlayerDataService")
	self._dataService.Data:Observe(function(newData)
		-- Naieve diff check, realistically i'm not sure if this is checkign memory addresses or content equality
		if newData == self.Data then
			return
		end

		self:Debug(`[CDC] ${Player.DisplayName} GlobalProfile changed:`, newData)
		self._oldData = self.data
		self.data = newData

		-- Fire DataChanged Event
		self:FireEvent("OnDataChanged", self.data)
	end)
end

--[[
	Fires Specific Events, Given EventName & Data
--]]
function DataController:FireEvent(EventName: string, Data: any)
	if not self.Events[EventName] then
		self:Debug(`[DataController] Attempt To Fire An Event, That Does Not Exist: {EventName}`)
		return
	end

	for _, Callback in self.Events[EventName] do
		-- Fire That Callback W/Data
		Callback(Data)
	end
end

function DataController:FireEventTo(SubscriberId, Event, Data: any)
	if not self.Events[Event] then
		self:Debug("Attempt To Fire An Event, That Does Not Exist")
		return
	end
	if not self.Events[Event][SubscriberId] then
		self:Debug("Attempt To Fire An Event, To A Subscriber That Does Not Exist")
		return
	end

	self.Events[Event][SubscriberId](Data)
end

--[[
	Subscribes to GlobalProfile updates. Fires immediately with current value and on every change. Callback receives GlobalProfile (read-only).
]]
function DataController:Subscribe(SubscriberId: string, callback: (any) -> (), Event: string?): () -> ()
	self:Debug(`[DataController] {SubscriberId} Subscribing To Event: `, Event or "OnDataChanged")
	if Event and not self.Events[Event] then
		self:Debug("Attempt To Subscribe To Event That Doesnt Exist")
		return function() end
	end
	if not Event then
		self:Debug(
			`[DataController] {SubscriberId} Attempting To Subscribe To OnDataChanged Event, Without Specifying It`
		)
		return function() end
	end
	self.Events[Event][SubscriberId] = callback
	self:FireEventTo(SubscriberId, Event or "OnDataChanged", self._localData)
	return function()
		self:Unsubscribe(SubscriberId, Event)
	end
end

-- Unsubscribe from DataController updates.
function DataController:Unsubscribe(SubscriberId, Event: string?)
	if not SubscriberId then
		return
	end
	if Event and not self.Events[Event] then
		return
	end
	if not Event then
		if self.Events.OnDataChanged[SubscriberId] then
			self.Events.OnDataChanged[SubscriberId] = nil
		end
	end

	-- Remove Event From Callback List
	self.Events[Event][SubscriberId] = nil
end

function DataController:Debug(...: any)
	if self._debugEnabled then
		print("[DataController]: ", ...)
	end
end

return DataController
