-- Animation previewer: lists every Animation in the "animations" folder
-- and plays it on your character when you click its name.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

-- Collects Animations and KeyframeSequences (raw, un-uploaded animations,
-- e.g. inside a rig's AnimSaves) from the PreviewAnimations folder.
-- KeyframeSequences get a temporary ID that only works in Studio playtests.
local function collectAnimations()
	local folder = ReplicatedStorage:WaitForChild("PreviewAnimations", 10)
	if not folder then
		return {}
	end
	local anims, seen = {}, {}
	for _, inst in folder:GetDescendants() do
		local anim
		if inst:IsA("Animation") and inst.AnimationId ~= "" then
			anim = inst
		elseif inst:IsA("KeyframeSequence") then
			local ok, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, inst)
			if ok then
				anim = Instance.new("Animation")
				anim.AnimationId = id
			else
				warn("[AnimPreviewer] Couldn't register", inst:GetFullName(), id)
			end
		end
		if anim and not seen[inst] then
			seen[inst] = true
			-- show the path inside the folder, e.g. "Runs/Sprint", skipping AnimSaves
			local parts, node = {}, inst
			while node and node ~= folder do
				if node.Name ~= "AnimSaves" then
					table.insert(parts, 1, node.Name)
				end
				node = node.Parent
			end
			table.insert(anims, { name = table.concat(parts, "/"), anim = anim })
		end
	end
	table.sort(anims, function(a, b) return a.name:lower() < b.name:lower() end)
	return anims
end

-- UI ------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AnimPreviewer"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(280, 420)
frame.Position = UDim2.new(0, 16, 0.5, -210)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
frame.Parent = gui
Instance.new("UICorner").Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 30)
title.Position = UDim2.fromOffset(8, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 36)
status.Position = UDim2.fromOffset(8, 32)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextWrapped = true
status.TextColor3 = Color3.fromRGB(180, 180, 190)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "Click a name to play it."
status.Parent = frame

local stopButton = Instance.new("TextButton")
stopButton.Size = UDim2.new(1, -16, 0, 28)
stopButton.Position = UDim2.new(0, 8, 1, -36)
stopButton.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
stopButton.Font = Enum.Font.GothamBold
stopButton.TextSize = 14
stopButton.TextColor3 = Color3.new(1, 1, 1)
stopButton.Text = "Stop"
stopButton.Parent = frame
Instance.new("UICorner").Parent = stopButton

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -116)
list.Position = UDim2.fromOffset(8, 72)
list.BackgroundTransparency = 1
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = frame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = list

-- Playback -------------------------------------------------------------
local currentTrack

local function stop()
	if currentTrack then
		currentTrack:Stop(0.2)
		currentTrack = nil
	end
end

local function play(entry)
	stop()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		status.Text = "No character yet - press Play first."
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local ok, track = pcall(animator.LoadAnimation, animator, entry.anim)
	if not ok then
		status.Text = "Couldn't load " .. entry.name .. ": " .. tostring(track)
		return
	end
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play(0.2)
	currentTrack = track
	status.Text = "Playing: " .. entry.name
	task.delay(1, function()
		if currentTrack == track and track.Length == 0 then
			status.Text = entry.name .. " didn't load - you may not own it, or it's for a different rig (R6/R15)."
		end
	end)
end

stopButton.MouseButton1Click:Connect(function()
	stop()
	status.Text = "Stopped."
end)

-- Build list -----------------------------------------------------------
local anims = collectAnimations()
title.Text = ("Animations (%d)"):format(#anims)
if #anims == 0 then
	status.Text = "No animations found. Check Output for [AnimPreviewer] messages."
end

for _, entry in anims do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -8, 0, 28)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	button.Font = Enum.Font.Gotham
	button.TextSize = 13
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.Text = "  " .. entry.name
	button.Parent = list
	Instance.new("UICorner").Parent = button
	button.MouseButton1Click:Connect(function()
		play(entry)
	end)
end

return {}
