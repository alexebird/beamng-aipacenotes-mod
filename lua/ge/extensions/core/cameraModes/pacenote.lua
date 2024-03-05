-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

local manualzoom = require('core/cameraModes/manualzoom')

local rotEulerTemp = quat()
local function setRotateEuler(x, y, z, qSource, qDest)
  rotEulerTemp:setFromEuler(0, z, 0)
  qDest:setQuatMul(rotEulerTemp, qSource)
  rotEulerTemp:setFromEuler(0, 0, x)
  qDest:setQuatMul(rotEulerTemp, qDest)
  rotEulerTemp:setFromEuler(y, 0, 0)
  qDest:setQuatMul(rotEulerTemp, qDest)
  return qDest
end

function C:reset()
  self.angularVelocity = vec3(0,0,0)
  self.velocity = vec3(0,0,0)
  self.manualzoom = manualzoom()
  self.manualzoom:init(65)
  self.rot.z = 0 -- reset roll
end

function C:setSmoothedCam(smoothed)
  if smoothed then
    self.angularForce = 150
    self.angularDrag = 2.5
    self.mass = 10
    self.translationForce = 600
    self.translationDrag = 2
    self.angularVelocity = vec3(0,0,0)
  else
    self.angularForce = 400
    self.angularDrag = 16
    self.mass = 1
    self.translationForce = 250
    self.translationDrag = 17
  end
end

function C:init()
  self.isGlobal = true
  self.hidden = true

  self:setSmoothedCam(false)

  self.pos = vec3(0,0,0)
  -- self.rot = vec3(0,0,0)
  self.rot = quat(0,0,0,1)
  self.targetPos = vec3(0,0,0)
  self.newtonTranslation = true
  self.newtonRotation = true
  self:reset()
end

function C:setTarget(position)
  self.targetPos = position
end

function C:setPosition(position)
  self.pos = position
end

function C:setFOV(fovDeg)
  self.manualzoom:init(fovDeg)
end

function C:setNewtonRotation(enabled)
  self.newtonRotation = enabled
end

function C:setNewtonTranslation(enabled)
  self.newtonTranslation = enabled
end

function C:setRotation(rotation)
  local eulerYXZ = rotation:toEulerYXZ()
  eulerYXZ.y = -eulerYXZ.y
  self.rot:set(eulerYXZ)
end

local function cartesianToSpherical(x, y, z)
  local radius = math.sqrt(x*x + y*y + z*z)
  local theta = math.atan2(y, x)
  local phi = math.acos(z / radius)
  return radius, theta, phi
end

-- Function to convert Spherical coordinates back to Cartesian
local function sphericalToCartesian(radius, theta, phi)
  local x = radius * math.sin(phi) * math.cos(theta)
  local y = radius * math.sin(phi) * math.sin(theta)
  local z = radius * math.cos(phi)
  return x, y, z
end

