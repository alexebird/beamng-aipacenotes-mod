-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This class is a near copy of pacenote.lua.

local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

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

function C:setManual(pos, radius, normal)
  self.mode = "manual"
  self.pos = vec3(pos)
  self.radius = radius
  self:setNormal(normal)
end

function C:setPos(newpos)
  self.pos = newpos
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
        -- check both directions of the plane so we dont have to worry about having the normal in the right direction when editing pacenoteWaypoints.
        local t1 = intersectsRay_Plane(rPos, rDir, self.pos, self.normal)
        local t2 = intersectsRay_Plane(rPos, rDir, self.pos, -self.normal)
        t1 = t1*len
        t2 = t2*len
        if (t1<=1 and t1>=0) or (t2<=1 and t2>=0) then
          minT = math.min(t1, t2, minT)
        end
      end
    end
  end

  return minT <= 1, minT
end

function C:colorForWpType(pn_drawMode)
  if self.waypointType == waypointTypes.wpTypeCornerStart then
    if pn_drawMode and (pn_drawMode == 'previous' or pn_drawMode == 'next') then
      return cc.waypoint_clr_cs_adjacent
    else
      return cc.waypoint_clr_cs
    end
  elseif self.waypointType == waypointTypes.wpTypeCornerEnd then
    if pn_drawMode and (pn_drawMode == 'previous' or pn_drawMode == 'next') then
      return cc.waypoint_clr_ce_adjacent
    else
      return cc.waypoint_clr_ce
    end
  elseif self.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
    if pn_drawMode and (pn_drawMode == 'previous' or pn_drawMode == 'next') then
      return cc.waypoint_clr_at_adjacent
    else
      return cc.waypoint_clr_at
    end
  elseif self.waypointType == waypointTypes.wpTypeRevAudioTrigger then
    return cc.waypoint_clr_at
  elseif self.waypointType == waypointTypes.wpTypeDistanceMarker then
    return cc.waypoint_clr_di
  end
end

function C:shouldDrawIntersectPlane()
  if self.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
    return true
  elseif self.waypointType == waypointTypes.wpTypeRevAudioTrigger then
    return true
  else
    return false
  end
end

function C:drawDebug(hover, text, clr, shapeAlpha, textAlpha, clr_text_fg, clr_text_bg)
  if hover then
    clr = cc.waypoint_clr_sphere_hover
    shapeAlpha = cc.waypoint_shapeAlpha_hover
    textAlpha = cc.waypoint_textAlpha_hover
  end

  -- if false, no other 3d objects seem to cause clipping, such as the terrain.
  local clipArg1 = true

  local shapeAlpha_sphere = shapeAlpha

  if self:shouldDrawIntersectPlane() then
    -- make the arrow a little easier to see
    shapeAlpha_sphere = shapeAlpha * cc.waypoint_sphereAlphaReducionFactor
    -- self:drawDebugIntersectPlane(clr, shapeAlpha * cc.waypoint_intersectPlaneAlphaReductionFactor)
  end

  debugDrawer:drawSphere(
    self.pos,
    self.radius,
    ColorF(clr[1], clr[2], clr[3], shapeAlpha_sphere),
    clipArg1
  )

  clr_text_fg = clr_text_fg or cc.waypoint_clr_txt_fg
  clr_text_bg = clr_text_bg or cc.waypoint_clr_txt_bg

  debugDrawer:drawTextAdvanced(
    self.pos,
    String(text),
    ColorF(clr_text_fg[1], clr_text_fg[2], clr_text_fg[3], textAlpha),
    true,
    false,
    ColorI(clr_text_bg[1]*255, clr_text_bg[2]*255, clr_text_bg[3]*255, textAlpha*255)
  )

  if self:shouldDrawIntersectPlane() then
    local midWidth = self.radius * 2
    local side = self.normal:cross(vec3(0,0,1)) * (self.radius - (midWidth / 2))

    -- this square prism is the intersection "plane" of the pacenote.
    debugDrawer:drawSquarePrism(
      self.pos + side,
      self.pos + 0.25 * self.normal + side,
      Point2F(5, midWidth),
      Point2F(0, 0),
      ColorF(clr[1], clr[2], clr[3], shapeAlpha)
    )

    -- the "arrow"
    -- debugDrawer:drawSquarePrism(
    --   self.pos,
    --   (self.pos + self.radius * self.normal),
    --   Point2F(1, self.radius * 2),
    --   Point2F(0, 0),
    --   ColorF(clr[1], clr[2], clr[3], shapeAlpha_arrow)
    -- )

    -- draws a tiny red line indicating the forward normal.
    -- local from = (self.pos)
    -- local to = (self.pos + self.normal)
    -- debugDrawer:drawLine(from, to, ColorF(1.0, 0.0, 0.0, 1.0))
  end
