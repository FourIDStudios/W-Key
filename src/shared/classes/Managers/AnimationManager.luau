--[[
	AnimationManager

	Manages animation track caching and playback
	for one character. The same manager drives player characters and
	generic NPCs.
    This is purposefully a generic manager, that cares only about the character
    it is attached to.
]]
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = {}
AnimationManager.__index = AnimationManager

function AnimationManager.new(Runtime)
	local self = setmetatable({}, AnimationManager)
	self._Controller = Runtime
	self.Name = "AnimationManager"
	self._character = nil :: Model?
	self._humanoid = nil :: Humanoid?
	self._rootPart = nil :: BasePart?
	self._PlayerAnimator = nil :: Animator?
	self._CurrentAnimationTrack = nil :: AnimationTrack?
	self._CachedAnimationTracks = {} :: { [string]: AnimationTrack }
	self._RunningTracks = {} :: { [string]: AnimationTrack }
	return self
end

function AnimationManager:Init() end
function AnimationManager:Start() end

--[[ ========================================
	 Playback
	======================================== ]]
function AnimationManager:Play(
	Anim: Animation,
	statePriority: Enum.AnimationPriority?,
	doesOverlap: boolean?
): AnimationTrack?
	if self._PlayerAnimator == nil then
		warn(`[AnimationManager]: Animator not ready`)
		return nil
	end

	if
		self._CurrentAnimationTrack
		and self._CurrentAnimationTrack.Animation.Name == Anim.Name
		and self._CurrentAnimationTrack.IsPlaying
	then
		return self._CurrentAnimationTrack
	end

	if doesOverlap then
		local AnimTrackToPlay = nil
		if
			self._CachedAnimationTracks[Anim.Name]
			and self._CachedAnimationTracks[Anim.Name].Animation.AnimationId == Anim.AnimationId
		then
			AnimTrackToPlay = self._CachedAnimationTracks[Anim.Name]
		else
			AnimTrackToPlay = self._PlayerAnimator:LoadAnimation(Anim)
			AnimTrackToPlay.Priority = statePriority or Enum.AnimationPriority.Action
			self._CachedAnimationTracks[Anim.Name] = AnimTrackToPlay
		end

		AnimTrackToPlay:Play(self:GetBlendTime(AnimTrackToPlay.Priority))
		return AnimTrackToPlay
	end

	self:StopPlayingAnimations()

	local AnimTrackToPlay
	if self._CachedAnimationTracks[Anim.Name] then
		AnimTrackToPlay = self._CachedAnimationTracks[Anim.Name]
	else
		AnimTrackToPlay = self._PlayerAnimator:LoadAnimation(Anim)
		AnimTrackToPlay.Priority = statePriority or Enum.AnimationPriority.Action
		self._CachedAnimationTracks[Anim.Name] = AnimTrackToPlay
	end

	self._CurrentAnimationTrack = AnimTrackToPlay
	AnimTrackToPlay:Play(self:GetBlendTime(AnimTrackToPlay.Priority))
	table.insert(self._RunningTracks, AnimTrackToPlay)
	return AnimTrackToPlay
end

function AnimationManager:GetPlayingName()
	if not self._CurrentAnimationTrack then
		return nil
	end
	return self._CurrentAnimationTrack.Animation.Name
end

function AnimationManager:GetTrack(animName: string): AnimationTrack?
	return self._CachedAnimationTracks[animName]
end

--[[ ========================================
	 Caching
	======================================== ]]
function AnimationManager:CacheAnimation(Anim: Animation)
	if self._CachedAnimationTracks[Anim.Name] then
		return
	end

	local capturedAnimator = self._PlayerAnimator
	if not capturedAnimator then
		return
	end
	task.spawn(function()
		ContentProvider:PreloadAsync({ Anim }, function(_, FetchStatus: Enum.AssetFetchStatus)
			if FetchStatus == Enum.AssetFetchStatus.Success then
				if self._PlayerAnimator == capturedAnimator then
					self._CachedAnimationTracks[Anim.Name] = capturedAnimator:LoadAnimation(Anim)
				end
			end
		end)
	end)
end

function AnimationManager:StopPlayingAnimations()
	for _, track: AnimationTrack in self._RunningTracks do
		if track.IsPlaying then
			track:Stop(self:GetBlendTime(track.Priority))
			if track == self._CurrentAnimationTrack then
				self._CurrentAnimationTrack = nil
			end
			table.remove(self._RunningTracks, table.find(self._RunningTracks, track))
		end
	end
end

function AnimationManager:GetBlendTime(Prio: Enum.AnimationPriority)
	return (Prio.Value >= Enum.AnimationPriority.Action.Value and Prio.Value < 1000) and 0.15 or 0.2
end

--[[ ========================================
	 Character Lifecycle
	======================================== ]]
function AnimationManager:OnCharacterAdded(character: Model)
	self._character = character
	self._humanoid = self._Controller:GetHumanoid()
	self._rootPart = self._Controller:GetRootPart()

	if not self._humanoid then
		warn(`[AnimationManager] Humanoid missing when character added`)
		return
	end

	self._PlayerAnimator = self._humanoid:FindFirstChildOfClass("Animator")
		or self._humanoid:WaitForChild("Animator", 5)
	self._CachedAnimationTracks = {}
	self._RunningTracks = {}
	self._CurrentAnimationTrack = nil

	local animationsFolder = ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("Animations")
	if animationsFolder then
		for _, desc in animationsFolder:GetDescendants() do
			if desc:IsA("Animation") then
				self:CacheAnimation(desc)
			end
		end
	end
end

function AnimationManager:OnCharacterRemoving()
	self:StopPlayingAnimations()
	self._character = nil
	self._humanoid = nil
	self._rootPart = nil
	self._PlayerAnimator = nil
	self._CurrentAnimationTrack = nil
	self._CachedAnimationTracks = {}
	self._RunningTracks = {}
end

function AnimationManager:Destroy()
	self:OnCharacterRemoving()
end

return AnimationManager
