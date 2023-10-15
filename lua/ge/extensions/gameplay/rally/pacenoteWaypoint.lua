-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This class is a near copy of pacenote.lua.

local waypointTypes = require('/lua/ge/extensions/gameplay/rally/waypointTypes')

local C = {}
local modes = {"manual","navgraph"}

function C:init(pacenote, name, forceId)
  self.pacenote = pacenote

  self.id = forceId or pacenote:getNextUniqueIdentifier()
  self.name = name or 'Waypoint '..self.id
  self.waypointType = self:getNextWaypointType()
  self.normal = vec3(0,1,0)
  self.pos = vec3()
  self.radius = 0

  self._drawMode = 'none'
  self.sortOrder = 999999
  self.mode = nil
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

function C:setNavgraph(navgraphName, fallback)
  self.mode = "navgraph"
  self.navgraphName = navgraphName
  local n = map.getMap().nodes[navgraphName]
  if n then
    self.pos = n.pos
    self.radius = n.radius * self.navRadiusScale
  else
    if fallback then
      self.pos = fallback.pos
      self.radius = fallback.radius * self.navRadiusScale
    end
  end
  self:setNormal(nil)
end

-- function C:inside(pos)
--   local inside = (pos-self.pos):length() <= self.radius
--   if self.hasNormal then
--     return inside and ((pos-self.pos):normalized():dot(self.normal) >= 0)
--   else
--     return inside
--   end
-- end

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

function C:textForDrawDebug(drawMode)
  local txt = ''
  if self.waypointType == waypointTypes.wpTypeCornerStart then
    if drawMode == 'highlight' or self.pacenote._drawMode == 'highlight' then
      txt = '['..waypointTypes.shortenWaypointType(self.waypointType)..'] ' .. self.pacenote.note
    else
      txt = self.pacenote.note
    end
  elseif self.waypointType == waypointTypes.wpTypeFwdAudioTrigger or self.waypointType == waypointTypes.wpTypeRevAudioTrigger then
    if self.name == 'curr' then
      txt = '['..waypointTypes.shortenWaypointType(self.waypointType) ..'] ' .. self.name..''
    else
      txt = '['..waypointTypes.shortenWaypointType(self.waypointType) ..']'
    end
  else
    txt = '['..waypointTypes.shortenWaypointType(self.waypointType) ..']'
  end
  return txt
end

function C:drawDebug(drawMode, clr, extraTextSuffix, extraTextPrefix, textAlpha)
  -- if self.waypointType == 'cornerEnd' then
  --   log('D', 'wtf', 'pacenoteWaypoint drawDebug start')
  --   log('D', 'wtf', '_drawmode='..self._drawMode)
  -- end
  drawMode = drawMode or self._drawMode
  -- if self.waypointType == 'cornerEnd' then
  --   log('D', 'wtf', 'drawmode='..drawMode)
  -- end
  if drawMode == 'none' then return end
  -- if self.waypointType == 'cornerEnd' then
  --   log('D', 'wtf', 'pacenoteWaypoint drawDebug passed checks and drawMode is not none')
  -- end

  -- if self.waypointType == 'cornerEnd' then
  --   log('D', 'wtf', 'HERE6')
  -- end

  clr = clr or rainbowColor(#self.pacenote.notebook.pacenotes.sorted, (self.pacenote.sortOrder-1), 1)
  if drawMode == 'highlight' then clr = {1,1,1,1} end
  --clr = {1,1,1,1}
  local shapeAlpha = (drawMode == 'highlight') and 0.5 or 0.25

  debugDrawer:drawSphere((self.pos), self.radius, ColorF(clr[1],clr[2],clr[3],shapeAlpha))

  -- if self.waypointType == 'cornerEnd' then
  --   log('D', 'wtf', 'HERE7')
  -- end

  textAlpha = textAlpha or ((drawMode == 'normal' or drawMode == 'faded') and 0.5 or 1)
  if self.pacenote.note == '' then textAlpha = textAlpha * 0.4 end
  if drawMode ~= 'faded' then
    local str = self:textForDrawDebug(drawMode)
    if extraTextPrefix then
      str = extraTextPrefix .. ' ' .. str
    end
    if extraTextSuffix then
      str = str .. ' ' .. extraTextSuffix
    end
    debugDrawer:drawTextAdvanced((self.pos),
      String(str),
      ColorF(1,1,1,textAlpha),true, false,
      ColorI(0,0,0,textAlpha*255))
  end

  -- if self.waypointType == 'cornerEnd' then
  --   log('D', 'wtf', 'HERE8')
  -- end

  local midWidth = self.radius*2
  local side = self.normal:cross(vec3(0,0,1)) *(self.radius - midWidth/2)
  -- this square prism is the "arrow" of the pacenote.
  debugDrawer:drawSquarePrism(
    self.pos,
    (self.pos + self.radius * self.normal),
    Point2F(1,self.radius/2),
    Point2F(0,0),
    ColorF(clr[1],clr[2],clr[3],shapeAlpha*1.25))
  -- this square prism is the "plane" of the pacenote.
  debugDrawer:drawSquarePrism(
    (self.pos+side),
    (self.pos + 0.25 * self.normal + side ),
    Point2F(5,midWidth),
    Point2F(0,0),
    ColorF(clr[1],clr[2],clr[3],shapeAlpha*0.66))
  
  -- if self.waypointType == 'cornerEnd' then
  --   log('D', 'wtf', 'HERE9')
  -- end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end