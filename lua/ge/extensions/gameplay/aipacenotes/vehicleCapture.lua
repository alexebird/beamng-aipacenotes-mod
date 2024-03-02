local logTag = 'aipacenotes'
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

local steeringKey = 'steering'

function C:init(vehicle, missionDir) --, cornerAngles, selectedCornerAnglesName)
  log('I', logTag, 'initializing vehicleCapture for vehicle='..vehicle:getId())
  self.vehicle = vehicle
  core_vehicleBridge.registerValueChangeNotification(self.vehicle, steeringKey)
  self.interval_m = 2
  self.last_dist_pos = nil
  self.capturesBuffer = {}
  self.fname = re_util.missionTranscripts2Path(missionDir, 'primary', 'driveline.json', false)
  log('I', logTag, 'vehicleCapture init fname='..self.fname)
end

function C:truncateCapturesFile()
  self.f = io.open(self.fname, "w")
  self.f:close()
end

function C:writeCaptures(force)
  if not force and #self.capturesBuffer < 10 then
    return
  end

  log('I', logTag, 'vehicleCapture writing '..tostring(#self.capturesBuffer)..' captures')
  self.f = io.open(self.fname, "a")
  for _,cap in ipairs(self.capturesBuffer) do
    local content = jsonEncode(cap)
    self.f:write(content.."\n")
  end
  self.f:close()
  self.capturesBuffer = {}
end

-- function C:getCornerCall(steering)
--   if not self.style then return nil end
--   local angle_data, cornerCallStr, pct = re_util.determineCornerCall(self.style.angles, steering)
--   return cornerCallStr
-- end

-- function C:reset()
  -- self.captures.clear()
  -- self.captures = {}
-- end

-- function C:asJson()
--   return {
--     cornerAnglesStyle = self.selectedCornerAnglesName,
--     -- captures = self.captures.getTable(),
--     captures = deepcopy(self.captures),
--   }
-- end

function C:capture()
  -- pos appears to be centered over the top center of the windshield.
  local vehPos = self.vehicle:getPosition()
  local vehRot = quatFromDir(self.vehicle:getDirectionVector(), self.vehicle:getDirectionVectorUp())
  local now = re_util.getTime()

  local vInfo = {
    ts = now,
    pos = { x = vehPos.x, y = vehPos.y, z = vehPos.z },
    quat = {x = vehRot.x, y = vehRot.y, z = vehRot.z, w = vehRot.w},
    steering = nil,
  }

  if self.last_dist_pos then
    local dist = self.last_dist_pos:distance(vehPos)
    if dist > self.interval_m then
      self.last_dist_pos = vehPos

      local steering = core_vehicleBridge.getCachedVehicleData(self.vehicle:getId(), steeringKey)
      if steering ~= nil then
        vInfo.steering = steering
      end
      table.insert(self.capturesBuffer, vInfo)
    end
  else
    self.last_dist_pos = vehPos
  end

  self:writeCaptures(false)
end

function C:drawDebug()
  -- local debugPos = self.last_time_pos
  local debugPos = self.last_dist_pos

  if debugPos then
    debugDrawer:drawSphere(
      debugPos,
      2,
      ColorF(0,0,1,0.5)
    )
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end

