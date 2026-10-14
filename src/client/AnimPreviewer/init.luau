-- Animation previewer + selector.
-- Click an animation to preview it (on the pack's dummy and on you), then
-- click a slot to assign it. Standard slots are applied to your R6
-- character's Animate script live. "Print selection" writes the picks to
-- Output so they can be copied into the final pack.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer

-- slot name -> the Animate script value it maps to (nil = custom, scripted later)
local SLOTS = {
	{ name = "Idle", animate = "idle" },
	{ name = "Walk", animate = "walk" },
	{ name = "Run", animate = "run" },
	{ name = "Jump", animate = "jump" },
	{ name = "Fall", animate = "fall" },
	{ name = "Climb", animate = "climb" },
	{ name = "Swim" },
	{ name = "Crouch" },
	{ name = "CrouchWalk" },
	{ name = "Prone" },
	{ name = "Slide" },
	{ name = "Land" },
	{ name = "Wallrun" },
}

local selection = {} -- slot name -> entry

-- Collect animations ------------------------------------------------------
local function collectAnimations()
	local folder = ReplicatedStorage:WaitForChild("PreviewAnimations", 10)
	if not folder then
		return {}
	end
	local anims = {}
	for _, inst in folder:GetDescendants() do
		local anim
		if inst:IsA("Animation") and inst.AnimationId ~= "" then
			anim = inst
		elseif inst:IsA("KeyframeSequence") then
			-- raw, un-uploaded animation: temporary ID, Studio playtests only
			local ok, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, inst)
			if ok then
				anim = Instance.new("Animation")
				anim.AnimationId = id
			else
				warn("[AnimPreviewer] Couldn't register", inst:GetFullName(), id)
			end
		end
		if anim then
			-- path inside the folder, e.g. "Runs/Sprint", skipping AnimSaves
			local parts, node = {}, inst
			while node and node ~= folder do
				if node.Name ~= "AnimSaves" then
					table.insert(parts, 1, node.Name)
				end
				node = node.Parent
			end
			table.insert(anims, {
				name = table.concat(parts, "/"),
				anim = anim,
				rig = inst:FindFirstAncestorOfClass("Model"),
			})
		end
	end
	table.sort(anims, function(a, b) return a.name:lower() < b.name:lower() end)
	return anims
end