local inputVec, acc, forceVec, tempVec = vec3(), vec3(), vec3(), vec3()
local qdir, qdirLook = quat(), quat()
function C:update(data)

  -- local u = cameraOrbitState.up == 1
  -- local d = cameraOrbitState.down == 1
  -- local r = cameraOrbitState.right == 1
  -- local l = cameraOrbitState.left == 1
  -- local orbitChanged = u or d or r or l

  local yawDif = 0.1*(MoveManager.yawRight - MoveManager.yawLeft)
  local pitchDif = 0.1*(MoveManager.pitchDown - MoveManager.pitchUp)
  local maxRot = 4.5
  -- if (math.abs(yawDif) + math.abs(pitchDif) + math.abs(MoveManager.yawRelative) + math.abs(MoveManager.pitchRelative) > 0) then
  --   maxRot = 1000
  -- end

  local dtfactor = data.dt * 1000
  local mouseYaw = sign(MoveManager.yawRelative) * math.min(math.abs(MoveManager.yawRelative * 10), maxRot * data.dt) + yawDif * dtfactor
  local mousePitch = sign(-MoveManager.pitchRelative) * math.min(math.abs(MoveManager.pitchRelative * 10), maxRot * data.dt) + pitchDif * dtfactor
  -- if mouseYaw ~= 0 or mousePitch ~= 0 then
    -- if self.cameraResetted == 0 then
    --   self.lockCamera = true
    -- end

    -- print(dumps(mouseYaw))
    -- print(dumps(mousePitch))
    -- print('-------------------------------------')

    -- self.rot.x = self.rot.x - mouseYaw
    -- self.rot.y = self.rot.y - mousePitch
    --self.rot.z = self.rot.z + 300*data.dt*(MoveManager.rollRight - MoveManager.rollLeft)
  -- end

    -- pitch
  local u = mousePitch < 0
  local d = mousePitch > 0
    -- yaw
  local r = mouseYaw > 0
  local l = mouseYaw < 0
  local orbitChanged = u or d or r or l

  if orbitChanged then
    -- local cameraPosition = core_camera.getPosition()
        if not self.pos then
            print('self.pos is nil')
            return true
        end
    local cameraPosition = self.pos
    -- local pn = pacenotesWindow:selectedPacenote()
    -- if pn then
      -- local wp = pn:getCornerStartWaypoint()
      local targetPosition = self.targetPos

      -- Convert to Spherical Coordinates
      local radius, theta, phi = cartesianToSpherical(cameraPosition.x - targetPosition.x, cameraPosition.y - targetPosition.y, cameraPosition.z - targetPosition.z)

      local orbitSpeed = 0.025

      -- if editor.keyModifiers.shift then
        -- orbitSpeed = 0.05
        -- orbitSpeed = orbitSpeed * 2
      -- end

      -- Update theta and phi based on input
      if r then theta = theta + orbitSpeed end
      if l then theta = theta - orbitSpeed end
      if u then phi = phi - orbitSpeed end
      if d then phi = phi + orbitSpeed end

      -- Ensure phi stays within bounds
      phi = math.max(0.1, math.min(math.pi - 0.1, phi))

      -- Convert back to Cartesian Coordinates
      local newX, newY, newZ = sphericalToCartesian(radius, theta, phi)
      local newPos = vec3(newX + targetPosition.x, newY + targetPosition.y, newZ + targetPosition.z)

      -- Check and adjust the camera position to ensure it's above the terrain
      local terrainHeight = core_terrain.getTerrainHeight(vec3(newPos.x, newPos.z, 0))
      terrainHeight = terrainHeight + 5
      if newPos.z < terrainHeight then
        newPos.z = terrainHeight
      end

    local newRot = quatFromDir(targetPosition - newPos)

      -- Set the new camera position and rotation
      -- core_camera.setPosition(0, newPos)
      -- make the camera look at the center point.
      -- core_camera.setRotation(0, newRot)
    -- end
      self.pos = newPos
        self.rot = newRot
      -- data.res.pos:set(self.pos)
  end


    data.res.pos:set(self.pos)
      data.res.rot = self.rot


















  -- print(dumps(MoveManager))

  -- local yawDif = 0.1*(MoveManager.yawRight - MoveManager.yawLeft)
  -- local pitchDif = 0.1*(MoveManager.pitchDown - MoveManager.pitchUp)
  --
  --   -- mouse rotation from orbit cam
  -- local maxRot = 4.5
  -- if (math.abs(yawDif) + math.abs(pitchDif) + math.abs(MoveManager.yawRelative) + math.abs(MoveManager.pitchRelative) > 0) then
  --   maxRot = 1000
  -- end
  --
  -- -- mouse rotation
  -- local dtfactor = data.dt * 1000
  -- local mouseYaw = sign(MoveManager.yawRelative) * math.min(math.abs(MoveManager.yawRelative * 10), maxRot * data.dt) + yawDif * dtfactor
  -- local mousePitch = sign(-MoveManager.pitchRelative) * math.min(math.abs(MoveManager.pitchRelative * 10), maxRot * data.dt) + pitchDif * dtfactor
  -- if mouseYaw ~= 0 or mousePitch ~= 0 then
  --   if self.cameraResetted == 0 then
  --     self.lockCamera = true
  --   end
  --
  --   print(dumps(mouseYaw))
  --   print(dumps(mousePitch))
  --   print('-------------------------------------')
  --
  --   self.rot.x = self.rot.x - mouseYaw
  --   self.rot.y = self.rot.y - mousePitch
  --   --self.rot.z = self.rot.z + 300*data.dt*(MoveManager.rollRight - MoveManager.rollLeft)
  -- end
  --
  -- self.rot.y = math.min(math.max(self.rot.y, -85), 85)
  -- qdir:set(0,0,0,1)
  -- setRotateEuler(self.rot.x, -self.rot.y, 0, qdir, qdirLook)
  -- setRotateEuler(0, 0, self.rot.z, qdirLook, qdir)



  -- Rotation
  -- local dtFactor = data.dt * 200
  -- inputVec:set(
  --   MoveManager.yawRelative / dtFactor + (MoveManager.yawRight - MoveManager.yawLeft) * 0.07,
  --   MoveManager.pitchRelative / dtFactor + (MoveManager.pitchUp - MoveManager.pitchDown) * 0.07,
  --   MoveManager.rollRelative / dtFactor + (MoveManager.rollLeft - MoveManager.rollRight) * 0.07
  -- )
  -- if self.newtonRotation then
  --   acc:set(0,0,0)
  --   if inputVec:squaredLength() > 0 then
  --     acc:setScaled2(inputVec, self.angularForce / self.mass)
  --   end
  --   forceVec:setScaled2(acc, data.dt) -- Acceleration
  --   forceVec:set(push3(forceVec) - push3(self.angularVelocity) * math.min(self.angularDrag * data.dt, 1)) -- Drag
  --   self.angularVelocity:setAdd(forceVec)
  -- else
  --   self.angularVelocity:setScaled2(inputVec, 30)
  -- end
  --
  -- self.rot:set(push3(self.rot) + push3(self.angularVelocity) * data.dt) -- Rotate
  -- self.rot.y = clamp(self.rot.y, -1.5706, 1.5706)
  --
  -- qdir:set(0,0,0,1)
  -- setRotateEuler(self.rot.x, -self.rot.y, 0, qdir, qdirLook)
  -- setRotateEuler(0, 0, self.rot.z, qdirLook, qdir)

  -- Translation
  -- acc:set(0,0,0)
  -- inputVec:set(
  --   MoveManager.right - MoveManager.left + MoveManager.absXAxis,
  --   MoveManager.forward - MoveManager.backward + MoveManager.absYAxis,
  --   MoveManager.up - MoveManager.down + MoveManager.absZAxis
  -- )
  --
  -- local modifiedSpeed = data.fastSpeedModifier and data.speed * 3 or data.speed
  -- local adjustedSpeed = ((modifiedSpeed^2)/30) / 40
  -- if self.newtonTranslation then
  --   local force = self.translationForce * adjustedSpeed
  --   if inputVec:squaredLength() > 0 then
  --     acc:setScaled2(inputVec, force / self.mass)
  --   end
  --   forceVec:setScaled2(acc, data.dt) -- Acceleration
  --   forceVec:set(push3(forceVec) - push3(self.velocity) * math.min(self.translationDrag * data.dt, 1)) -- Drag
  --   self.velocity:setAdd(forceVec)
  -- else
  --   self.velocity:setScaled2(inputVec, adjustedSpeed * 15)
  -- end
  -- tempVec:setRotate(qdir, self.velocity)
  -- self.pos:set(push3(self.pos) + push3(tempVec) * data.dt) -- Move

  -- data.res.rot = qdir
  -- data.res.pos:set(self.pos)

  -- self.manualzoom:update(data)
  return true
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
