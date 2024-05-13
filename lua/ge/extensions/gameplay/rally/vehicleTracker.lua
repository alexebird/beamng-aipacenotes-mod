local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes'

-- function C:init(damageThreshold, raceData)
function C:init(damageThreshold)
  -- raceData = nil

  -- self.rallyManager = rallyManager

  log('D', logTag, 'VehicleTracker init')

  self.damageThreshold = damageThreshold or 1

  self:updateVehicleData(self:getVehicleId())
  self.lastDamage = self:damage()
  self.lastDamageDiff = 0
  self.justHadDamage = false

  self.wheelOffsets = {}
  self.currentCorners = {}
  self.previousCorners = {}

  -- if raceData then
  --   local vehId = self:getVehicleId()
  --   self.currentCorners = raceData.states[vehId].currentCorners
  --   self.previousCorners = raceData.states[vehId].previousCorners
  -- else
    local vehicle = self:getVehicle()
    local wCount = vehicle:getWheelCount()-1
    if wCount > 0 then
      local vehiclePos = vehicle:getPosition()
      local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
      local x,y,z = vRot * vec3(1,0,0),vRot * vec3(0,1,0),vRot * vec3(0,0,1)
      for i=0, wCount do
        local axisNodes = vehicle:getWheelAxisNodes(i)
        local nodePos = vec3(vehicle:getNodePosition(axisNodes[1]))
        local pos = vec3(nodePos:dot(x), nodePos:dot(y), nodePos:dot(z))
        table.insert(self.wheelOffsets, pos)
        table.insert(self.currentCorners, vRot*pos + vehiclePos)
        table.insert(self.previousCorners, vRot*pos + vehiclePos)
      end
    end
  -- end
end

function C:getVehicleId()
  return be:getPlayerVehicleID(0)
end

function C:getVehicle()
  -- local vehObjId = be:getPlayerVehicleID(0) -> 50001
-- print( be:getObjectByID(be:getPlayerVehicleID(0)):getId() ) -> 50001
  return be:getObjectByID(self:getVehicleId())
end

function C:getPreviousCorners()
  return self.previousCorners
end

function C:getCurrentCorners()
  return self.currentCorners
end

-- function C:onUpdate(dt, raceData)
function C:onUpdate(dt)
  local vehId = self:getVehicleId()
  local vehicle = self:getVehicle()
  -- raceData = nil

  -- log('D', logTag, 'VehicleTracker.onUpdate vehId='..vehId)

  self:updateVehicleData(vehId)
  -- self:updateVehicleCorners(vehicle, raceData)
  self:updateVehicleCorners(vehicle)
  self:updateVehicleDamage()
end

function C:updateVehicleCorners(vehicle)
  -- local vehId = self:getVehicleId()
  -- if raceData and raceData.states[vehId] then
    -- self.currentCorners = raceData.states[vehId].currentCorners
    -- self.previousCorners = raceData.states[vehId].previousCorners
  -- else
    if vehicle then
      local vPos = vehicle:getPosition()
      local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
      for i, corner in ipairs(self.wheelOffsets) do
        self.previousCorners[i]:set(self.currentCorners[i])
        self.currentCorners[i]:set(vPos + vRot*corner)
      end
    else
      log('E', logTag, 'updateVehicleCorners: vehicle was null')
    end
  -- end
end

function C:updateVehicleDamage()
  local currDamage = self:damage()
  if not currDamage then
    self.justHadDamage = false
    return
  end

  -- this is some one time initial setup.
  -- otherwise, if the vehicle has damage already when the class is instantiated,
  -- it will erroneously think a big jump in damage has occurred..
  -- if not self.lastDamage then
  --   self.lastDamage = currDamage
  -- end

  local diff = currDamage - self.lastDamage

  if currDamage > self.lastDamage then
    self.lastDamage = currDamage
    self.lastDamageDiff = diff
    if self.lastDamageDiff >= self.damageThreshold then
      self.justHadDamage = true
    end
  else
    self.justHadDamage = false
  end
end

function C:updateVehicleData(vehicleId)
  self.vehicleData = map.objects[vehicleId]
end

function C:pos()
  local vehicle = self:getVehicle()
  return vehicle:getPosition()
end

function C:velocity()
  local vehicle = self:getVehicle()
  return vehicle:getVelocity()
end

function C:damage()
  if self.vehicleData then
    return self.vehicleData.damage or 0
  else
    return nil
  end
end

function C:didJustHaveDamage()
  -- if self.justHadDamage then
    -- log('I', logTag, 'got damage during last tick. lastDamage='..self.lastDamage ..' diff='..self.lastDamageDiff..' threshold='..self.damageThreshold)
  -- end
  return self.justHadDamage
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
