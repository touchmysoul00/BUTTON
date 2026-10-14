-- Replaces Roblox's default R6 Animate script with the animations picked in
-- ReplicatedStorage.Shared.AnimConfig.
-- Controls: Shift = sprint, C / Left Ctrl = crouch, C while sprinting = slide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local WALK_SPEED = 16
local RUN_SPEED = 26
local CROUCH_SPEED = 8
local SLIDE_TIME = 0.8

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

local function loadSlot(slot)
	local value = config[slot]
	if not value then
		return nil
	end
	local anim
	if value:match("^rbxassetid://") then
		anim = Instance.new("Animation")
		anim.AnimationId = value
	else
		local inst = findInPack(value)
		if not inst then
			warn(("[Animate] %s: no animation matches %q"):format(slot, value))
			return nil
		end
		if inst:IsA("Animation") then
			anim = inst
		else
			-- raw KeyframeSequence: temporary ID, only works in Studio playtests
			local ok, id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, inst)
			if not ok then
				warn("[Animate] Couldn't register", slot, id)
				return nil
			end
			anim = Instance.new("Animation")
			anim.AnimationId = id
		end
	end
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if not ok then
		warn("[Animate] Couldn't load", slot, track)
		return nil
	end
	return track
end

local LOOPED = { Idle = true, Walk = true, Run = true, Fall = true, Climb = true, ClimbIdle = true,
	Swim = true, Crouch = true, CrouchWalk = true, Slide = true }
local PRIORITY = { Jump = Enum.AnimationPriority.Action, Land = Enum.AnimationPriority.Action,
	Slide = Enum.AnimationPriority.Movement }

local tracks = {}
for slot in config do
	local track = loadSlot(slot)
	if track then
		track.Looped = LOOPED[slot] == true
		track.Priority = PRIORITY[slot] or Enum.AnimationPriority.Core
		tracks[slot] = track
	end
end

-- Playing -------------------------------------------------------------------
local currentSlot

-- one looping "base" animation at a time (idle, walk, run, fall, ...)
local function setBase(slot, speed)
	if not tracks[slot] then
		return
	end
	if currentSlot ~= slot then
		if currentSlot and tracks[currentSlot] then
			tracks[currentSlot]:Stop(0.15)
		end
		currentSlot = slot
		tracks[slot]:Play(0.15)
	end
	tracks[slot]:AdjustSpeed(speed or 1)
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

RunService.Heartbeat:Connect(function()
	local state = humanoid:GetState()
	local horizontal = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local sliding = os.clock() < slideUntil

	humanoid.WalkSpeed = (sliding or crouching) and CROUCH_SPEED or (sprinting and RUN_SPEED or WALK_SPEED)

	if state == Enum.HumanoidStateType.Climbing then
		local climbSpeed = math.abs(root.AssemblyLinearVelocity.Y)
		if climbSpeed < 0.5 and tracks.ClimbIdle then
			setBase("ClimbIdle")
		else
			setBase("Climb", math.max(climbSpeed / 8, 0.1))
		end
	elseif state == Enum.HumanoidStateType.Swimming then
		setBase(tracks.Swim and "Swim" or "Idle")
	elseif state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		setBase("Fall")
	elseif sliding and tracks.Slide then
		setBase("Slide")
	elseif crouching and tracks.Crouch then
		setBase((horizontal > 0.5 and tracks.CrouchWalk) and "CrouchWalk" or "Crouch")
	elseif horizontal > 0.5 then
		if sprinting and tracks.Run then
			setBase("Run")
		else
			setBase(tracks.Walk and "Walk" or "Run", horizontal / WALK_SPEED)
		end
	else
		setBase("Idle")
	end
end)
