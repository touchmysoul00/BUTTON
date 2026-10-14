-- Replaces Roblox's default R6 Animate script with the animations picked in
-- ReplicatedStorage.Shared.AnimConfig (or live in the previewer).
-- Controls: Shift = sprint, C / Left Ctrl = crouch, C while sprinting = slide.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local WALK_SPEED = 16
local RUN_SPEED = 26
local CROUCH_SPEED = 8
local SLIDE_TIME = 0.8

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimConfig"))
local pack = ReplicatedStorage:WaitForChild("PreviewAnimations", 10)

-- Finding animations --------------------------------------------------------
-- path inside the pack (e.g. "Runs/Sprint") -> KeyframeSequence/Animation
local byPath = {}
if pack then
	for _, inst in pack:GetDescendants() do
		if inst:IsA("KeyframeSequence") or (inst:IsA("Animation") and inst.AnimationId ~= "") then
			local parts, node = {}, inst
			while node and node ~= pack do
				if node.Name ~= "AnimSaves" then
					table.insert(parts, 1, node.Name)
				end
				node = node.Parent
			end
			byPath[table.concat(parts, "/")] = inst
		end
	end
else
	warn("[Animate] Animations pack not found - using no custom animations")
end

-- picks saved from the previewer
local savedPicks = {}
do
	local saved = ReplicatedStorage:WaitForChild("SavedAnimPicks", 10)
	local ok, data = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), saved and saved.Value or "{}")
	if ok and type(data) == "table" and type(data.Picks) == "table" then
		savedPicks = data.Picks
	end
end

-- slots not set in the config are filled from the animation names
local autoPicks = {}
do
	local paths = {}
	for path in byPath do
		table.insert(paths, path)
	end
	table.sort(paths)
	autoPicks = require(ReplicatedStorage.Shared:WaitForChild("AutoPick"))(paths)
	local lines = { "[Animate] Animations on your character:" }
	for _, slot in config.Order do
		local value = savedPicks[slot] or config.Slots[slot] or autoPicks[slot]
		table.insert(lines, ("  %s = %s"):format(slot, value or "(none - uses the forward/default one)"))
	end
	print(table.concat(lines, "\n"))
end

local function findInPack(value)
	if byPath[value] then
		return byPath[value]
	end
	if not value:find("*", 1, true) then
		return nil
	end
	-- "Idles/*" style: turn into a case-insensitive pattern, pick the first match
	local pattern = "^" .. value:lower():gsub("[%(%)%.%%%+%-%?%[%]%^%$]", "%%%0"):gsub("%*", ".*") .. "$"
	local matches = {}
	for path in byPath do
		if path:lower():match(pattern) then
			table.insert(matches, path)
		end
	end
	table.sort(matches)
	return matches[1] and byPath[matches[1]]
end

local registered = {} -- KeyframeSequence -> temporary ID

local function toAnimation(value)
	local anim = Instance.new("Animation")
	if value:match("^rbxassetid://") then
		anim.AnimationId = value
		return anim
	end
	local inst = findInPack(value)
	if not inst then
		return nil, ("no animation matches %q"):format(value)
	end
	if inst:IsA("Animation") then
		return inst
	end
	-- raw KeyframeSequence: temporary ID, only works in Studio playtests
	if not registered[inst] then
		local ok, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, inst)
		if not ok then
			return nil, id
		end
		registered[inst] = id
	end
	anim.AnimationId = registered[inst]
	return anim
end

-- Roblox's standard R6 animations, used when a move has no working pick so
-- the character never just slides around
local ROBLOX_DEFAULTS = {
	Idle = "rbxassetid://180435571",
	Walk = "rbxassetid://180426354",
	Run = "rbxassetid://180426354",
	Jump = "rbxassetid://125750702",
	Fall = "rbxassetid://180436148",
	Climb = "rbxassetid://180436334",
	Swim = "rbxassetid://180426354",
}

local ONE_SHOT = { Jump = true, Land = true }
local PRIORITY = { Jump = Enum.AnimationPriority.Action, Land = Enum.AnimationPriority.Action,
	Slide = Enum.AnimationPriority.Movement }

local tracks = {}
local problems = {} -- slot -> why it didn't load

-- live previewer picks (player attributes "Anim_<slot>") win, then saved
-- picks, then the config file, then the automatic picks
local function slotValue(slot)
	local live = player:GetAttribute("Anim_" .. slot)
	if live == "" then
		return config.Slots[slot] or autoPicks[slot]
	end
	return live or savedPicks[slot] or config.Slots[slot] or autoPicks[slot]
