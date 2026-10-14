-- Which animation from the Animations pack plays for each movement.
-- Use the names shown in the previewer, e.g. "Walks/Walk Back".
-- A "*" matches anything, so "Idles/*" means "the first animation in Idles".
-- Once animations are uploaded to Roblox, an ID like "rbxassetid://123" works too.
-- Missing direction slots fall back to the closest one that exists.
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
		"WalkForwardLeft", "WalkForwardRight", "WalkBackLeft", "WalkBackRight",
		"Run", "RunBack", "RunLeft", "RunRight",
		"RunForwardLeft", "RunForwardRight", "RunBackLeft", "RunBackRight",
		"Jump", "Fall", "Land",
		"Climb", "ClimbIdle", "Swim",
		"Crouch", "CrouchWalk", "CrouchWalkBack", "CrouchWalkLeft", "CrouchWalkRight",
		"CrouchWalkForwardLeft", "CrouchWalkForwardRight", "CrouchWalkBackLeft", "CrouchWalkBackRight",
		"Slide",
	},
}
