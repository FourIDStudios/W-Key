--[[
	PlayerDataTemplate
]]
local PlayerDataTemplate = {}
PlayerDataTemplate.__index = PlayerDataTemplate

function PlayerDataTemplate.new()
	-- Player Data Definition
	return setmetatable({
		-- Character selection
		Name = "John Doe",
		SlotIndex = 1,

		-- Currency placeholders for menu UI
		Scrap = 1800,

		-- Player progression
		Level = 1,
		XP = 0,
		QuestProgressions = {
			-- [Quest|Event|Etc] = {
			-- 	information needed for it, such as progress
			-- }
		},

		-- Game statistics
		Statistics = {
			-- Core stats
			StationsEntered = 0,
			StationsCleared = 0,
			EnemiesKilled = 0,
			Deaths = 0,
			Playtime = 0,
			TotalXP = 0,
			TotalScrap = 0,
			TotalGold = 0,

			-- Session tracking
			lastJoin = 0,

			-- Player settings
			Settings = {
				General = {
					MusicVolume = 0.5,
					SFXVolume = 0.8,
				},
			},
		},
	}, PlayerDataTemplate)
end

return PlayerDataTemplate
