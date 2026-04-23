-- Services & Folders
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages

-- Packages
local Knit = require(Packages.Knit)

local PackageFunctions = {
	Knit = {
		OnStart = function()
			print(`[ClientManager]: Loading Controllers...`)
			Knit.AddControllersDeep(script.Controllers)
			Knit.Start()
				:andThen(function()
					print(`[ClientManager]: Knit Started`)
				end)
				:catch(error)
		end,
		OnClose = function() end,
	},
}

-- Lifecycle Functions
function OnClientClose()
	-- Stop Packages
	print("[ClientManager]: Client Closing...")
	for PackageName in PackageFunctions do
		print(`[ClientManager]: Cleaning Up Package ({PackageName})...`)
		local isSuccess, err = pcall(function()
			PackageFunctions[PackageName].OnClose()
		end)
		if not isSuccess then
			print(`[ClientManager]: {PackageName} Package Failed CleanUp!`, err)
		end
	end
	print("[ClientManager]: Client Closed!")
end

function OnClientStart()
	-- Start Packages
	print("[ClientManager]: Client Starting...")
	for PackageName in PackageFunctions do
		print(`[ClientManager]: Starting Package ({PackageName})...`)
		local isSuccess, err = pcall(function()
			PackageFunctions[PackageName].OnStart()
		end)
		if not isSuccess then
			print(`[ClientManager]: {PackageName} Package Failed To Load!`, err)
		end
	end
	-- Setup Close Connection
	game:BindToClose(OnClientClose)
	print("[ClientManager]: Client Started!")
end
OnClientStart()
