-- Which animation from the Animations pack plays for each movement.
-- Use the names shown in the previewer, e.g. "Walks/Walk Back".
-- A "*" matches anything, so "Idles/*" means "the first animation in Idles".
-- Once animations are uploaded to Roblox, an ID like "rbxassetid://123" works too.
-- Leave a slot out (or nil) to skip it. Missing Back/Left/Right slots fall
-- back to the forward one.
-- Picks made in the previewer (P) override these while playtesting.
return {
	-- true: character faces the camera, so back/left/right animations play
	Strafe = true,

	Slots = {
		Idle = "Idles/*",

		Walk = "Walks/*",
		WalkBack = nil,
		WalkLeft = nil,
		WalkRight = nil,

		Run = "Runs/*",
		RunBack = nil,
		RunLeft = nil,
		RunRight = nil,

		Jump = "Falls/Jumps/Landing/*jump*",
		Fall = "Falls/Jumps/Landing/*fall*",
		Land = "Falls/Jumps/Landing/*land*",

		Climb = "Climbing/Climb",
		ClimbIdle = "Climbing/Climb Idle",
		Swim = "Swimming/*",

		Crouch = "Crouch/Prone/Crouch_Idle",
		CrouchWalk = "Crouch/Prone/Crouch_Walk",
		CrouchWalkBack = nil,
		CrouchWalkLeft = nil,
		CrouchWalkRight = nil,

		Slide = "Sliding/*",
	},

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
