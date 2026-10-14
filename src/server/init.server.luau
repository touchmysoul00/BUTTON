-- Makes an "animations" folder that lives somewhere only the server can see
-- (ServerStorage / ServerScriptService) visible to clients for the previewer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function findAnimationsFolder()
	for _, service in { game:GetService("ServerStorage"), game:GetService("ServerScriptService") } do
		for _, child in service:GetDescendants() do
			if child.Name:lower() == "animations" and #child:GetChildren() > 0 then
				return child
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
	print("[AnimPreviewer] Copied", folder:GetFullName(), "for preview")
end