end

function C:drawDebugRecce(i, nextPacenotes, note_text)
  local is_next_note = i == 1
  local multiple_notes = #nextPacenotes > 1

  -- self:drawDebugIntersectPlane(cc.clr_red, cc.pacenote_alpha_recce)
  local clr = cc.clr_white
  local shapeAlpha = 0.09

  -- local textAlpha = (is_next_note and 1.0) or 0.5
  -- local textAlpha = (multiple_notes and 0.65) or 1.0
  local textAlpha = (#nextPacenotes - (i-1)) / #nextPacenotes -- scale the alpha by distance.

  local height = 6
  local width = self.radius * 2
  local side = self.normal:cross(vec3(0,0,1)) * (self.radius - (width / 2))

  -- this square prism is the intersection "plane" of the pacenote.
  debugDrawer:drawSquarePrism(
    (self.pos + side),
    (self.pos + 0.01 * self.normal + side),
    Point2F(height, width), -- by itself, forms the lower triangle
    Point2F(height, width), -- forms the upper triangle
    ColorF(clr[1], clr[2], clr[3], shapeAlpha)
  )

  -- if is_next_note then
    local clr_text_fg = cc.waypoint_clr_txt_fg
    local clr_text_bg = cc.waypoint_clr_txt_bg

    debugDrawer:drawTextAdvanced(
      self.pos + (vec3(0,0,height/2)),
      String(note_text),
      ColorF(clr_text_fg[1], clr_text_fg[2], clr_text_fg[3], textAlpha),
      true,
      false,
      ColorI(clr_text_bg[1]*255, clr_text_bg[2]*255, clr_text_bg[3]*255, textAlpha*255)
    )
  -- end

  local clr_cyl = cc.clr_red
  -- local cyl_alpha = 0.5
  local cyl_alpha = 0.5 * ((#nextPacenotes - (i-1)) / #nextPacenotes) -- scale the alpha by distance.
  local radius_cyl = 0.1

  if multiple_notes then
    clr_cyl = cc.clr_yellow
  end

  -- if not is_next_note then
  --   cyl_alpha = 0.2
  -- end

  debugDrawer:drawCylinder(
    self.pos + (self.normal:cross(vec3(0,0,1)) * self.radius) + vec3(0,0,-1),
    self.pos + (self.normal:cross(vec3(0,0,1)) * self.radius) + (side + vec3(0, 0, (height/2)-radius_cyl)),
    radius_cyl,
    ColorF(clr_cyl[1], clr_cyl[2], clr_cyl[3], cyl_alpha)
  )

  debugDrawer:drawCylinder(
    self.pos + (-self.normal:cross(vec3(0,0,1)) * self.radius) + vec3(0,0,-1), -- adjust down through the ground in case the ground is uneven
    self.pos + (-self.normal:cross(vec3(0,0,1)) * self.radius) + (side + vec3(0, 0, (height/2)-radius_cyl)),
    radius_cyl,
    ColorF(clr_cyl[1], clr_cyl[2], clr_cyl[3], cyl_alpha)
  )

  debugDrawer:drawCylinder(
    self.pos + (self.normal:cross(vec3(0,0,1)) * (self.radius+radius_cyl)) + (side + vec3(0, 0, height/2)),
    self.pos + (-self.normal:cross(vec3(0,0,1)) * (self.radius+radius_cyl)) + (side + vec3(0, 0, height/2)),
    radius_cyl,
    ColorF(clr_cyl[1], clr_cyl[2], clr_cyl[3], cyl_alpha)
  )
end

function C:lookAtMe()
  re_util.setCameraTarget(self.pos)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
