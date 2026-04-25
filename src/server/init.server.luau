-- Services & Folders
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

-- Packages
local Knit = require(Packages.Knit)
local PackageFunctions = {
	Knit = {
		OnStart = function()
			print(`[ServerManager]: Loading Services...`)
			Knit.AddServicesDeep(script:WaitForChild("Services"))
			Knit.Start()
				:andThen(function()
					print("[ServerManager]: Knit Started")
				end)
				:catch(warn)
		end,
		OnClose = function() end,
	},
}

-- Lifecycle Functions
function OnServerClose()
	-- Stop Packages
	print("[ServerManager]: Server Closing...")
	for PackageName in PackageFunctions do
		print(`[ServerManager]: Cleaning Up Package ({PackageName})...`)
		local isSuccess, error = pcall(PackageFunctions[PackageName].OnClose)
		if not isSuccess then
			print(`[ServerManager]: {PackageName} Package Failed CleanUp!`)
		end
	end
	print("[ServerManager]: Server Closed!")
end

function OnServerStart()
	-- Start Packages
	print("[ServerManager]: Server Starting...")
	for PackageName in PackageFunctions do
		print(`[ServerManager]: Starting Package ({PackageName})...`)
		local isSuccess, err = pcall(function()
			PackageFunctions[PackageName].OnStart()
		end)
		if not isSuccess then
			print(`[ServerManager]: {PackageName} Package Failed To Load!`, err)
		end
	end

	-- Setup Close Connection
	game:BindToClose(OnServerClose)
	print("[ServerManager]: Server Started!")
end
OnServerStart()
