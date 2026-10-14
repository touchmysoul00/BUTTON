-- Animation previewer + selector.
-- Click an animation to preview it in the preview window (on the pack's
-- own dummy), then click a slot to apply it to your character live.
-- "Print selection" writes the picks to Output so they can go into AnimConfig.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer

local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimConfig"))
local SLOTS = config.Order

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

-- P shows/hides the previewer
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then
		gui.Enabled = not gui.Enabled
	end
end)

local frame = make("Frame", {
	Size = UDim2.fromOffset(760, 460),
	Position = UDim2.new(0.5, -380, 0.5, -230),
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
	Text = "1. Click an animation on the left - it plays in the preview window.  2. Click a slot on the right to apply it.",
}, frame)

-- left: animation list
local list = make("ScrollingFrame", {
	Size = UDim2.new(0, 240, 1, -108),
	Position = UDim2.fromOffset(8, 64),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, frame)
make("UIListLayout", { Padding = UDim.new(0, 4) }, list)

-- right: slots
local slotList = make("ScrollingFrame", {
	Size = UDim2.new(0, 220, 1, -108),
	Position = UDim2.new(1, -228, 0, 64),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, frame)
make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, slotList)

-- middle: preview window
local viewport = make("ViewportFrame", {
	Size = UDim2.fromOffset(268, 340),
	Position = UDim2.fromOffset(256, 64),
	BackgroundColor3 = Color3.fromRGB(55, 58, 70),
	Ambient = Color3.fromRGB(200, 200, 200),
	LightColor = Color3.new(1, 1, 1),
}, frame)
make("UICorner", {}, viewport)
local worldModel = make("WorldModel", {}, viewport)
local camera = make("Camera", { FieldOfView = 40 }, viewport)
viewport.CurrentCamera = camera
local previewLabel = make("TextLabel", {
	Size = UDim2.new(1, -12, 0, 20),
	Position = UDim2.fromOffset(6, 4),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Text = "Preview",
	ZIndex = 2,
}, viewport)

local stopButton = button("Stop", Color3.fromRGB(170, 50, 50), frame)
stopButton.Size = UDim2.new(0.5, -12, 0, 30)
stopButton.Position = UDim2.new(0, 8, 1, -38)
stopButton.Text = "Stop preview"
stopButton.Font = Enum.Font.GothamBold

local printButton = button("Print selection", Color3.fromRGB(40, 120, 70), frame)
printButton.Size = UDim2.new(0.5, -12, 0, 30)
printButton.Position = UDim2.new(0.5, 4, 1, -38)
printButton.Font = Enum.Font.GothamBold

-- Playback ------------------------------------------------------------------
local currentTrack
local previewRig
local current -- entry being previewed

local function stop()
	if currentTrack then
		currentTrack:Stop(0)
		currentTrack = nil
	end
	if previewRig then
		previewRig:Destroy()
		previewRig = nil
	end
	previewLabel.Text = "Preview"
end

-- copy of the pack's own dummy (the rig the animation was made for),
-- placed in the preview window's WorldModel
local function spawnPreviewRig(rig)
	local clone = rig:Clone()
	for _, inst in clone:GetDescendants() do
		if inst.Name == "AnimSaves" or inst:IsA("Script") or inst:IsA("LocalScript") then
			inst:Destroy()
		end
	end
	local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		clone:Destroy()
		return nil
	end
	root.Anchored = true
	clone.PrimaryPart = root
	clone:PivotTo(CFrame.new())
	clone.Parent = worldModel
	-- camera in front of the rig, framing the whole body
	local box, size = clone:GetBoundingBox()
	local distance = math.max(size.X, size.Y) * 1.9 + 2
	local center = box.Position
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0, -distance), center)
	return clone
end

local function play(entry)
	stop()
	current = entry
	if not entry.rig then
		status.Text = entry.name .. " has no dummy rig to preview on."
		return
	end
	previewRig = spawnPreviewRig(entry.rig)
	local controller = previewRig and (previewRig:FindFirstChildOfClass("Humanoid") or previewRig:FindFirstChildOfClass("AnimationController"))
	if not controller then
		status.Text = "Couldn't preview " .. entry.name .. " - its dummy has no Humanoid."
		return
	end
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
	local ok, track = pcall(animator.LoadAnimation, animator, entry.anim)
	if not ok then
		warn("[AnimPreviewer] Couldn't load", entry.name, track)
		status.Text = "Couldn't load " .. entry.name .. " - check Output."
		return
	end
	track.Looped = true
	track:Play(0)
	currentTrack = track
	previewLabel.Text = entry.name
	status.Text = "Previewing " .. entry.name .. ". Like it? Click a slot on the right to apply it."
end

-- Slots ---------------------------------------------------------------------
local slotButtons = {}

-- Animate script picks these up live (player attributes "Anim_<slot>")
local function applySlot(slot)
	local entry = selection[slot]
	player:SetAttribute("Anim_" .. slot, entry and entry.name or nil)
end

local function refreshSlot(slot)
	local entry = selection[slot]
	local current = entry and entry.name or config.Slots[slot]
	local b = slotButtons[slot]
	b.Text = ("  %s: %s"):format(slot, current or "—")
	b.BackgroundColor3 = entry and Color3.fromRGB(40, 90, 150) or Color3.fromRGB(50, 50, 60)
end

for i, slot in SLOTS do
	local b = button("", Color3.fromRGB(50, 50, 60), slotList)
	b.Size = UDim2.new(1, -8, 0, 28)
	b.LayoutOrder = i
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextTruncate = Enum.TextTruncate.AtEnd
	slotButtons[slot] = b
	refreshSlot(slot)
	b.MouseButton1Click:Connect(function()
		if not current then
			status.Text = "Click an animation on the left first, then a slot."
			return
		end
		if selection[slot] == current then
			selection[slot] = nil -- click again to undo
			status.Text = "Reset " .. slot .. " to the default."
		else
			selection[slot] = current
			status.Text = ("%s -> %s. Applied to your character - close this with P and move to try it."):format(current.name, slot)
		end
		refreshSlot(slot)
		applySlot(slot)
	end)
end

stopButton.MouseButton1Click:Connect(function()
	stop()
	current = nil
	status.Text = "Stopped. Walk around to see the animations you applied."
end)

printButton.MouseButton1Click:Connect(function()
	local lines = { "[AnimPreviewer] Selection - copy this to Claude:" }
	for _, slot in SLOTS do
		local entry = selection[slot]
		local value = entry and entry.name or config.Slots[slot]
		table.insert(lines, ("%s = %s"):format(slot, value and ('"' .. value .. '"') or "nil"))
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