-- UI helpers ----------------------------------------------------------------
local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function button(text, color, parent)
	local b = make("TextButton", {
		BackgroundColor3 = color,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		AutoButtonColor = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	return b
end

local gui = make("ScreenGui", { Name = "AnimPreviewer", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

local frame = make("Frame", {
	Size = UDim2.fromOffset(520, 460),
	Position = UDim2.new(0, 16, 0.5, -230),
	BackgroundColor3 = Color3.fromRGB(30, 30, 36),
}, gui)
make("UICorner", {}, frame)

local title = make("TextLabel", {
	Size = UDim2.new(1, -16, 0, 26),
	Position = UDim2.fromOffset(8, 4),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Loading animations...",
}, frame)

local status = make("TextLabel", {
	Size = UDim2.new(1, -16, 0, 32),
	Position = UDim2.fromOffset(8, 28),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(180, 180, 190),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "1. Click an animation to preview it.  2. Click a slot on the right to assign it.",
}, frame)

-- left: animation list
local list = make("ScrollingFrame", {
	Size = UDim2.new(0, 260, 1, -108),
	Position = UDim2.fromOffset(8, 64),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, frame)
make("UIListLayout", { Padding = UDim.new(0, 4) }, list)

-- right: slots
local slotList = make("ScrollingFrame", {
	Size = UDim2.new(1, -284, 1, -108),
	Position = UDim2.fromOffset(276, 64),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, frame)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, slotList)

local stopButton = button("Stop", Color3.fromRGB(170, 50, 50), frame)
stopButton.Size = UDim2.new(0.5, -12, 0, 30)
stopButton.Position = UDim2.new(0, 8, 1, -38)
stopButton.Font = Enum.Font.GothamBold

local printButton = button("Print selection", Color3.fromRGB(40, 120, 70), frame)
printButton.Size = UDim2.new(0.5, -12, 0, 30)
printButton.Position = UDim2.new(0.5, 4, 1, -38)
printButton.Font = Enum.Font.GothamBold

-- Playback ------------------------------------------------------------------
local currentTracks = {}
local previewRig
local current -- entry being previewed

local function stop()
	for _, track in currentTracks do
		track:Stop(0.2)
	end
	currentTracks = {}
	if previewRig then
		previewRig:Destroy()
		previewRig = nil
	end
end

local function getAnimator(model)
	local controller = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")
	if not controller then
		return nil
	end
	return controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
end

local function playOn(model, entry)
	local animator = model and getAnimator(model)
	if not animator then
		return nil
	end
	local ok, track = pcall(animator.LoadAnimation, animator, entry.anim)
	if not ok then
		warn("[AnimPreviewer] Couldn't load", entry.name, track)
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play(0.2)
	table.insert(currentTracks, track)
	return track
end

-- copy of the pack's own dummy in front of you, so the animation is shown
-- on the rig it was made for
local function spawnPreviewRig(rig)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not rig or not root then
		return nil
	end
	local clone = rig:Clone()
	for _, inst in clone:GetDescendants() do
		if inst.Name == "AnimSaves" or inst:IsA("Script") or inst:IsA("LocalScript") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.CanCollide = false
		end
	end
	local rigRoot = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart
	if rigRoot then
		rigRoot.Anchored = true
		clone.PrimaryPart = rigRoot
		local spot = (root.CFrame * CFrame.new(0, 0, -8)).Position
		clone:PivotTo(CFrame.lookAt(spot, Vector3.new(root.Position.X, spot.Y, root.Position.Z)))
	end
	clone.Parent = workspace
	return clone
end

local function play(entry)
	stop()
	current = entry
	previewRig = spawnPreviewRig(entry.rig)
	local rigTrack = playOn(previewRig, entry)
	local charTrack = playOn(player.Character, entry)
	if not rigTrack and not charTrack then
		status.Text = "Couldn't play " .. entry.name .. " - check Output."
		return
	end
	status.Text = "Previewing: " .. entry.name .. "  -> click a slot on the right to assign it."
end

-- Applying to the character -------------------------------------------------
-- Points the R6 Animate script's values at the selected animations.
local function applyToCharacter()
	local character = player.Character
	local animate = character and character:FindFirstChild("Animate")
	if not animate then
		return
	end
	for _, slot in SLOTS do
		local entry = selection[slot.name]
		local value = slot.animate and animate:FindFirstChild(slot.animate)
		if entry and value then
			for _, anim in value:GetChildren() do
				if anim:IsA("Animation") then
					anim.AnimationId = entry.anim.AnimationId
				end
			end
		end
	end
	-- restart Animate so it reloads the new IDs
	animate.Disabled = true
	animate.Disabled = false
end

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("Animate")
	applyToCharacter()
end)

-- Slots ---------------------------------------------------------------------
local slotButtons = {}

local function refreshSlot(slot)
	local entry = selection[slot.name]
	local b = slotButtons[slot.name]
	b.Text = ("  %s: %s"):format(slot.name, entry and entry.name or "—")
	b.BackgroundColor3 = entry and Color3.fromRGB(40, 90, 150) or Color3.fromRGB(50, 50, 60)
end

for i, slot in SLOTS do
	local b = button("", Color3.fromRGB(50, 50, 60), slotList)
	b.Size = UDim2.new(1, -8, 0, 28)
	b.LayoutOrder = i
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextTruncate = Enum.TextTruncate.AtEnd
	slotButtons[slot.name] = b
	refreshSlot(slot)
	b.MouseButton1Click:Connect(function()
		if not current then
			status.Text = "Click an animation on the left first, then a slot."
			return
		end
		if selection[slot.name] == current then
			selection[slot.name] = nil -- click again to clear
			status.Text = "Cleared " .. slot.name .. "."
		else
			selection[slot.name] = current
			status.Text = ("Assigned %s -> %s%s"):format(current.name, slot.name,
				slot.animate and " (applied to you - press Stop to see it)" or " (custom slot, scripted in the final pack)")
		end
		refreshSlot(slot)
		applyToCharacter()
	end)
end

stopButton.MouseButton1Click:Connect(function()
	stop()
	current = nil
	status.Text = "Stopped. Move around to see your assigned animations."
end)

printButton.MouseButton1Click:Connect(function()
	local lines = { "[AnimPreviewer] Selection - copy this to Claude:" }
	for _, slot in SLOTS do
		local entry = selection[slot.name]
		table.insert(lines, ("%s = %s"):format(slot.name, entry and entry.name or "(none)"))
	end
	print(table.concat(lines, "\n"))
	status.Text = "Printed to Output (View -> Output). Copy it and send it to Claude."
end)

-- Build list ------------------------------------------------------------------
local anims = collectAnimations()
title.Text = ("Animations (%d)"):format(#anims)
if #anims == 0 then
	status.Text = "No animations found. Check Output for [AnimPreviewer] messages."
end

for _, entry in anims do
	local b = button("  " .. entry.name, Color3.fromRGB(50, 50, 60), list)
	b.Size = UDim2.new(1, -8, 0, 28)
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.MouseButton1Click:Connect(function()
		play(entry)
	end)
end

return {}
