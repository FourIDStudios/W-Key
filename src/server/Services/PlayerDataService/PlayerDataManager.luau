--[[
	PlayerDataManager

	Centralized helper for manipulating a single player's profile data.
	PlayerDataService should delegate character unlock/select/purchase mutations here.
--]]

local PlayerDataManager = {}
PlayerDataManager.__index = PlayerDataManager

function PlayerDataManager.new(plr: Player?, profileDataRef, onUpdate: (() -> ())?)
	return setmetatable({
		player = plr,
		profileData = profileDataRef,
		dataChanged = onUpdate,
	}, PlayerDataManager)
end

function PlayerDataManager:_markUpdated()
	if self.dataChanged then
		self.dataChanged()
	end
end

return PlayerDataManager
