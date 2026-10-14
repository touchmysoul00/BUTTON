-- Animation picker (press P).
-- 1. Click a move on the left (Walk, Run, Jump...).
-- 2. Click an animation in the middle - it plays in the preview on the right
--    AND goes on your character straight away. Picks are saved automatically.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer
local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimConfig"))
local AutoPick = require(ReplicatedStorage.Shared:WaitForChild("AutoPick"))

-- friendly names for the moves
local LABELS = {
	Idle = "Standing still", Walk = "Walk forward", WalkBack = "Walk backward",
	WalkLeft = "Walk left", WalkRight = "Walk right", Run = "Run forward (Shift)",
	RunBack = "Run backward", RunLeft = "Run left", RunRight = "Run right",
	Jump = "Jump", Fall = "Falling", Land = "Landing", Climb = "Climbing",
	ClimbIdle = "Climb (not moving)", Swim = "Swimming", Crouch = "Crouch (C)",
	CrouchWalk = "Crouch walk forward", CrouchWalkBack = "Crouch walk backward",
	CrouchWalkLeft = "Crouch walk left", CrouchWalkRight = "Crouch walk right",
	Slide = "Slide (C while running)",
}

-- Saved picks -----------------------------------------------------------------
local picks = {} -- move -> pack path
do
	local saved = ReplicatedStorage:WaitForChild("SavedAnimPicks", 10)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, saved and saved.Value or "{}")
	if ok and type(data) == "table" then
		picks = data
	end
end

-- Animations in the pack --------------------------------------------------------
local anims = {} -- { name = "Walks/Walk Back", anim = Animation, rig = Model }
do
	local folder = ReplicatedStorage:WaitForChild("PreviewAnimations", 10)
	for _, inst in folder and folder:GetDescendants() or {} do
		local anim
		if inst:IsA("Animation") and inst.AnimationId ~= "" then
			anim = inst
		elseif inst:IsA("KeyframeSequence") then
			local ok, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, inst)
			if ok then
				anim = Instance.new("Animation")
				anim.AnimationId = id
			end
		end
		if anim then
			local parts, node = {}, inst
			while node and node ~= folder do
				if node.Name ~= "AnimSaves" then
					table.insert(parts, 1, node.Name)
				end
				node = node.Parent
			end
			table.insert(anims, { name = table.concat(parts, "/"), anim = anim, rig = inst:FindFirstAncestorOfClass("Model") })
		end
	end
	table.sort(anims, function(a, b) return a.name:lower() < b.name:lower() end)
end

local autoPicks
do
	local paths = {}
	for _, entry in anims do
		table.insert(paths, entry.name)
	end
	autoPicks = AutoPick(paths)
end

local function currentPick(move)
	return picks[move] or config.Slots[move] or autoPicks[move]
end

-- UI ------------------------------------------------------------------------------
local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local GREY, BLUE, GREEN = Color3.fromRGB(50, 50, 60), Color3.fromRGB(40, 90, 150), Color3.fromRGB(40, 130, 70)

