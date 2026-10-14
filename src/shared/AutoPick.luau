-- Picks an animation for each slot from the pack by looking at the names,
-- e.g. "Walks/Walk Back" -> WalkBack, "Crouch/Prone/Crouch_Walk_Left" -> CrouchWalkLeft.
-- Takes a list of pack paths and returns { [slot] = path }.

-- split "Walks/Walk_Back Left" into lowercase words
local function words(path)
	local list = {}
	local spaced = path:gsub("(%l)(%u)", "%1 %2")
	for word in spaced:lower():gmatch("%a+") do
		list[word] = true
	end
	return list
end

local function hasAny(w, list)
	for _, word in list do
		if w[word] then
			return true
		end
	end
	return false
end

-- which way an animation moves: "", "Back", "Left", "Right", "ForwardLeft",
-- "ForwardRight", "BackLeft", "BackRight" (nil if it makes no sense)
local function direction(w)
	local back = w.back or w.backward or w.backwards
	local left, right = w.left, w.right
	local forward = w.forward or w.forwards or w.front
	if (back and forward) or (left and right) then
		return nil
	end
	local vertical = back and "Back" or (forward and "Forward" or "")
	local side = left and "Left" or (right and "Right" or "")
	if vertical == "Forward" and side == "" then
		return ""
	end
	return vertical .. side
end

-- transitions like "Crouch_Walk_Start" or "Idle to Climb" aren't loops
local TRANSITION = { "start", "stop", "end", "to", "transition", "enter", "exit" }

local RULES = {
	Idle = { has = { "idle", "idles" }, never = { "crouch", "prone", "climb", "climbing", "swim", "swimming", "wall" } },
	Jump = { has = { "jump" } },
	Fall = { has = { "fall", "falling" }, never = { "land", "landing" } },
	Land = { has = { "land", "landing" } },
	Climb = { has = { "climb" }, never = { "idle", "back" } },
	ClimbIdle = { has = { "climb" }, also = { "idle" } },
	Swim = { has = { "swim", "swimming" }, never = { "idle" } },
	Crouch = { has = { "crouch" }, also = { "idle" } },
	Slide = { has = { "slide", "sliding" } },
}
for _, group in { "Walk", "Run", "CrouchWalk" } do
	for _, dir in { "", "Back", "Left", "Right", "ForwardLeft", "ForwardRight", "BackLeft", "BackRight" } do
		RULES[group .. dir] = { group = group, dir = dir }
	end
end

local function matches(slot, rule, w)
	if rule.group then
		if direction(w) ~= rule.dir or hasAny(w, TRANSITION) then
			return false
		end
		if rule.group == "CrouchWalk" then
			return w.crouch and (w.walk or w.walking or w.move) and true or false
		end
		local word = rule.group:lower()
		return (w[word] or w[word .. "s"] or w[word .. "ning"] or w[word .. "ing"])
			and not w.crouch and not w.prone and not w.wall and not w.wallrun and true or false
	end
	if not hasAny(w, rule.has) then
		return false
	end
	if rule.also and not hasAny(w, rule.also) then
		return false
	end
	if rule.never and hasAny(w, rule.never) then
		return false
	end
	if slot ~= "Jump" and slot ~= "Land" and hasAny(w, TRANSITION) then
		return false
	end
	return true
end

-- Looks at the animation's own name first ("Walk Back"); only if nothing
-- fits does it also use the folder names ("Walks/..."), because some folders
-- mix several kinds, like "Falls/Jumps/Landing".
return function(paths)
	local picks = {}
	for slot, rule in RULES do
		for _, useFolders in { false, true } do
			local best
			for _, path in paths do
				local name = path:match("[^/]+$")
				if matches(slot, rule, words(useFolders and path or name)) then
					-- prefer the plainest name ("Walk" over "Walk2 Tired")
					local bestName = best and best:match("[^/]+$")
					if not best or #name < #bestName or (#name == #bestName and path < best) then
						best = path
					end
				end
			end
			if best then
				picks[slot] = best
				break
			end
		end
	end
	return picks
end
