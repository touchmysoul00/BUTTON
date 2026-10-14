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
local DIRECTIONS = { "", "Back", "Left", "Right" }

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

local ONE_SHOT = { Jump = true, Land = true }
local PRIORITY = { Jump = Enum.AnimationPriority.Action, Land = Enum.AnimationPriority.Action,
	Slide = Enum.AnimationPriority.Movement }

local tracks = {}

-- previewer picks (player attributes "Anim_<slot>") win over the config file
local function slotValue(slot)
	return player:GetAttribute("Anim_" .. slot) or config.Slots[slot]
end

local function loadSlot(slot)
	if tracks[slot] then
		tracks[slot]:Stop(0)
		tracks[slot] = nil
	end
	local value = slotValue(slot)
	if not value or value == "" then
		return
	end
	local anim, err = toAnimation(value)
	if not anim then
		warn(("[Animate] %s: %s"):format(slot, err))
		return
	end
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if not ok then
		warn("[Animate] Couldn't load", slot, track)
		return
	end
	track.Looped = not ONE_SHOT[slot]
	track.Priority = PRIORITY[slot] or Enum.AnimationPriority.Core
	tracks[slot] = track
end

local currentGroup

for _, slot in config.Order do
	loadSlot(slot)
end
player.AttributeChanged:Connect(function(attribute)
	local slot = attribute:match("^Anim_(.+)$")
	if slot then
		loadSlot(slot)
		currentGroup = nil -- restart whatever is playing with the new track
	end
end)

-- Playing -------------------------------------------------------------------
-- A "group" is a looping movement (Walk, Run, Idle, ...). Walk/Run/CrouchWalk
-- also have Back/Left/Right slots, blended by which way you're moving.
local function groupTracks(group)
	local list = {}
	for _, dir in DIRECTIONS do
		local track = tracks[group .. dir]
		if track then
			list[dir] = track
		end
	end
	return list
end

local function directionWeights(group)
	local list = groupTracks(group)
	local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local weights = { [""] = 1, Back = 0, Left = 0, Right = 0 }
	if velocity.Magnitude > 0.5 and (list.Back or list.Left or list.Right) then
		local localDir = root.CFrame:VectorToObjectSpace(velocity.Unit)
		weights = {
			[""] = math.max(0, -localDir.Z),
			Back = math.max(0, localDir.Z),
			Left = math.max(0, -localDir.X),
			Right = math.max(0, localDir.X),
		}
		-- directions without their own animation use the forward one
		for _, dir in { "Back", "Left", "Right" } do
			if not list[dir] then
				weights[""] += weights[dir]
				weights[dir] = 0
			end
		end
	end
	return list, weights
end

local function stopGroup(group)
	for _, track in groupTracks(group) do
		track:Stop(0.15)
	end
end

local function setGroup(group, speed)
	local list, weights = directionWeights(group)
	if not next(list) then
		return
	end
	if currentGroup ~= group then
		if currentGroup then
			stopGroup(currentGroup)
		end
		currentGroup = group
		for _, track in list do
			track:Play(0.15, 0.001)
		end
	end
	for dir, track in list do
		track:AdjustWeight(math.max(weights[dir] or 0, 0.001), 0.15)
		track:AdjustSpeed(speed or 1)
	end
end

local function playOnce(slot)
	if tracks[slot] then
		tracks[slot]:Play(0.05)
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

humanoid.StateChanged:Connect(function(_, new)
	if new == Enum.HumanoidStateType.Jumping then
		playOnce("Jump")
	elseif new == Enum.HumanoidStateType.Landed then
		playOnce("Land")
	end
end)

if config.Strafe then
	humanoid.AutoRotate = false
end

RunService.Heartbeat:Connect(function()
	local state = humanoid:GetState()
	local horizontal = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local sliding = os.clock() < slideUntil
	local climbing = state == Enum.HumanoidStateType.Climbing
	local swimming = state == Enum.HumanoidStateType.Swimming

	humanoid.WalkSpeed = (sliding or crouching) and CROUCH_SPEED or (sprinting and RUN_SPEED or WALK_SPEED)

	-- strafe: keep facing where the camera looks
	if config.Strafe and not climbing and not swimming and not sliding then
		local look = workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
		end
	end

	if climbing then
		local climbSpeed = math.abs(root.AssemblyLinearVelocity.Y)
		if climbSpeed < 0.5 and tracks.ClimbIdle then
			setGroup("ClimbIdle")
		else
			setGroup("Climb", math.max(climbSpeed / 8, 0.1))
		end
	elseif swimming then
		setGroup(tracks.Swim and "Swim" or "Idle")
	elseif state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		setGroup("Fall")
	elseif sliding and tracks.Slide then
		setGroup("Slide")
	elseif crouching and tracks.Crouch then
		setGroup((horizontal > 0.5 and tracks.CrouchWalk) and "CrouchWalk" or "Crouch", horizontal > 0.5 and horizontal / CROUCH_SPEED or 1)
	elseif horizontal > 0.5 then
		if sprinting and tracks.Run then
			setGroup("Run")
		else
			setGroup(tracks.Walk and "Walk" or "Run", horizontal / WALK_SPEED)
		end
	else
		setGroup("Idle")
	end
end)
