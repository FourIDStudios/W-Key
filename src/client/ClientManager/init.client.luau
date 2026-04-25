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
	},
}

-- Lifecycle Functions
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
	print("[ClientManager]: Client Started!")
end
OnClientStart()
