-- extension name: gameplay_rally_ui_recce

local M = {}

local function loadCornerAnglesFile()
  local filename = '/settings/aipacenotes/cornerAngles.json'
  local json = jsonReadFile(filename)
  if not json then
    local err = 'unable to find cornerAngles file: ' .. tostring(filename)
    log('E', 'aipacenotes', err)
    guihooks.trigger('aiPacenotesCornerAnglesLoaded', nil, err)
  end
  guihooks.trigger('aiPacenotesCornerAnglesLoaded', json, nil)
end

-- local function onFirstUpdate()
  -- loadCornerAnglesFile()
-- end

local function onUpdate(dtReal, dtSim, dtRaw)
  local veh = be:getPlayerVehicle(0)
  if not veh then
    guihooks.trigger('aiPacenotesRecce', -1, "no vehicle")
    return
  end

  local vehPos = veh:getPosition()
  -- log('D', 'wtf', 'onUpdate vehPos='..dumps(vehPos))
end

-- -- public interface
M.loadCornerAnglesFile = loadCornerAnglesFile
M.onUpdate = onUpdate
-- M.onFirstUpdate = onFirstUpdate

return M


-- local M = {}
--
-- local sphereColor = ColorF(1, 0, 0, 1)
-- local textColor = ColorF(1, 1, 1, 0.9)
-- local textBackgroundColor = ColorI(0, 0, 0, 128)
--
-- local function onUpdate(dtReal, dtSim, dtRaw)
--   -- TODO: convert into stream
--   local veh = be:getPlayerVehicle(0)
--   if not veh then
--     guihooks.trigger('aiPacenotesRecce', -1, "no vehicle")
--     return
--   end
--
--   local vehPos = veh:getPosition()
--   local camPos = core_camera.getPosition()
--
--   debugDrawer:drawSphere(vehPos, 0.5, sphereColor)
--   debugDrawer:drawTextAdvanced(vehPos, "camera distance target", textColor, true, false, textBackgroundColor)
--
--   local distance = vehPos:distance(camPos)
--
--   guihooks.trigger('aiPacenotesRecce', distance)
-- end
--
-- -- public interface
-- M.onUpdate = onUpdate
--
-- return M
