-- Which animation from the Animations pack plays for each movement.
-- Use the names shown in the previewer, e.g. "Runs/Sprint".
-- A "*" matches anything, so "Idles/*" means "the first animation in Idles".
-- Once animations are uploaded to Roblox, an ID like "rbxassetid://123" works too.
-- Set a slot to nil to leave it out.
return {
	Idle = "Idles/*",
	Walk = "Walks/*",
	Run = "Runs/*",
	Jump = "Falls/Jumps/Landing/*jump*",
	Fall = "Falls/Jumps/Landing/*fall*",
	Land = "Falls/Jumps/Landing/*land*",
	Climb = "Climbing/Climb",
	ClimbIdle = "Climbing/Climb Idle",
	Swim = "Swimming/*",
	Crouch = "Crouch/Prone/Crouch_Idle",
	CrouchWalk = "Crouch/Prone/Crouch_Walk",
	Slide = "Sliding/*",
}