end

local function loadTrack(slot, value)
	local anim, err = toAnimation(value)
	if not anim then
		return nil, err
	end
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if not ok then
		return nil, track
	end
	track.Looped = not ONE_SHOT[slot]
	track.Priority = PRIORITY[slot] or Enum.AnimationPriority.Core
	return track
end

local function loadSlot(slot)
	if tracks[slot] then
		tracks[slot]:Stop(0)
		tracks[slot] = nil
	end
	problems[slot] = nil
	local value = slotValue(slot)
	if value and value ~= "" then
		local track, err = loadTrack(slot, value)
		if track then
			tracks[slot] = track
			return
		end
		warn(("[Animate] %s: %s"):format(slot, tostring(err)))
		problems[slot] = tostring(err)
	end
	if ROBLOX_DEFAULTS[slot] then
		tracks[slot] = loadTrack(slot, ROBLOX_DEFAULTS[slot])
	end
end

local currentGroup
local stopGroup -- defined below (stops the looping track)

-- On-screen status (Studio only) so problems show without opening Output
local statusLabel
if RunService:IsStudio() then
	local gui = Instance.new("ScreenGui")
	gui.Name = "AnimateStatus"
	gui.ResetOnSpawn = true
	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 22)
	statusLabel.Position = UDim2.new(0, 0, 1, -22)
	statusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	statusLabel.BackgroundTransparency = 0.4
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

local lastError -- set by the main loop if it crashes

local function updateStatus()
	if not statusLabel then
		return
	end
	local loaded, broken = 0, {}
	for _, slot in config.Order do
		if tracks[slot] then
			loaded += 1
		elseif problems[slot] then
			table.insert(broken, slot .. ": " .. problems[slot])
		end
	end
	local text = ("Body: %s  |  %d animations on your character  |  playing: %s"):format(
		humanoid.RigType.Name, loaded, currentGroup or "-")
	if lastError then
		text ..= "  |  ERROR " .. tostring(lastError)
	elseif not pack then
		text ..= "  |  Animations folder NOT found"
	elseif #broken > 0 then
		text ..= "  |  PROBLEM " .. broken[1]
	end
	statusLabel.Text = text
end

for _, slot in config.Order do
	loadSlot(slot)
end
player.AttributeChanged:Connect(function(attribute)
	local slot = attribute:match("^Anim_(.+)$")
	if slot then
		loadSlot(slot)
		-- restart whatever is playing so the new track is used
		stopGroup()
		currentGroup = nil
	end
end)

-- Playing -------------------------------------------------------------------
-- Exactly one looping track plays at a time (blending two walk cycles makes
-- the legs scissor). Walk/Run/CrouchWalk pick the Back/Left/Right version
-- for the direction you're mostly moving in.
local currentTrack
local currentDir = ""

-- direction you're moving relative to where the character faces, with a
-- little stickiness so it doesn't flicker around 45 degrees
local function moveDirection()
	local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	if velocity.Magnitude < 0.5 then
		return currentDir
	end
	local d = root.CFrame:VectorToObjectSpace(velocity.Unit)
	local scores = { [""] = -d.Z, Back = d.Z, Left = -d.X, Right = d.X }
	local best, bestScore = currentDir, (scores[currentDir] or 0) + 0.15
	for dir, score in scores do
		if score > bestScore then
			best, bestScore = dir, score
		end
	end
	currentDir = best
	return best
end

-- the track for a movement; returns track, speed sign (-1 = play reversed)
local function pickTrack(group)
	if group ~= "Walk" and group ~= "Run" and group ~= "CrouchWalk" then
		return tracks[group], 1
	end
	local dir = moveDirection()
	if tracks[group .. dir] then
		return tracks[group .. dir], 1
	end
	-- running without its own direction animation: use the walking one
	if group == "Run" and tracks["Walk" .. dir] and dir ~= "" then
		return tracks["Walk" .. dir], 1
	end
	-- backward without an animation: the forward one played in reverse
	if dir == "Back" then
		return tracks[group], -1
	end
	return tracks[group], 1
end

function stopGroup()
	if currentTrack then
		currentTrack:Stop(0.2)
		currentTrack = nil
	end
end

