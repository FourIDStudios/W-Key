-- Services & Folders
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages
local Vendor = ServerScriptService.Vendor

-- Packages
local Knit = require(Packages.Knit)
local ProfileStore = require(Vendor.ProfileStore)

-- Modules
local PlayerDataManager = require(script:WaitForChild("PlayerDataManager"))
local PlayerDataTemplate = require(script:WaitForChild("PlayerDataTemplate"))

-- Service Definition
local DataService = Knit.CreateService({
	Name = "PlayerDataService",
	FetchedStore = nil,
	HeldProfiles = {},
	ProfileConnections = {}, --[plr.UserId] = {Connections}
	DataManagers = {},
	ProfileTemplate = PlayerDataTemplate.new(),

	-- Client Facing Functions & Data
	Client = {
		Data = Knit.CreateProperty(nil),
	},
})

-- Service Lifecycle Functions
function DataService:KnitInit()
	-- Initialize ProfileStore
	self.FetchedStore = ProfileStore.New("PlayerData", self.ProfileTemplate)

	-- Connect Profile Events
	Players.PlayerAdded:Connect(function(plr)
		self:OnPlayerAdded(plr)
	end)
	Players.PlayerRemoving:Connect(function(plr)
		local profile = self.HeldProfiles[plr.UserId]
		if profile ~= nil then
			profile:EndSession()
		end
	end)

	-- Handle Existing Players
	for _, Player in pairs(Players:GetPlayers()) do
		if self.HeldProfiles[Player.UserId] == nil then
			self:OnPlayerAdded(Player)
		end
	end
end

function DataService:KnitStart()
	print(`[PlayerDataService]: Started!`)
end

-- Service Functions
function DataService:OnPlayerAdded(plr: Player)
	print(`[PlayerDataService]: Fetching Profile For {plr.Name}...`)

	-- Fetch Profile
	local fetchedProfile = self.FetchedStore.Mock:StartSessionAsync(`{plr.UserId}`, {
		Cancel = function()
			return plr.Parent ~= Players
		end,
	})

	-- Handle Profile
	if fetchedProfile ~= nil then
		print(`[PlayerDataService]: {plr.Name} Profile Found, Loading...`)

		-- Handle Compliance
		fetchedProfile:AddUserId(plr.UserId)

		-- Handle Data Reconciliation
		fetchedProfile:Reconcile()

		-- Handle Profile Events
		self.ProfileConnections[plr.UserId] = {}
		table.insert(
			self.ProfileConnections[plr.UserId],
			-- OnSessionEnd - Handles Cleanup
			fetchedProfile.OnSessionEnd:Connect(function()
				self.HeldProfiles[plr.UserId] = nil
				self.DataManagers[plr.UserId] = nil

				if self.ProfileConnections[plr.UserId] then
					for _, connection in self.ProfileConnections[plr.UserId] do
						connection:Disconnect()
					end
					self.ProfileConnections[plr.UserId] = nil
				end

				if plr:IsDescendantOf(Players) then
					plr:Kick(`[PlayerDataService]: Session Ended - Try Rejoining!`)
				end
			end)
		)

		-- Handle Exit During Session Load
		if plr:IsDescendantOf(Players) == false then
			fetchedProfile:EndSession()
			return
		end

		-- Handle Profile Storage
		print(`[PlayerDataService]: {plr.Name} Profile Loaded, Storing...`)
		self.HeldProfiles[plr.UserId] = fetchedProfile
		self.DataManagers[plr.UserId] = PlayerDataManager.new(plr, fetchedProfile.Data, function()
			self:OnProfileUpdate(plr)
		end)

		-- Update Last Join
		fetchedProfile.Data.Statistics.lastJoin = os.time()

		-- Send initial data to client
		self:OnProfileUpdate(plr)

		print(`[PlayerDataService]: {plr.Name} Profile Loaded Successfully.`)
	else
		-- Profile Failed To Load
		plr:Kick(`[PlayerDataService]: Failed To Load Profile Data - Try Rejoining!`)
	end
end

-- Utility Functions
function DataService.DeepCopy(original)
	-- Define the new table for the copy
	local clone = table.clone(original)

	-- Loop through the original table to check for table values
	-- If a table is found as a value, deep clone it to the key (index)
	for key, value in original do
		if type(value) == "table" then
			clone[key] = DataService.DeepCopy(value)
		end
	end

	-- Return the finalized copy of the deep cloned table
	return clone
end

function DataService:OnProfileUpdate(plr: Player)
	local profile = self.HeldProfiles[plr.UserId]
	if not profile then
		return
	end
	local dataCopy = DataService.DeepCopy(profile.Data)
	self.Client.Data:SetFor(plr, dataCopy)
end

-- Public API for other services
function DataService:GetProfile(player: Player)
	return self.HeldProfiles[player.UserId]
end

function DataService:GetCharacter(player: Player)
	local profile = self:GetProfile(player)
	if profile then
		return profile.Data.Character
	end
end

function DataService:GetData(player: Player)
	local profile = self:GetProfile(player)
	return profile and profile.Data
end

function DataService:UpdateData(player: Player, callback: (data: any) -> ())
	local profile = self:GetProfile(player)
	if not profile then
		return
	end

	callback(profile.Data)
	self:OnProfileUpdate(player)
end

return DataService
