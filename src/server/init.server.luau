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
