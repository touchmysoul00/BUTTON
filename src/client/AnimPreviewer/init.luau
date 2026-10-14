-- Animation picker (press P).
-- Tick the animations you want (click one to preview it, click again to
-- untick), then press Save. Each ticked animation is put on the right move
-- from its name/folder (Walk Back -> walking backward, etc.), applied to
-- your character, and kept after Stop.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer
local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimConfig"))
local AutoPick = require(ReplicatedStorage.Shared:WaitForChild("AutoPick"))

local LABELS = {
	Idle = "Standing still", Walk = "Walk forward", WalkBack = "Walk backward",
	WalkLeft = "Walk left", WalkRight = "Walk right", Run = "Run (Shift)",
	RunBack = "Run backward", RunLeft = "Run left", RunRight = "Run right",
	Jump = "Jump", Fall = "Falling", Land = "Landing", Climb = "Climbing",
	ClimbIdle = "Climb (still)", Swim = "Swimming", Crouch = "Crouch (C)",
	CrouchWalk = "Crouch walk", CrouchWalkBack = "Crouch walk back",
	CrouchWalkLeft = "Crouch walk left", CrouchWalkRight = "Crouch walk right",
	Slide = "Slide (C while running)",
}
for _, group in { { "Walk", "Walk" }, { "Run", "Run" }, { "CrouchWalk", "Crouch walk" } } do
	LABELS[group[1] .. "ForwardLeft"] = group[2] .. " W+A"
	LABELS[group[1] .. "ForwardRight"] = group[2] .. " W+D"
	LABELS[group[1] .. "BackLeft"] = group[2] .. " S+A"
	LABELS[group[1] .. "BackRight"] = group[2] .. " S+D"
end

-- if a ticked animation's name doesn't say what it is, its folder decides
local FOLDER_MOVES = {
	{ "idle", "Idle" }, { "walk", "Walk" }, { "run", "Run" }, { "swim", "Swim" },
	{ "slid", "Slide" }, { "climb", "Climb" }, { "crouch", "Crouch" },
	{ "jump", "Jump" }, { "fall", "Fall" }, { "land", "Land" },
}

-- Animations in the pack ----------------------------------------------------------
local anims = {} -- { name = "Walks/Walk Back", anim = Animation, rig = Model }
local byName = {}
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
			local entry = { name = table.concat(parts, "/"), anim = anim, rig = inst:FindFirstAncestorOfClass("Model") }
			table.insert(anims, entry)
			byName[entry.name] = entry
		end
	end
	table.sort(anims, function(a, b) return a.name:lower() < b.name:lower() end)
end

-- Saved choice ------------------------------------------------------------------------
local ticked = {} -- path -> true
local picks = {} -- move -> path
do
	local saved = ReplicatedStorage:WaitForChild("SavedAnimPicks", 10)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, saved and saved.Value or "{}")
	if ok and type(data) == "table" and type(data.Selected) == "table" then
		for _, path in data.Selected do
			if byName[path] then
				ticked[path] = true
			end
		end
		picks = type(data.Picks) == "table" and data.Picks or {}
	end
end

-- ticked animations -> moves
local function assign()
	local paths = {}
	for path in ticked do
		table.insert(paths, path)
	end
	table.sort(paths)
	local result = AutoPick(paths)
	local used = {}
	for _, path in result do
		used[path] = true
	end
	-- anything left over goes by folder into a move that's still empty
	for _, path in paths do
		if not used[path] then
			local lower = path:lower()
			for _, rule in FOLDER_MOVES do
				if lower:find(rule[1], 1, true) and not result[rule[2]] then
					result[rule[2]] = path
					used[path] = true
					break
				end
			end
		end
	end
	local unused = {}
	for _, path in paths do
		if not used[path] then
			table.insert(unused, path)
		end
	end
	return result, unused
end

-- UI --------------------------------------------------------------------------------------
local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local GREY, GREEN = Color3.fromRGB(50, 50, 60), Color3.fromRGB(40, 130, 70)

local function heading(text, x, width, parent)
	make("TextLabel", {
		Size = UDim2.fromOffset(width, 20),
		Position = UDim2.fromOffset(x, 56),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	}, parent)
end

local function scrolling(x, width, parent)
	local list = make("ScrollingFrame", {
		Size = UDim2.new(0, width, 1, -136),
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
	Size = UDim2.fromOffset(820, 500),
	Position = UDim2.new(0.5, -410, 0.5, -250),
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
	Text = "Click animations to tick them (✓). Then press Save.",
}, frame)

