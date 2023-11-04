local M = {}

local wpTypeFwdAudioTrigger = "fwdAudioTrigger"
local wpTypeRevAudioTrigger = "revAudioTrigger"
local wpTypeCornerStart = "cornerStart"
local wpTypeCornerEnd = "cornerEnd"
local wpTypeDistanceMarker = "distanceMarker"

local shortener_map = {
  [wpTypeFwdAudioTrigger] = "Af",
  [wpTypeRevAudioTrigger] = "Ar",
  [wpTypeCornerStart] = "CS",
  [wpTypeCornerEnd] = "CE",
  [wpTypeDistanceMarker] = "D",
}

local function shortenWaypointType(wpType)
  return shortener_map[wpType]
end

M.wpTypeFwdAudioTrigger = wpTypeFwdAudioTrigger
M.wpTypeRevAudioTrigger = wpTypeRevAudioTrigger
M.wpTypeCornerStart = wpTypeCornerStart
M.wpTypeCornerEnd = wpTypeCornerEnd
M.wpTypeDistanceMarker = wpTypeDistanceMarker

M.shortenWaypointType = shortenWaypointType

return M