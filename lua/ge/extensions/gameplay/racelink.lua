-- extension name: gameplay_racelink

local Tracker = require('/lua/ge/extensions/gameplay/aipacenotes/racelink/tracker')

local logTag = 'racelink'

local M = {}

local tracker = nil

-- local function isFreeroam()
--   return core_gamestate.state and core_gamestate.state.state == "freeroam"
-- end

local function initTracker(vehId, missionId)
  tracker = Tracker(vehId)
end

-- local function clearRallyManager()
--   rallyManager = nil
-- end

local function isReady()
  if tracker then
    return true
  end
  return false
end

-- API
M.initTracker = initTracker
M.getTracker = function() return tracker end
M.isReady = isReady

return M
