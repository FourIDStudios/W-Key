--[[
	instanceUtil

	Shared helpers for resolving paths between mirrored Instance trees.

	The `ResolveFolder` helper is the main entry point. Given any Instance in
	one tree and an ancestor name that marks where that tree starts, it walks
	down a parallel tree from a different root and returns the folder at the
	mirrored path.

    note: Mirrored_Path_Util might be a better name for this ngl. 

	Example — resolving a state module's animation folder:
		local folder = instanceUtil.ResolveFolder(
			moduleRef,
			"States",
			ReplicatedStorage.Assets.Animations.States
		)
]]

local instanceUtil = {}

--- Returns the name segments from `from` up to (but not including) an
--- ancestor whose name equals `rootAncestorName`. Segments are ordered
--- from the ancestor downward (root-first, target-last).
--- Returns nil if no matching ancestor is found.
function instanceUtil.GetRelativePath(from: Instance?, rootAncestorName: string): { string }?
	if not from or type(rootAncestorName) ~= "string" or rootAncestorName == "" then
		return nil
	end

	local segments: { string } = {}
	local node: Instance? = from
	while node and node.Name ~= rootAncestorName do
		table.insert(segments, 1, node.Name)
		node = node.Parent
	end

	if not node then
		return nil
	end
	return segments
end

--- Walks `root` using the list of names in `segments`, returning the final
--- Instance or nil if any segment fails to resolve. Empty segment lists
--- return the root itself.
function instanceUtil.FindByPath(root: Instance?, segments: { string }?): Instance?
	if not root then
		return nil
	end
	if not segments or #segments == 0 then
		return root
	end

	local node: Instance? = root
	for _, segment in segments do
		if not node then
			return nil
		end
		node = node:FindFirstChild(segment)
	end
	return node
end

--- Resolves the mirrored folder of `from` under `toRoot`.
--- Walks `from` up to an ancestor matching `fromRootName`, captures the
--- intermediate names, then walks down from `toRoot` using those same
--- names. Returns nil if either side of the path fails to resolve.
function instanceUtil.ResolveFolder(from: Instance?, fromRootName: string, toRoot: Instance?): Instance?
	if not from or not toRoot then
		return nil
	end

	local segments = instanceUtil.GetRelativePath(from, fromRootName)
	if not segments then
		return nil
	end

	return instanceUtil.FindByPath(toRoot, segments)
end

return instanceUtil