local function setGroup(group, speed)
	local track, sign = pickTrack(group)
	if not track then
		return
	end
	if track ~= currentTrack then
		stopGroup()
		track:Play(0.2)
		currentTrack = track
	end
	currentGroup = group
	track:AdjustSpeed((speed or 1) * sign)
end

local function playOnce(slot)
	if tracks[slot] then
		tracks[slot]:Play(0.1)
	end
end

local function stopOnce(slot)
	if tracks[slot] and tracks[slot].IsPlaying then
		tracks[slot]:Stop(0.15)
	end
end

-- Controls ------------------------------------------------------------------
local sprinting, crouching, slideUntil = false, false, 0

local function isCrouchKey(key)
	return key == Enum.KeyCode.C or key == Enum.KeyCode.LeftControl
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = true
	elseif isCrouchKey(input.KeyCode) then
		local moving = humanoid.MoveDirection.Magnitude > 0
		if sprinting and moving and humanoid.FloorMaterial ~= Enum.Material.Air and tracks.Slide then
			slideUntil = os.clock() + SLIDE_TIME
			root.AssemblyLinearVelocity += humanoid.MoveDirection * 20
		end
		crouching = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		sprinting = false
	elseif isCrouchKey(input.KeyCode) then
		crouching = false
	end
end)

local airSince -- when we left the ground

humanoid.StateChanged:Connect(function(_, new)
	if new == Enum.HumanoidStateType.Jumping then
		playOnce("Jump")
	elseif new == Enum.HumanoidStateType.Landed then
		stopOnce("Jump")
		-- only a real fall, and not while running off (it would freeze the legs)
		local airTime = airSince and os.clock() - airSince or 0
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		if airTime > 0.5 and not moving then
			playOnce("Land")
		end
	end
end)

if config.Strafe then
	humanoid.AutoRotate = false
	-- face where the camera looks, right after the camera updates each frame
	RunService:BindToRenderStep("AnimateStrafe", Enum.RenderPriority.Camera.Value + 1, function()
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming
			or state == Enum.HumanoidStateType.Dead or humanoid.Sit then
			return
		end
		local look = workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
		end
	end)
	local function unbind()
		RunService:UnbindFromRenderStep("AnimateStrafe")
	end
	humanoid.Died:Connect(unbind)
	script.Destroying:Connect(unbind)
end

local function step()
	local state = humanoid:GetState()
	local horizontal = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local sliding = os.clock() < slideUntil
	local climbing = state == Enum.HumanoidStateType.Climbing
	local swimming = state == Enum.HumanoidStateType.Swimming

	-- no sprinting backwards unless there's a run-backward animation
	local canSprint = sprinting and (currentDir ~= "Back" or tracks.RunBack ~= nil)
	humanoid.WalkSpeed = (sliding or crouching) and CROUCH_SPEED or (canSprint and RUN_SPEED or WALK_SPEED)

	local inAir = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
	if inAir then
		airSince = airSince or os.clock()
	else
		airSince = nil
	end
	-- ignore tiny drops (stairs, bumps) so the legs don't flicker into falling
	local falling = inAir and (state == Enum.HumanoidStateType.Jumping or os.clock() - airSince > 0.25)

	if climbing then
		local climbSpeed = math.abs(root.AssemblyLinearVelocity.Y)
		if climbSpeed < 0.5 and tracks.ClimbIdle then
			setGroup("ClimbIdle")
		else
			setGroup("Climb", math.max(climbSpeed / 8, 0.1))
		end
	elseif swimming then
		setGroup(tracks.Swim and "Swim" or "Idle")
	elseif falling then
		setGroup(tracks.Fall and "Fall" or "Idle")
	elseif sliding and tracks.Slide then
		setGroup("Slide")
	elseif crouching and tracks.Crouch then
		setGroup((horizontal > 0.5 and tracks.CrouchWalk) and "CrouchWalk" or "Crouch", horizontal > 0.5 and horizontal / CROUCH_SPEED or 1)
	elseif horizontal > 0.5 then
		if canSprint and tracks.Run then
			setGroup("Run", horizontal / RUN_SPEED)
		else
			setGroup(tracks.Walk and "Walk" or "Run", horizontal / WALK_SPEED)
		end
	else
		setGroup("Idle")
	end
end

RunService.Heartbeat:Connect(function()
	local ok, err = pcall(step)
	if not ok and err ~= lastError then
		lastError = err
		warn("[Animate] ERROR:", err)
	end
	updateStatus()
end)
