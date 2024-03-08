-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- ORBIT CAMERA

local C = {}
C.__index = C
-- local vecY = vec3(0,1,0)
-- local vecZ = vec3(0,0,1)
-- local lookBackVec = vec3(0,-0.3,0)
--
-- local function getRot(base, vf, vz)
--   local nyn = vf:normalized()
--   local nxn = nyn:cross(vz):projectToOriginPlane(vecZ):normalized()
--   local nzn = nxn:cross(nyn):normalized()
--   local nbase = base:normalized()
--   return math.atan2(-nbase:dot(nxn), nbase:dot(nyn)), math.asin(nbase:dot(nzn))
-- end

function C:init()
  print('pacenoteOrbit cam init')
  self.isGlobal = true
  -- self.target = false
  -- self.camLastTargetPos = vec3()
  -- self.camLastTargetPos2 = vec3()
  -- self.camLastPos = vec3()
  -- self.camLastPos2 = vec3()
  -- self.camLastPosPerp = vec3()
  -- self.camVel = vec3()
  -- self.cameraResetted = 3
  -- self.lockCamera = false
  -- self.orbitOffset = vec3()
  -- self.preResetPos = vec3(1e+300, 0, 0)
  -- self.smoothedVelocity = newTemporalSmoothing(24, 24, 24)

  -- self.targetCenter = vec3(0, 0, 0)
  -- self.targetLeft = vec3(0, 0, 0)
  -- self.targetBack = vec3(0, 0, 0)
  -- self.configChanged = false

  -- my stuff
  self.fixedTargetPos = vec3(0, 0, 0)
  self.fov = 65 -- deg
  -- self.fov = 1.13446 -- rad

  -- self:onVehicleCameraConfigChanged()
  self:setupStuff()
  self:onSettingsChanged()
  self:reset()
end

function C:setupStuff()
  if self.defaultRotation == nil then
    self.defaultRotation = vec3(0, -17, 0)
  end
  self.defaultRotation = vec3(self.defaultRotation)
  -- self.offset = vec3(self.offset)
  if not self.camRot then self.camRot = vec3(self.defaultRotation) end
  -- self.camLastRot = vec3(math.rad(self.camRot.x), math.rad(self.camRot.y), 0)
  self.camMinDist = 10
  self.camMaxDist = 700
  local default
  self.defaultDistance = 300
  self.camDist = self.distance or self.defaultDistance
  -- self.camLastDist = self.distance or 5
  -- self.mode = self.mode or 'ref'
  -- self.skipFovModifier = self.skipFovModifier or false
  -- self.smoothedVelocity:set(0)
end

-- function C:onVehicleCameraConfigChanged()
--   self.configChanged = true
--   if self.defaultRotation == nil then
--     self.defaultRotation = vec3(0, -17, 0)
--   end
--   self.defaultRotation = vec3(self.defaultRotation)
--   self.offset = vec3(self.offset)
--   if not self.camRot then self.camRot = vec3(self.defaultRotation) end
--   self.camLastRot = vec3(math.rad(self.camRot.x), math.rad(self.camRot.y), 0)
--   self.camMinDist = self.distanceMin or 3
--   self.camMaxDist = (self.distanceMin or 5) * 10
--   self.camDist = self.distance or 5
--   self.camLastDist = self.distance or 5
--   self.defaultDistance = self.distance or 5
--   self.mode = self.mode or 'ref'
--   self.skipFovModifier = self.skipFovModifier or false
--   self.smoothedVelocity:set(0)
-- end

function C:onSettingsChanged()
  print('pacenoteOrbit cam onSettingsChanged')
  core_camera.clearInputs() --TODO is this really necessary?
  self.fovModifier = settings.getValue('cameraOrbitFovModifier')
  self.relaxation = settings.getValue('cameraOrbitRelaxation') or 3
  self.maxDynamicFov = settings.getValue('cameraOrbitMaxDynamicFov') or 35
  self.maxDynamicPitch = math.rad(settings.getValue('cameraOrbitMaxDynamicPitch') or 0)
  self.maxDynamicOffset = settings.getValue('cameraOrbitMaxDynamicOffset') or 0
  self.smoothingEnabled = settings.getValue('cameraOrbitSmoothing', true)
end

-- function C:onVehicleSwitched()
  -- self.collision:onVehicleSwitched()
-- end

function C:reset()
  print('pacenoteOrbit cam reset')
  if self.cameraResetted == 0 then
    self.preResetPos = vec3(self.camLastTargetPos2)
    self.cameraResetted = 3
  end
end

-- function C:setFixedTargetPos(pos)
--   self.fixedTargetPos = vec3(pos)
-- end

-- function C:setRotation(rot)
--   self.camRot = vec3(rot)
-- end

-- function C:setFOV(fov)
--   self.fov = fov
-- end

-- function C:setOffset(v)
--   self.orbitOffset = vec3(v)
-- end

-- function C:setRefNodes(centerNodeID, leftNodeID, backNodeID, dynamicFovRearNodeID)
--   self.refNodes = self.refNodes or {}
--   self.refNodes.ref = centerNodeID
--   self.refNodes.left = leftNodeID
--   self.refNodes.back = backNodeID
--   self.rearNodeID = dynamicFovRearNodeID -- specifies which area of the vehicle will have constant screen-size during dolly zoom effect (dynamic FOV effect)
-- end

