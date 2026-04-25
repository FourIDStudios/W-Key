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
	Name = "DataController",
	DataService = nil,
	LocalData = {},
	Events = {
		OnDataChanged = {},
	},
})

function DataController:KnitInit() end

--[[
	Starts The DataController, And Observes The DataService.Data Property.
	When The DataService.Data Property Changes, The DataController Will Fire The OnDataChanged Event.
]]
function DataController:KnitStart()
	self._dataService = Knit.GetService("PlayerDataService")
	self._dataService.Data:Observe(function(data)
		-- Naieve diff check, realistically i'm not sure if this is checkign memory addresses or content equality
		if data == self.LocalData then
			return
		end

		print(`[CDC] ${Player.DisplayName} GlobalProfile changed:`, data)
		-- Server sends a clone of the data, so we can just assign it to our local data
		self.LocalData = data

		-- Fire DataChanged Event
		self:FireEvent("OnDataChanged", self.LocalData)
	end)
end

--[[
	Fires Specific Events, Given EventName & Data
	Intended to use as a way of extending the data events, for more specific use cases
	i.e an update specifically to the inventory, or the character, etc.
--]]
function DataController:FireEvent(EventName: string, Data: any)
	if not self.Events[EventName] then
		warn(`[DataController] Attempt To Fire An Event, That Does Not Exist: {EventName}`)
		return
	end

	for _, Callback in self.Events[EventName] do
		-- Fire That Callback W/Data
		Callback(Data)
	end
end

function DataController:FireEventTo(SubscriberId, Event, Data: any)
	if not self.Events[Event] then
		warn("Attempt To Fire An Event, That Does Not Exist")
		return
	end
	if not self.Events[Event][SubscriberId] then
		warn("Attempt To Fire An Event, To A Subscriber That Does Not Exist")
		return
	end

	self.Events[Event][SubscriberId](Data)
end

--- Subscribes to GlobalProfile updates. Fires immediately with current value and on every change. Callback receives GlobalProfile (read-only).
--- @param callback (globalProfile: PlayerData.GlobalProfile?) -> ()
--- @return () disconnect
function DataController:Subscribe(SubscriberId, callback: () -> (), Event: string?)
	print(`[DataController] {SubscriberId} Subscribing To Event: `, Event or "OnDataChanged")
	if Event and not self.Events[Event] then
		warn("Attempt To Subscribe To Event That Doesnt Exist")
		return
	end
	if not Event then
		warn(`[DataController] {SubscriberId} Attempting To Subscribe To OnDataChanged Event, Without Specifying It`)
		return
	end
	self.Events[Event][SubscriberId] = callback
	self:FireEventTo(SubscriberId, Event, self.LocalData)
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

return DataController