local function button(text, parent)
	local b = make("TextButton", {
		Size = UDim2.new(1, -8, 0, 30),
		BackgroundColor3 = GREY,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "  " .. text,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	return b
end

local function column(x, width, heading, parent)
	make("TextLabel", {
		Size = UDim2.fromOffset(width, 20),
		Position = UDim2.fromOffset(x, 56),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = heading,
	}, parent)
	local list = make("ScrollingFrame", {
		Size = UDim2.new(0, width, 1, -88),
		Position = UDim2.fromOffset(x, 78),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, parent)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	return list
end

local gui = make("ScreenGui", { Name = "AnimPicker", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
local frame = make("Frame", {
	Size = UDim2.fromOffset(800, 480),
	Position = UDim2.new(0.5, -400, 0.5, -240),
	BackgroundColor3 = Color3.fromRGB(30, 30, 36),
}, gui)
make("UICorner", {}, frame)

make("TextLabel", {
	Size = UDim2.new(1, -16, 0, 24),
	Position = UDim2.fromOffset(10, 6),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Animation Picker  (P to close)",
}, frame)
local status = make("TextLabel", {
	Size = UDim2.new(1, -16, 0, 20),
	Position = UDim2.fromOffset(10, 30),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(255, 220, 120),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Text = ("Step 1: click a move on the left.   (%d animations found)"):format(#anims),
}, frame)

local movesList = column(10, 230, "1. MOVE", frame)
local choicesList = column(250, 260, "2. ANIMATION (click to use it)", frame)

make("TextLabel", {
	Size = UDim2.fromOffset(270, 20),
	Position = UDim2.fromOffset(520, 56),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(200, 200, 210),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "PREVIEW",
}, frame)
local viewport = make("ViewportFrame", {
	Size = UDim2.new(0, 270, 1, -88),
	Position = UDim2.fromOffset(520, 78),
	BackgroundColor3 = Color3.fromRGB(55, 58, 70),
	Ambient = Color3.fromRGB(200, 200, 200),
	LightColor = Color3.new(1, 1, 1),
}, frame)
make("UICorner", {}, viewport)
local worldModel = make("WorldModel", {}, viewport)
local camera = make("Camera", { FieldOfView = 40 }, viewport)
viewport.CurrentCamera = camera

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then
		gui.Enabled = not gui.Enabled
	end
end)

-- Preview ---------------------------------------------------------------------------
local previewRig, previewTrack

local function preview(entry)
	if previewTrack then
		previewTrack:Stop(0)
	end
	if previewRig then
		previewRig:Destroy()
	end
	previewRig, previewTrack = nil, nil
	if not entry or not entry.rig then
		return
	end
	local clone = entry.rig:Clone()
	for _, inst in clone:GetDescendants() do
		if inst.Name == "AnimSaves" or inst:IsA("BaseScript") then
			inst:Destroy()
		end
	end
	local root = clone:FindFirstChild("HumanoidRootPart") or clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	local controller = clone:FindFirstChildOfClass("Humanoid") or clone:FindFirstChildOfClass("AnimationController")
	if not root or not controller then
		clone:Destroy()
		return
	end
	root.Anchored = true
	clone.PrimaryPart = root
	clone:PivotTo(CFrame.new())
	clone.Parent = worldModel
	local box, size = clone:GetBoundingBox()
	local distance = math.max(size.X, size.Y) * 1.9 + 2
	camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, 0, -distance), box.Position)
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
	local ok, track = pcall(animator.LoadAnimation, animator, entry.anim)
	if ok then
		track.Looped = true
		track:Play(0)
		previewTrack = track
	end
	previewRig = clone
end

-- Saving ------------------------------------------------------------------------------
local saveRemote = ReplicatedStorage:WaitForChild("SaveAnimPicks", 10)
local saving, pending = false, false
local function save()
	if not saveRemote then
		return
	end
	if saving then
		pending = true
		return
	end
	saving = true
	task.spawn(function()
		local ok, success, err = pcall(saveRemote.InvokeServer, saveRemote, picks)
		saving = false
		if pending then
			pending = false
			save()
		elseif ok and success then
			status.Text ..= "  ✓ Saved"
		else
			status.Text = "Works now, but won't be kept after Stop: " .. tostring(err or success)
		end
	end)
end

-- Moves and choices -------------------------------------------------------------------
local moveButtons = {}
local selectedMove

local function refreshMove(move)
	local b = moveButtons[move]
	local pick = currentPick(move)
	b.Text = ("  %s\n  → %s"):format(LABELS[move] or move, pick and pick:match("[^/]+$") or "none")
	b.BackgroundColor3 = move == selectedMove and BLUE or GREY
end

-- suggest animations from the same folder as the automatic pick first
local function sortedChoices(move)
	local pick = currentPick(move)
	local folder = pick and pick:match("^(.*)/[^/]+$")
	local list = table.clone(anims)
	table.sort(list, function(a, b)
		local aIn = folder and a.name:sub(1, #folder) == folder
		local bIn = folder and b.name:sub(1, #folder) == folder
		if aIn ~= bIn then
			return aIn
		end
		return a.name:lower() < b.name:lower()
	end)
	return list
end

local function showChoices(move)
	for _, child in choicesList:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local pick = currentPick(move)
	for i, entry in sortedChoices(move) do
		local b = button(entry.name, choicesList)
		b.LayoutOrder = i
		b.BackgroundColor3 = entry.name == pick and GREEN or GREY
		b.MouseButton1Click:Connect(function()
			picks[move] = entry.name
			player:SetAttribute("Anim_" .. move, entry.name) -- Animate script swaps it in now
			preview(entry)
			for _, other in choicesList:GetChildren() do
				if other:IsA("GuiButton") then
					other.BackgroundColor3 = GREY
				end
			end
			b.BackgroundColor3 = GREEN
			refreshMove(move)
			status.Text = ("%s now uses %s. Close with P and try it."):format(LABELS[move] or move, entry.name)
			save()
		end)
	end
end

local reset = button("Reset everything to automatic", movesList)
reset.LayoutOrder = 1000
reset.BackgroundColor3 = Color3.fromRGB(110, 50, 50)
reset.MouseButton1Click:Connect(function()
	picks = {}
	for _, move in config.Order do
		player:SetAttribute("Anim_" .. move, "")
		refreshMove(move)
	end
	if selectedMove then
		showChoices(selectedMove)
	end
	status.Text = "Everything is back to automatic."
	save()
end)

for i, move in config.Order do
	local b = button("", movesList)
	b.Size = UDim2.new(1, -8, 0, 40)
	b.LayoutOrder = i
	moveButtons[move] = b
	refreshMove(move)
	b.MouseButton1Click:Connect(function()
		local previous = selectedMove
		selectedMove = move
		if previous then
			refreshMove(previous)
		end
		refreshMove(move)
		showChoices(move)
		local pick = currentPick(move)
		for _, entry in anims do
			if entry.name == pick then
				preview(entry)
			end
		end
		status.Text = ("Step 2: click an animation for \"%s\". Green = the one it uses now."):format(LABELS[move] or move)
	end)
end

if #anims == 0 then
	status.Text = "No animations found - is the Animations folder in the game?"
end

return {}
