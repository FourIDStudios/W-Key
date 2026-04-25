--!strict
--!optimize 2

--[[

______  _____   _______   ___   _____ _____        _   _ _____ _____ _   _  ___   _     _____ ______ ___________ 
| ___ \/ _ \ \ / /  __ \ / _ \ /  ___|_   _|      | | | |_   _/  ___| | | |/ _ \ | |   |_   _|___  /|  ___| ___ \
| |_/ / /_\ \ V /| /  \// /_\ \\ `--.  | |        | | | | | | \ `--.| | | / /_\ \| |     | |    / / | |__ | |_/ /
|    /|  _  |\ / | |    |  _  | `--. \ | |        | | | | | |  `--. \ | | |  _  || |     | |   / /  |  __||    / 
| |\ \| | | || | | \__/\| | | |/\__/ / | |        \ \_/ /_| |_/\__/ / |_| | | | || |_____| |_./ /___| |___| |\ \ 
\_| \_\_| |_/\_/  \____/\_| |_/\____/  \_/         \___/ \___/\____/ \___/\_| |_/\_____/\___/\_____/\____/\_| \_|
                                                                                                            
                                                                                                            


Author: @Tasty_Snicker
Date Created: 3/21/2025
Edited By: VashTheGamerElite


Thanks for using this Raycast-Visualizer. This didn't take me long to make and this wasn't fully bug-tested yet. This is just a simple tool to-
visualize where a raycast is getting casted towards. API usage will be below this message

API:
.new(RaycastVisualizerSettings) Creates a new RaycastVisualizer
RaycastVisualizer:Draw(Origin: Vector3, EndPosition: Vector3, Color: Color3, VisualsDuration: number?) -> Creates new visualizers in the worldspace and checks if the max visualizers have been made.
RaycastVisualizer:GetVisualizedCount(): number -> Returns the amount of visuals the RaycastVisualizer has created (does not account for visuals made by other RaycastVisualizers').
RaycastVisualizer:GetAllVisualizedRaysCount(): number -> Returns ALL visualized rays made by all RaycastVisualizer.
RaycastVisualizer:Cleanup() -> Cleansup all visuals made by the current RaycastVisualizer.
RaycastVisualizer:CleanAllVisuals() -> Cleans up all visuals made by ANY RaycastVisualizer.
RaycastVisualizer:Destroy() -> Destroys the RaycastVisualizer class from becoming usable and performs Cleanup.

]]

local RaycastVisualizerClass = {} :: RaycastVisualizer
RaycastVisualizerClass.__index = RaycastVisualizerClass

--// Types \\--
type self = {

	_VisualizerSettings: RaycastVisualizerSettings,
	_RayVisualizeCount: number,
	_VisualRaycasts: { Instance },
	_VisualizersFolder: Folder,

	new: (RaycastVisualizerSettings: RaycastVisualizerSettings) -> RaycastVisualizer,
	Draw: (
		self: RaycastVisualizer,
		Origin: Vector3,
		EndPosition: Vector3,
		Color: Color3,
		VisualsDuration: number?
	) -> (),
	Cleanup: (self: RaycastVisualizer) -> (),
	GetVisualizedCount: (self: RaycastVisualizer) -> number,
	GetAllVisualizedRaysCount: (self: RaycastVisualizer) -> number,
	CleanAllVisuals: (self: RaycastVisualizer) -> (),
	Destroy: (self: RaycastVisualizer) -> (),
}

type RaycastVisualizerSettings = {

	LOG_MESSAGES: boolean,
	AUTO_CLEANUP: boolean,
	MAX_VISUALIZERS: number,
}

export type RaycastVisualizer = typeof(setmetatable({} :: self, RaycastVisualizerClass))

--// Private Functions \\--

--Logs all messages and auto checks for the LOG_MESSAGE condition
local function logMessage(Message: string, asWarning: boolean, LogMessage: boolean)
	if not LogMessage then
		return
	end
	if asWarning then
		warn(Message)
	else
		print(Message)
	end
end

--// Public Functions \\--

--Creates a new RaycastVisualizer
function RaycastVisualizerClass.new(RaycastVisualizerSettings: RaycastVisualizerSettings): RaycastVisualizer
	local self = setmetatable({} :: self, RaycastVisualizerClass)
	self._RayVisualizeCount = 0
	self._VisualRaycasts = {}

	self._VisualizerSettings = RaycastVisualizerSettings

	self._VisualizersFolder = workspace:FindFirstChild("_RayVisualizers") or Instance.new("Folder")
	do
		self._VisualizersFolder.Name = "_RayVisualizers"
		self._VisualizersFolder.Parent = workspace
	end

	return self
end

--Visualizes the raycast utilizing LineHandleAdornments and ConeHandleAdornment.
function RaycastVisualizerClass:Draw(Origin: Vector3, EndPosition: Vector3, Color: Color3, VisualsDuration: number?)
	if self:GetVisualizedCount() >= self._VisualizerSettings.MAX_VISUALIZERS then
		if not self._VisualizerSettings.AUTO_CLEANUP then
			return
		end
		self:Cleanup()
	end

	local Distance = (Origin - EndPosition).Magnitude

	local LineHandleAdornment = Instance.new("LineHandleAdornment")
	LineHandleAdornment.Color3 = Color
	LineHandleAdornment.Length = Distance
	LineHandleAdornment.Thickness = 4
	LineHandleAdornment.AlwaysOnTop = false
	LineHandleAdornment.ZIndex = 1
	LineHandleAdornment.CFrame = CFrame.lookAt(Origin, EndPosition)
	LineHandleAdornment.Adornee = workspace.Terrain
	LineHandleAdornment.Parent = self._VisualizersFolder

	local ConeHandleAdornment = Instance.new("ConeHandleAdornment")
	ConeHandleAdornment.Color3 = Color
	ConeHandleAdornment.Height = 0.3
	ConeHandleAdornment.Radius = 0.15
	ConeHandleAdornment.AlwaysOnTop = true
	ConeHandleAdornment.ZIndex = 1
	ConeHandleAdornment.Adornee = workspace.Terrain
	ConeHandleAdornment.CFrame = LineHandleAdornment.CFrame * CFrame.new(0, 0, -Distance)
	ConeHandleAdornment.Parent = self._VisualizersFolder

	self._RayVisualizeCount += 2

	table.insert(self._VisualRaycasts, LineHandleAdornment)
	table.insert(self._VisualRaycasts, ConeHandleAdornment)

	if not VisualsDuration then
		return
	end
	task.delay(VisualsDuration, function()
		table.remove(self._VisualRaycasts, table.find(self._VisualRaycasts, LineHandleAdornment))
		table.remove(self._VisualRaycasts, table.find(self._VisualRaycasts, ConeHandleAdornment))

		LineHandleAdornment:Destroy()
		ConeHandleAdornment:Destroy()
	end)
end

--Returns the amount of visualizers the class made.
function RaycastVisualizerClass:GetVisualizedCount(): number
	return self._RayVisualizeCount
end

--Returns ALL visualizers made by all RaycastVisualizers.
function RaycastVisualizerClass:GetAllVisualizedRaysCount(): number
	return #self._VisualizersFolder:GetChildren()
end

--Cleansup all visualizers made from this class.
function RaycastVisualizerClass:Cleanup()
	for Index, RaycastVisualizers in self._VisualRaycasts do
		RaycastVisualizers:Destroy()
	end

	logMessage(
		`THERE WAS A TOTAL OF {self._RayVisualizeCount} RAY VISUALIZERS!`,
		true,
		self._VisualizerSettings.LOG_MESSAGES
	)

	self._RayVisualizeCount = 0
	table.clear(self._VisualRaycasts)
end

--Cleans ALL visuals from the workspace.
function RaycastVisualizerClass:CleanAllVisuals()
	self:Cleanup()
	for _, Visualizer in self._VisualizersFolder:GetChildren() do
		Visualizer:Destroy()
	end
end

--Cleans up all visualizers from this class and sets nil to the class.
function RaycastVisualizerClass:Destroy()
	self:Cleanup()
	setmetatable(self, nil)
end

return RaycastVisualizerClass
