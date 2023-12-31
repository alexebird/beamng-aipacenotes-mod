local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes'

function C:init(vehId, damageThreshold, raceData)
  self.vehId = vehId
  self.damageThreshold = damageThreshold or 1
  self.lastDamage = 0
  self.justHadDamage = false

  self.vehicle = be:getObjectByID(self.vehId)

  self.wheelOffsets = {}
  self.currentCorners = {}
  self.previousCorners = {}

  if raceData then
    self.currentCorners = raceData.states[self.vehId].currentCorners
    self.previousCorners = raceData.states[self.vehId].previousCorners
  else
    local wCount = self.vehicle:getWheelCount()-1
    if wCount > 0 then
      local vehiclePos = self.vehicle:getPosition()
      local vRot = quatFromDir(self.vehicle:getDirectionVector(), self.vehicle:getDirectionVectorUp())
      local x,y,z = vRot * vec3(1,0,0),vRot * vec3(0,1,0),vRot * vec3(0,0,1)
      for i=0, wCount do
        local axisNodes = self.vehicle:getWheelAxisNodes(i)
        local nodePos = vec3(self.vehicle:getNodePosition(axisNodes[1]))
        local pos = vec3(nodePos:dot(x), nodePos:dot(y), nodePos:dot(z))
        table.insert(self.wheelOffsets, pos)
        table.insert(self.currentCorners, vRot*pos + vehiclePos)
        table.insert(self.previousCorners, vRot*pos + vehiclePos)
      end
    end
  end
end

function C:getPreviousCorners()
  return self.previousCorners
end

function C:getCurrentCorners()
  return self.currentCorners
end

function C:onUpdate(dt, raceData)
  self:updateVehicleData()
  self:updateVehicleCorners(raceData)
  self:updateVehicleDamage()
end

function C:updateVehicleCorners(raceData)
  if raceData then
    self.currentCorners = raceData.states[self.vehId].currentCorners
    self.previousCorners = raceData.states[self.vehId].previousCorners
  else
    local vPos = self.vehicle:getPosition()
    local vRot = quatFromDir(self.vehicle:getDirectionVector(), self.vehicle:getDirectionVectorUp())
    for i, corner in ipairs(self.wheelOffsets) do
      self.previousCorners[i]:set(self.currentCorners[i])
      self.currentCorners[i]:set(vPos + vRot*corner)
    end
  end
end

function C:updateVehicleDamage()
  local currDamage = self:damage()
  if not currDamage then
    self.justHadDamage = false
    return
  end
  local diff = currDamage - self.lastDamage

  if currDamage > self.lastDamage and diff >= self.damageThreshold then
    self.lastDamage = currDamage
    self.justHadDamage = true
  else
    self.justHadDamage = false
  end
end

function C:updateVehicleData()
  self.vehicleData = map.objects[self.vehicle:getId()]
end

function C:pos()
  return self.vehicle:getPosition()
end

function C:damage()
  if self.vehicleData then
    return self.vehicleData.damage
  else
    return nil
  end
end

function C:didJustHaveDamage()
  return self.justHadDamage
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
