-- Copies the "animations" folder (wherever it lives) into ReplicatedStorage
-- as "PreviewAnimations" so the client-side previewer can see it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SEARCH = {
	"ServerStorage", "ServerScriptService", "ReplicatedStorage", "Workspace",
	"StarterPack", "StarterPlayer", "StarterGui", "ReplicatedFirst", "Lighting",
}

local function findAnimationsFolder()
	for _, serviceName in SEARCH do
		local ok, service = pcall(game.GetService, game, serviceName)
		if ok then
			for _, inst in service:GetDescendants() do
				if inst.Name:lower() == "animations" and #inst:GetChildren() > 0
					and not Players:GetPlayerFromCharacter(inst:FindFirstAncestorOfClass("Model")) then
					return inst
				end
			end
		end
	end
	return nil
end

local folder = findAnimationsFolder()
if folder then
	local copy = folder:Clone()
	copy.Name = "PreviewAnimations"
	copy.Parent = ReplicatedStorage
	print("[AnimPreviewer] Found", folder:GetFullName())
else
	warn("[AnimPreviewer] No folder named 'animations' found")
end

-- Saved animation picks ------------------------------------------------------
-- The previewer saves picks here so they survive stopping the playtest and
-- are used in the real game. Stored in a DataStore (needs the place published
-- and "Enable Studio Access to API Services" on in Game Settings > Security).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PICKS_KEY = "AnimPicks"

local savedValue = Instance.new("StringValue")
savedValue.Name = "SavedAnimPicks"
savedValue.Value = "{}"
savedValue.Parent = ReplicatedStorage

local saveRemote = Instance.new("RemoteFunction")
saveRemote.Name = "SaveAnimPicks"
saveRemote.Parent = ReplicatedStorage

local okStore, store = pcall(DataStoreService.GetDataStore, DataStoreService, "AnimationPack")
if okStore then
	local ok, data = pcall(store.GetAsync, store, PICKS_KEY)
	if ok and type(data) == "table" then
		savedValue.Value = HttpService:JSONEncode(data)
		print("[AnimPicks] Loaded saved picks")
	elseif not ok then
		warn("[AnimPicks] Couldn't load saved picks:", data)
	end
end

saveRemote.OnServerInvoke = function(_, picks)
	-- only the developer in Studio may change the game's animations
	if not RunService:IsStudio() then
		return false, "Saving only works in Studio"
	end
	if type(picks) ~= "table" then
		return false, "Bad data"
	end
	local clean = {}
	for slot, path in picks do
		if type(slot) == "string" and type(path) == "string" then
			clean[slot] = path
		end
	end
	savedValue.Value = HttpService:JSONEncode(clean)
	if not okStore then
		return false, "Publish the game and turn on Studio API access to keep picks after Stop"
	end
	local ok, err = pcall(store.SetAsync, store, PICKS_KEY, clean)
	if not ok then
		return false, "Turn on Game Settings > Security > Enable Studio Access to API Services (" .. tostring(err) .. ")"
	end
	return true
end
