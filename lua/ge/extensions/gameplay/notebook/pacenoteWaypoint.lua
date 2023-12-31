-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This class is a near copy of pacenote.lua.

local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')

local C = {}

function C:init(pacenote, name, pos, forceId)
  self.pacenote = pacenote

  self.id = forceId or pacenote:getNextUniqueIdentifier()

  local nextType = self.pacenote:getNextWaypointType()
  if nextType == waypointTypes.wpTypeFwdAudioTrigger then
    name = "curr"
  elseif nextType == waypointTypes.wpTypeDistanceMarker then
    local cnt = #self.pacenote:getDistanceMarkerWaypoints()
    name = 'dist '..(cnt+1)
  end
  self.name = name or ('Waypoint '..self.id)
  self.waypointType = nextType

  self.normal = vec3(0,1,0)
  self.pos = pos
  self.radius = (editor_rallyEditor and editor_rallyEditor.getPrefDefaultRadius()) or 10

  self.sortOrder = 999999
  self.mode = nil
  -- self.validation_issues = {}
end

-- function C:validate()
--   self.validation_issues = {}
--   return true
-- end
--
-- function C:is_valid()
--   return #self.validation_issues > 0
-- end

function C:selectionString()
  local txt = '['..waypointTypes.shortenWaypointType(self.waypointType)..']'
  txt = txt .. ' '..self.name
  return txt
end

function C:flipNormal()
  self.normal = -self.normal
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
    return cc.waypoint_clr_cs
  elseif self.waypointType == waypointTypes.wpTypeCornerEnd then
    return cc.waypoint_clr_ce
  elseif self.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
    return cc.waypoint_clr_at
  elseif self.waypointType == waypointTypes.wpTypeRevAudioTrigger then
    return cc.waypoint_clr_at
  elseif self.waypointType == waypointTypes.wpTypeDistanceMarker then
    return cc.waypoint_clr_di
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
    clr = cc.waypoint_clr_sphere_hover
    shapeAlpha = cc.waypoint_shapeAlpha_hover
    textAlpha = cc.waypoint_textAlpha_hover
  end

  -- if false, no other 3d objects seem to cause clipping, such as the terrain.
  local clipArg1 = true

  local shapeAlpha_sphere = shapeAlpha

  if self:shouldDrawArrow() then
    -- make the arrow a little easier to see
    shapeAlpha_sphere = shapeAlpha * cc.waypoint_sphereAlphaReducionForArrowFactor
  end

  debugDrawer:drawSphere(
    (self.pos),
    self.radius,
    ColorF(clr[1], clr[2], clr[3], shapeAlpha_sphere),
    clipArg1
  )

  local clr_text_fg = cc.waypoint_clr_txt_fg
  local clr_text_bg = cc.waypoint_clr_txt_bg

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

    local shapeAlpha_arrow = shapeAlpha * cc.waypoint_shapeAlpha_arrowAdjustFactor
    local shapeAlpha_arrowPlane = shapeAlpha * cc.waypoint_shapeAlpha_arrowPlaneAdjustFactor

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

function C:posForVehiclePlacement()
  local pos = (self.pos + (self.radius*2) * -self.normal)
  return pos
end

function C:rotForVehiclePlacement(vehicle)
  local pointA = self.pos
  local pointB = (self.pos + self.radius * self.normal)

  local dx = pointB.x - pointA.x
  local dy = pointB.y - pointA.y
  local dz = pointB.z - pointA.z

  local fwd = {x = dx, y = dy, z = dz}
  fwd = vec3(fwd)

  local up = {x = 0, y = 0 , z = 1}
  up = vec3(up)
  local rot = quatFromDir(fwd, up):normalized()
  return rot
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
