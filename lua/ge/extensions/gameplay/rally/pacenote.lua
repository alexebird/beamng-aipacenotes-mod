-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local modes = {"manual","navgraph"}

function C:init(notebook, name, forceId)
  self.notebook = notebook
  self.id = forceId or notebook:getNextUniqueIdentifier()
  self.name = name or "Pacenote " .. self.id
  self.note = ""
  self.segment = -1
  self.pacenoteWaypoints = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "pacenoteWaypoints",
    self,
    require('/lua/ge/extensions/gameplay/rally/pacenoteWaypoint')
  )
  self.pacenoteWaypointsByType = nil

  self._drawMode = 'none'
  self.sortOrder = 999999
end

function C:getNextUniqueIdentifier()
  return self.notebook:getNextUniqueIdentifier()
end

function C:indexWaypointsByType()
  self.pacenoteWaypointsByType = {}

  for i, wp in pairs(self.pacenoteWaypoints.objects) do
    local wpType = wp.waypointType
    if self.pacenoteWaypointsByType[wpType] == nil then
      self.pacenoteWaypointsByType[wpType] = {}
    end
    table.insert(self.pacenoteWaypointsByType[wpType], wp)
  end
end

function C:validateWaypointTypes()
  -- TODO
  return true
end

function C:getCornerStartWaypoint()
  local wpListForType = self.pacenoteWaypointsByType[editor_rallyEditor.wpTypeCornerStart]
  if wpListForType then
    local k, v = next(wpListForType)
    return v
  else
    return nil
  end
end

function C:onSerialize()
  local ret = {
    oldId = self.id,
    name = self.name,
    note = self.note,
    segment = self.segment,
    pacenoteWaypoints = self.pacenoteWaypoints:onSerialize(),
  }

  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.name = data.name
  self.note = data.note
  self.segment = oldIdMap and oldIdMap[data.segment] or data.segment or -1
  self.pacenoteWaypoints:onDeserialized(data.pacenoteWaypoints, oldIdMap)

  self:indexWaypointsByType()
end

-- function C:setNormal(normal)
--   if not normal then
--     self.normal = vec3(0,1,0)
--   end
--   if normal:length() > 0.9 then
--     self.normal = normal:normalized()
--   end
-- end

-- function C:setManual(pos, radius, normal)
--   self.mode = "manual"
--   self.pos = vec3(pos)
--   self.radius = radius
--   self:setNormal(normal)
--   self.navgraphName = nil
-- end

-- function C:setNavgraph(navgraphName, fallback)
--   self.mode = "navgraph"
--   self.navgraphName = navgraphName
--   local n = map.getMap().nodes[navgraphName]
--   if n then
--     self.pos = n.pos
--     self.radius = n.radius * self.navRadiusScale
--   else
--     if fallback then
--       self.pos = fallback.pos
--       self.radius = fallback.radius * self.navRadiusScale
--     end
--   end
--   self:setNormal(nil)
-- end


-- function C:inside(pos)
--   local inside = (pos-self.pos):length() <= self.radius
--   if self.hasNormal then
--     return inside and ((pos-self.pos):normalized():dot(self.normal) >= 0)
--   else
--     return inside
--   end
-- end

-- function C:intersectCorners(fromCorners, toCorners)
--     return self:intersectCorners(fromCorners, toCorners)
-- end

-- function C:intersectCornersDynamic(fromCorners, toCorners)
--   local minT = math.huge
--   for i = 1, #fromCorners do
--     local rPos, rDir = fromCorners[i], toCorners[i]-fromCorners[i]
--     local len = rDir:length()
--     if len > 0 then
--       len = 1/len
--       rDir:normalize()
--       local sMin, sMax = intersectsRay_Sphere(rPos, rDir, self.pos, self.radius)
--       --adjust for normlized rDir
--       sMin = sMin * len
--       sMax = sMax * len
--       -- inside sphere?
--       if sMin <= 0 and sMax >= 1 then
--         local t = intersectsRay_Plane(rPos, rDir, self.pos, self.normal)
--         t = t*len
--         if t<=1 and t>=0 then
--           minT = math.min(t, minT)
--         end
--       end
--     end
--   end

--   return minT <= 1, minT
-- end

-- function C:intersectCornersOrig(fromCorners, toCorners)
--   local minT = math.huge
--   for i = 1, #fromCorners do
--     local rPos, rDir = fromCorners[i], toCorners[i]-fromCorners[i]
--     local len = rDir:length()
--     if len > 0 then
--       len = 1/len
--       rDir:normalize()
--       local sMin, sMax = intersectsRay_Sphere(rPos, rDir, self.pos, self.radius)
--       --adjust for normlized rDir
--       sMin = sMin * len
--       sMax = sMax * len
--       -- inside sphere?
--       if sMin <= 0 and sMax >= 1 then
--         local t = intersectsRay_Plane(rPos, rDir, self.pos, self.normal)
--         t = t*len
--         if t<=1 and t>=0 then
--           minT = math.min(t, minT)
--         end
--       end
--     end
--   end

--   return minT <= 1, minT
-- end

function C:drawDebug(drawMode, clr, extraText)
  -- local wp = self:getCornerStartWaypoint()
  -- if wp then
  --   wp:drawDebug(self._drawMode, clr, extraText)
  -- end

  for i,wp in pairs(self.pacenoteWaypoints.objects) do
    wp:drawDebug(self._drawMode, clr, extraText)
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end