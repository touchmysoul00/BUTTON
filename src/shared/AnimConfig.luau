-- Which animation from the Animations pack plays for each movement.
-- Use the names shown in the previewer, e.g. "Walks/Walk Back".
-- A "*" matches anything, so "Idles/*" means "the first animation in Idles".
-- Once animations are uploaded to Roblox, an ID like "rbxassetid://123" works too.
-- Missing Back/Left/Right slots fall back to the forward one.
-- Picks made in the previewer (P) override these while playtesting.
return {
	-- true: character faces the camera, so back/left/right animations play
	Strafe = true,

	-- Every slot is filled automatically from the animation names (see
	-- AutoPick). Put a slot here only to force a specific animation, e.g.
	--   Run = "Runs/Sprint",
	Slots = {},

	-- order the slots appear in the previewer
	Order = {
		"Idle",
		"Walk", "WalkBack", "WalkLeft", "WalkRight",
		"Run", "RunBack", "RunLeft", "RunRight",
		"Jump", "Fall", "Land",
		"Climb", "ClimbIdle", "Swim",
		"Crouch", "CrouchWalk", "CrouchWalkBack", "CrouchWalkLeft", "CrouchWalkRight",
		"Slide",
	},
}
