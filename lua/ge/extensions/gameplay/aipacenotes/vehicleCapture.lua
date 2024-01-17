local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

local steeringKey = 'steering'

function C:init(vehicle, cornerAngles, selectedCornerAnglesName)
  self.vehicle = vehicle
  self.cornerAngles = cornerAngles
  self.selectedCornerAnglesName = selectedCornerAnglesName
  self.style = nil

  for _,style in ipairs(self.cornerAngles.pacenoteStyles) do
    if style.name == self.selectedCornerAnglesName then
      self.style = style
      break
    end
  end

  -- core_vehicleBridge.unregisterValueChangeNotification(self.vehicle, 'steering')
  core_vehicleBridge.registerValueChangeNotification(self.vehicle, steeringKey)

  -- time-based
  self.interval_s = 1
  self.last_capture_ts = re_util.getTime()
  self.last_time_pos = nil

  -- distance-based
  self.interval_m = 2
  -- self.last_capture_ts = re_util.getTime()
  self.last_dist_pos = nil
end

function C:getCornerCall(steering)
  if not self.style then return nil end

  local absSteeringVal = math.abs(steering)
  for _,item in ipairs(self.style.angles) do
    if absSteeringVal >= item.fromAngleDegrees and absSteeringVal < item.toAngleDegrees then
      local direction = steering >= 0 and "L" or "R"
      local cornerCallWithDirection = item.cornerCall..direction
      if item.cornerCall == '_deadzone' then
        cornerCallWithDirection = 'c'
      end
      return string.upper(cornerCallWithDirection)
    end
  end
end

function C:capture()
  -- self:drawDebug()

  -- pos appears to be centered over the top center of the windshield.
  local vehPos = self.vehicle:getPosition()
  local vehRot = quatFromDir(self.vehicle:getDirectionVector(), self.vehicle:getDirectionVectorUp())
  -- rotation = QuatF(q.x, q.y, q.z, q.w)

  local now = re_util.getTime()

  local vInfo = {
    ts = now,
    -- pos = vehPos,
    pos = { x = vehPos.x, y = vehPos.y, z = vehPos.z },
    -- quat = vehRot,
    quat = {x = vehRot.x, y = vehRot.y, z = vehRot.z, w = vehRot.w},
    steering = nil,
    cornerCall = nil,
  }

  -- time-based
  -- local diff = now - self.last_capture_ts
  -- if diff >= self.interval_s then
    -- self.last_capture_ts = now
    -- self.last_time_pos = vehPos
    -- log("D", 'wtf', dumps(vehPos))
  -- end

  -- distance-based
  if self.last_dist_pos then
    local dist = self.last_dist_pos:distance(vehPos)
    if dist > self.interval_m then
      self.last_dist_pos = vehPos

      local steering = core_vehicleBridge.getCachedVehicleData(self.vehicle:getId(), steeringKey)
      if steering ~= nil then
        vInfo.steering = steering
        vInfo.cornerCall = self:getCornerCall(steering)
      end
      -- log('D', 'wtf', dumps(vInfo))
    end
  else
    self.last_dist_pos = vehPos
  end
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

