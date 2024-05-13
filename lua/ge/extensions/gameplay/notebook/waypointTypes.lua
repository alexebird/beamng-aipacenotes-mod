local M = {}

local wpTypeFwdAudioTrigger = "fwdAudioTrigger"
local wpTypeRevAudioTrigger = "revAudioTrigger"
local wpTypeCornerStart = "cornerStart"
local wpTypeCornerEnd = "cornerEnd"
local wpTypeDistanceMarker = "distanceMarker"

local shortener_map = {
  [wpTypeFwdAudioTrigger] = "At",
  [wpTypeRevAudioTrigger] = "Ar",
  [wpTypeCornerStart] = "Cs",
  [wpTypeCornerEnd] = "Ce",
  [wpTypeDistanceMarker] = "Di",
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
