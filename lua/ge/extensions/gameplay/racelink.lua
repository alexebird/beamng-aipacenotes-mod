-- extension name: gameplay_racelink
--
-- extensions.gameplay_racelink.initTracker()
-- getPlayerVehicle(0):queueLuaCommand("extensions.aipacenotes.sendVehicleReading()")
-- extensions.gameplay_racelink.pprint()

local Tracker = require('/lua/ge/extensions/gameplay/aipacenotes/racelink/tracker')

local logTag = 'racelink'

local M = {}

local tracker = nil

-- local function isFreeroam()
--   return core_gamestate.state and core_gamestate.state.state == "freeroam"
-- end

local function initTracker(vehId)
  if not vehId then
    vehId = be:getPlayerVehicleID(0)
  end
  tracker = Tracker(vehId)
end

-- local function clearRallyManager()
--   rallyManager = nil
-- end

local function receiveVehicleReading(readingJson)
  log('D', logTag, 'racelink receiveVehicleReading')
  local data = jsonDecode(readingJson)
  -- print(dumps(data))

  if tracker then
    tracker:putVehicleLuaReading(data)
  end
end

local function isReady()
  if tracker then
    return true
  end
  return false
end

local function pprint()
  if not tracker then
    log('W', logTag, 'pprint: no tracker found')
    return
  end

  print(dumps(tracker:getAllData()))
end

-- API
M.initTracker = initTracker
M.getTracker = function() return tracker end
M.isReady = isReady
M.pprint = pprint

M.receiveVehicleReading = receiveVehicleReading

return M