-- params in global coords
-- function C:setRef(center, left, back)
--   local prevTarget = self.target
--   self.target = center ~= nil and true or false
--   self.targetCenter = center
--   self.targetLeft = left
--   self.targetBack = back
--   if self.target ~= prevTarget then self:reset() end
-- end

function C:setRef(center, left, back)
  -- local prevTarget = self.target
  -- self.target = center ~= nil and true or false
  self.fixedTargetPos = center
  -- self.targetCenter = center
  -- self.targetLeft = left
  -- self.targetBack = back
  -- if self.target ~= prevTarget then self:reset() end
end

-- function C:setTargetMode(targetMode, camBase)
--   self.mode = targetMode
--   self.camBase = camBase
-- end

function C:setDefaultDistance(d)
  self.defaultDistance = d
end

-- function C:setDistance(d)
--   self.camDist = d
-- end

-- function C:setMaxDistance(d)
--   self.camMaxDist = d
-- end

-- function C:setDefaultRotation(rot)
--   self.defaultRotation = rot
-- end

-- function C:setSkipFovModifier(skip)
--   self.skipFovModifier = skip
-- end

-- local ref, left, back, dirxy = vec3(), vec3(), vec3(), vec3()
-- local nx, ny, nz = vec3(), vec3(), vec3()
-- local targetPos, camdir, dir = vec3(), vec3(), vec3()
-- local lastCamPointVec, lastCamLastPerp, moveDir = vec3(), vec3(), vec3()
-- local rot, calculatedCamPos, camPos, updir, rear = vec3(), vec3(), vec3(), vec3(), vec3()

function C:update(data)
  data.res.collisionCompatible = true

  local targetPos = self.fixedTargetPos

  local yawDif = 0.1 * (MoveManager.yawRight - MoveManager.yawLeft)
  local pitchDif = 0.1 * (MoveManager.pitchDown - MoveManager.pitchUp)

  -- Camera rotation around the fixed point based on user input
  local maxRot = 180 -- rotation speed
  local dtfactor = data.dt * 1000
  local mouseYaw = sign(MoveManager.yawRelative) * math.min(math.abs(MoveManager.yawRelative * 10), maxRot * data.dt) + yawDif * dtfactor
  local mousePitch = sign(-MoveManager.pitchRelative) * math.min(math.abs(MoveManager.pitchRelative * 10), maxRot * data.dt) + pitchDif * dtfactor

  -- Keyboard input for rotation
  local maxRotKeyboard = 80 -- rotation speed
  local keyboardYaw = (MoveManager.left - MoveManager.right) * maxRotKeyboard * data.dt
  local keyboardPitch = (MoveManager.forward - MoveManager.backward) * maxRotKeyboard * data.dt

  if mouseYaw ~= 0 or mousePitch ~= 0 then
    self.camRot.x = self.camRot.x - mouseYaw
    self.camRot.y = self.camRot.y - mousePitch
  end

  if keyboardYaw ~= 0 or keyboardPitch ~= 0 then
    self.camRot.x = self.camRot.x - keyboardYaw
    self.camRot.y = self.camRot.y - keyboardPitch
  end

  self.camRot.y = math.min(math.max(self.camRot.y, -85), 85)

  -- Ensure the rotation is within bounds
  self.camRot.x = (self.camRot.x + 360) % 360
  if self.camRot.x > 180 then
    self.camRot.x = self.camRot.x - 360
  end

  -- Zoom control
  local zoomChange = MoveManager.zoomIn - MoveManager.zoomOut
  local zoomSpeed = 3.0
  self.camDist = clamp(self.camDist + zoomChange * dtfactor * zoomSpeed, self.camMinDist, self.camMaxDist)

  -- Calculate the new camera position based on rotation and distance
  local rot = vec3(math.rad(self.camRot.x), math.rad(self.camRot.y), 0)
  local calculatedCamPos = vec3(
    math.sin(rot.x) * math.cos(rot.y),
    -math.cos(rot.x) * math.cos(rot.y),
    -math.sin(rot.y)
  )
  calculatedCamPos:normalize()
  calculatedCamPos = calculatedCamPos * self.camDist
  local camPos = targetPos + calculatedCamPos


  -- Get the terrain height at the new camera position
  -- Note: Assuming newPos should be camPos in your context and considering BeamNG's Z-up coordinate system
  local terrainHeight = core_terrain.getTerrainHeight(vec3(camPos.x, camPos.y, 0))

  -- Adjust camPos.z to ensure it's not below the terrain height
  -- Add some offset if needed to prevent clipping with the terrain surface
  local offsetAboveTerrain = 1.0 -- Adjust this value as needed
  if camPos.z < terrainHeight + offsetAboveTerrain then
    camPos.z = terrainHeight + offsetAboveTerrain
  end

  -- Apply the calculated camera position and orientation
  data.res.pos = camPos
  data.res.rot = quatFromDir(targetPos - camPos)
  data.res.fov = self.fov

  return true
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end