heading(("ANIMATIONS (%d) - click to tick"):format(#anims), 10, 300, frame)
local animList = scrolling(10, 300, frame)
heading("PREVIEW", 320, 220, frame)
heading("YOUR CHARACTER WILL USE", 550, 260, frame)
local resultList = scrolling(550, 260, frame)

local viewport = make("ViewportFrame", {
	Size = UDim2.new(0, 220, 1, -136),
	Position = UDim2.fromOffset(320, 78),
	BackgroundColor3 = Color3.fromRGB(55, 58, 70),
	Ambient = Color3.fromRGB(200, 200, 200),
	LightColor = Color3.new(1, 1, 1),
}, frame)
make("UICorner", {}, viewport)
local worldModel = make("WorldModel", {}, viewport)
local camera = make("Camera", { FieldOfView = 40 }, viewport)
viewport.CurrentCamera = camera

local saveButton = make("TextButton", {
	Size = UDim2.new(1, -20, 0, 44),
	Position = UDim2.new(0, 10, 1, -52),
	BackgroundColor3 = GREEN,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
}, frame)
make("UICorner", {}, saveButton)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.P then
		gui.Enabled = not gui.Enabled
	end
end)

-- Preview -------------------------------------------------------------------------------
local previewRig

local function preview(entry)
	if previewRig then
		previewRig:Destroy()
		previewRig = nil
	end
	if not entry.rig then
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
	end
	previewRig = clone
end

-- Result list -----------------------------------------------------------------------------
local function showResult(result, unused)
	for _, child in resultList:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local function line(text, color, order)
		make("TextLabel", {
			Size = UDim2.new(1, -8, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			LayoutOrder = order,
		}, resultList)
	end
	for i, move in config.Order do
		local path = result[move]
		line(("%s: %s"):format(LABELS[move] or move, path and path:match("[^/]+$") or "default"),
			path and Color3.new(1, 1, 1) or Color3.fromRGB(130, 130, 140), i)
	end
	for i, path in unused or {} do
		line("Not used (name unclear): " .. path:match("[^/]+$"), Color3.fromRGB(255, 150, 120), 100 + i)
	end
end

-- Animation list ----------------------------------------------------------------------------
local function countTicked()
	local n = 0
	for _ in ticked do
		n += 1
	end
	return n
end

local function refreshSaveButton()
	saveButton.Text = ("SAVE - use these %d animations on my character"):format(countTicked())
end

for i, entry in anims do
	local b = make("TextButton", {
		Size = UDim2.new(1, -8, 0, 30),
		BackgroundColor3 = ticked[entry.name] and GREEN or GREY,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = (ticked[entry.name] and "  ✓ " or "     ") .. entry.name,
		LayoutOrder = i,
	}, animList)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	b.MouseButton1Click:Connect(function()
		ticked[entry.name] = not ticked[entry.name] or nil
		b.BackgroundColor3 = ticked[entry.name] and GREEN or GREY
		b.Text = (ticked[entry.name] and "  ✓ " or "     ") .. entry.name
		preview(entry)
		refreshSaveButton()
		showResult(assign())
		status.Text = ("%s %s. Press Save when you're done."):format(ticked[entry.name] and "Ticked" or "Unticked", entry.name)
	end)
end

-- Saving ------------------------------------------------------------------------------------
local saveRemote = ReplicatedStorage:WaitForChild("SaveAnimPicks", 10)

saveButton.MouseButton1Click:Connect(function()
	local result = assign()
	picks = result
	-- put them on the character now ("" = this move uses the default)
	for _, move in config.Order do
		player:SetAttribute("Anim_" .. move, result[move] or "")
	end
	local selected = {}
	for path in ticked do
		table.insert(selected, path)
	end
	status.Text = "Saving..."
	local ok, success, err = false, false, "Save system not found"
	if saveRemote then
		ok, success, err = pcall(saveRemote.InvokeServer, saveRemote, { Picks = result, Selected = selected })
	end
	if ok and success then
		status.Text = "✓ Saved! Your character uses them now and after Stop. Press P and move around."
	else
		status.Text = "On your character now, but NOT kept after Stop: " .. tostring(err or success)
	end
end)

refreshSaveButton()
showResult(next(ticked) and assign() or picks)
if #anims == 0 then
	status.Text = "No animations found - is the Animations folder in the game?"
end

return {}
