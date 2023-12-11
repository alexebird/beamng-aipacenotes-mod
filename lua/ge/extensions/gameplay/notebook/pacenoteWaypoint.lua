-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This class is a near copy of pacenote.lua.

local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')

local C = {}

local clr_white = {1.0, 1.0, 1.0}
local clr_black = {0.0, 0.0, 0.0}
local clr_green = {0.0, 1.0, 0.0}
local clr_red = {1.0, 0.0, 0.0}
local clr_blue = {0.0, 0.0, 1.0}
local clr_orange = {1.0, 0.64, 0.0}

local shapeAlpha_hover = 1.0
local textAlpha_hover = 1.0

local sphereAlphaReducionForArrowFactor = 0.9
local shapeAlpha_arrowAdjustFactor = 1.25
local shapeAlpha_arrowPlaneAdjustFactor = 0.66

function C:init(pacenote, name, pos, forceId)
  self.pacenote = pacenote

  self.id = forceId or pacenote:getNextUniqueIdentifier()
  self.name = name or 'Waypoint '..self.id
  self.waypointType = self:getNextWaypointType()
  self.normal = vec3(0,1,0)
  self.pos = pos
  self.radius = editor_rallyEditor.getPrefDefaultRadius()

  self.sortOrder = 999999
  self.mode = nil
end

function C:flipNormal()
  self.normal = -self.normal
end

function C:getNextWaypointType()
  local foundTypes = {
    [waypointTypes.wpTypeCornerStart] = false,
    [waypointTypes.wpTypeCornerEnd] = false,
    [waypointTypes.wpTypeFwdAudioTrigger] = false,
  }

  for i,wp in pairs(self.pacenote.pacenoteWaypoints.objects) do
    foundTypes[wp.waypointType] = true
  end

  if foundTypes[waypointTypes.wpTypeCornerStart] == false then
    return waypointTypes.wpTypeCornerStart
  elseif foundTypes[waypointTypes.wpTypeCornerEnd] == false then
    return waypointTypes.wpTypeCornerEnd
  elseif foundTypes[waypointTypes.wpTypeFwdAudioTrigger] == false then
    return waypointTypes.wpTypeFwdAudioTrigger
  else
    return waypointTypes.wpTypeDistanceMarker
  end
end

function C:setManual(pos, radius, normal)
  self.mode = "manual"
  self.pos = vec3(pos)
  self.radius = radius
  self:setNormal(normal)
end

function C:setNormal(normal)
  if not normal then
    self.normal = vec3(0,1,0)
  end
  if normal:length() > 0.9 then
    self.normal = normal:normalized()
  end
end

function C:onSerialize()
  local ret = {
    oldId = self.id,
    name = self.name,
    waypointType = self.waypointType,
    pos = {self.pos.x,self.pos.y,self.pos.z},
    radius = self.radius,
    normal = {self.normal.x,self.normal.y,self.normal.z},
  }
  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.waypointType = data.waypointType
  self.name = data.name
  self:setManual(vec3(data.pos), data.radius, vec3(data.normal))
end

function C:intersectCorners(fromCorners, toCorners)
  local minT = math.huge
  for i = 1, #fromCorners do
    local rPos, rDir = fromCorners[i], toCorners[i]-fromCorners[i]
    local len = rDir:length()
    if len > 0 then
      len = 1/len
      rDir:normalize()
      local sMin, sMax = intersectsRay_Sphere(rPos, rDir, self.pos, self.radius)
      --adjust for normlized rDir
      sMin = sMin * len
      sMax = sMax * len
      -- inside sphere?
      if sMin <= 0 and sMax >= 1 then
        local t = intersectsRay_Plane(rPos, rDir, self.pos, self.normal)
        t = t*len
        if t<=1 and t>=0 then
          minT = math.min(t, minT)
        end
      end
    end
  end

  return minT <= 1, minT
end

function C:colorForWpType()
  if self.waypointType == waypointTypes.wpTypeCornerStart then
    return clr_green
  elseif self.waypointType == waypointTypes.wpTypeCornerEnd then
    return clr_red
  elseif self.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
    return clr_blue
  elseif self.waypointType == waypointTypes.wpTypeRevAudioTrigger then
    return clr_blue
  elseif self.waypointType == waypointTypes.wpTypeDistanceMarker then
    return clr_orange
  end
end

function C:shouldDrawArrow()
  if self.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
    return true
  elseif self.waypointType == waypointTypes.wpTypeRevAudioTrigger then
    return true
  else
    return false
  end
end

function C:drawDebug(hover, text, clr, shapeAlpha, textAlpha)
  if hover then
    clr = clr_white
    shapeAlpha = shapeAlpha_hover
    textAlpha = textAlpha_hover
  end

  -- if false, no other 3d objects seem to cause clipping, such as the terrain.
  local clipArg1 = true

  local shapeAlpha_sphere = shapeAlpha

  if self:shouldDrawArrow() then
    -- make the arrow a little easier to see
    shapeAlpha_sphere = shapeAlpha * sphereAlphaReducionForArrowFactor
  end

  debugDrawer:drawSphere(
    (self.pos),
    self.radius,
    ColorF(clr[1], clr[2], clr[3], shapeAlpha_sphere),
    clipArg1
  )

  local clr_text_fg = clr_white
  local clr_text_bg = clr_black

  debugDrawer:drawTextAdvanced(
    (self.pos),
    String(text),
    ColorF(clr_text_fg[1], clr_text_fg[2], clr_text_fg[3], textAlpha),
    true,
    false,
    ColorI(clr_text_bg[1], clr_text_bg[2], clr_text_bg[3], textAlpha*255)
  )

  if self:shouldDrawArrow() then
    local midWidth = self.radius*2
    local side = self.normal:cross(vec3(0,0,1)) * (self.radius - midWidth / 2)

    local shapeAlpha_arrow = shapeAlpha * shapeAlpha_arrowAdjustFactor
    local shapeAlpha_arrowPlane = shapeAlpha * shapeAlpha_arrowPlaneAdjustFactor

    -- this square prism is the "arrow" of the pacenote.
    debugDrawer:drawSquarePrism(
      self.pos,
      (self.pos + self.radius * self.normal),
      Point2F(1, self.radius / 2),
      Point2F(0, 0),
      ColorF(clr[1], clr[2], clr[3], shapeAlpha_arrow)
    )
    -- this square prism is the "plane" of the pacenote.
    debugDrawer:drawSquarePrism(
      (self.pos + side),
      (self.pos + 0.25 * self.normal + side),
      Point2F(5, midWidth),
      Point2F(0, 0),
      ColorF(clr[1], clr[2], clr[3], shapeAlpha_arrowPlane)
    )

    -- draws a tiny red line indicating the forward normal.
    -- local from = (self.pos)
    -- local to = (self.pos + self.normal)
    -- debugDrawer:drawLine(from, to, ColorF(1.0, 0.0, 0.0, 1.0))
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
