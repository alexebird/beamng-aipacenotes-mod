-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local modes = {"manual","navgraph"}
local logTag = 'aipacenotes_pacenote'

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

  -- self.pacenoteWaypoints.postClear = function() self:indexWaypointsByType() end
  -- self.pacenoteWaypoints.postRemove = function() self:indexWaypointsByType() end
  -- self.pacenoteWaypoints.postCreate = function() self:indexWaypointsByType() end

  self.pacenoteWaypointsByType = {}

  self.prevNote = nil
  self.nextNote = nil

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

function C:getCornerEndWaypoint()
  local wpListForType = self.pacenoteWaypointsByType[editor_rallyEditor.wpTypeCornerEnd]
  if wpListForType then
    local k, v = next(wpListForType)
    return v
  else
    return nil
  end
end

function C:getDistanceMarkerWaypointsAfterEnd()
  local cornerEndFound = false
  local wps = {}

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == editor_rallyEditor.wpTypeCornerEnd then
      cornerEndFound = true 
    end

    if cornerEndFound and wp.waypointType == editor_rallyEditor.wpTypeDistanceMarker then
      table.insert(wps, wp)
    end
  end

  return wps
end

function C:getDistanceMarkerWaypointsBeforeStart()
  local wps = {}

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == editor_rallyEditor.wpTypeDistanceMarker then
      table.insert(wps, wp)
    elseif wp.waypointType == editor_rallyEditor.wpTypeCornerStart then
      break
    end
  end

  return wps
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

local function reverseList(list)
  local reversed = {}
  local count = #list
  for i = count, 1, -1 do
      table.insert(reversed, list[i])
  end
  return reversed
end

function C:setAdjacentNotes(prevNote, nextNote)
  self.prevNote = prevNote
  self.nextNote = nextNote
end

function C:clearAdjacentNotes()
  self:setAdjacentNotes(nil, nil)
end

function C:drawDebug(drawMode, clr, extraText)
  -- local wp = self:getCornerStartWaypoint()
  -- if wp then
  --   wp:drawDebug(self._drawMode, clr, extraText)
  -- end

  -- local linkClr = {0.2, 0.2, 0.2} -- gray
  -- local linkClr = {1.0, 1.0, 1.0} -- white
  local linkClr = {0, 1, 0} -- green
  local undistractClr = {0.2, 0.2, 0.2} -- gray
  local distClr = {1, 0.6, 0.2} -- orange

  -- drawMode = drawMode or self._drawMode
  drawMode = self._drawMode

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    -- wp:drawDebug(self._drawMode, clr, extraText)
    if drawMode == 'highlight' then
      local clr = nil
      if wp.waypointType == editor_rallyEditor.wpTypeCornerStart then
        clr = {0, 1, 0} -- green
        local cornerEnd = self:getCornerEndWaypoint()
        if cornerEnd then
          self:drawLink(wp, cornerEnd, linkClr)
        else
          log('W', logTag, 'pacenote "'..self.name..'" cornerEnd is nil')
        end
      elseif wp.waypointType == editor_rallyEditor.wpTypeCornerEnd then
        clr = {1, 0, 0} -- red
      elseif wp.waypointType == editor_rallyEditor.wpTypeFwdAudioTrigger then
        clr = {0, 0, 1} -- blue
        self:drawLink(wp, self:getCornerStartWaypoint(), clr)
      elseif wp.waypointType == editor_rallyEditor.wpTypeRevAudioTrigger then
        -- clr = {0, 0.5, 1} -- slightly more cyan than blue
        -- self:drawLink(wp, self:getCornerEndWaypoint(), clr)
      elseif wp.waypointType == editor_rallyEditor.wpTypeDistanceMarker then
        clr = distClr
        local cornerStartOrder = self:getCornerStartWaypoint().sortOrder
        local cornerEndOrder = self:getCornerEndWaypoint().sortOrder
        local wpOrder = wp.sortOrder
        local from = nil
        local to = nil

        if wpOrder < cornerStartOrder then
          from = wp
          local toFound = false
          for i,wp2 in ipairs(self.pacenoteWaypoints.sorted) do
            if not toFound then
              -- advance to the "from" waypoint
              if wp2.id == from.id then
                toFound = true
              end
            else
              -- once "from" is found, then find the next distanceMarker or cornerStart
              if wp2.waypointType == editor_rallyEditor.wpTypeCornerStart or wp2.waypointType == editor_rallyEditor.wpTypeDistanceMarker then
                to = wp2
                break
              end
            end
          end

          self:drawLink(from, to, clr)
          local textPos = (from.pos + to.pos) / 2
          local highlightDist = from._drawMode == 'highlight' or to._drawMode == 'highlight'
          local alpha = highlightDist and 1 or 0.5
          local dist = round(from.pos:distance(to.pos))
          debugDrawer:drawTextAdvanced(textPos,
            String(tostring(dist)..'m'),
            ColorF(1, 1, 1, alpha), true, false,
            ColorI(0, 0, 0, alpha * 255)
          )
        elseif wpOrder > cornerEndOrder then
          to = wp
          local fromFound = false
          for i,wp2 in ipairs(reverseList(self.pacenoteWaypoints.sorted)) do
            if not fromFound then
              -- advance to the "from" waypoint
              if wp2.id == to.id then
                fromFound = true
              end
            else
              -- once "from" is found, then find the next distanceMarker or cornerStart
              if wp2.waypointType == editor_rallyEditor.wpTypeCornerEnd or wp2.waypointType == editor_rallyEditor.wpTypeDistanceMarker then
                from = wp2
                break
              end
            end
          end

          self:drawLink(from, to, clr)
          local textPos = (from.pos + to.pos) / 2
          local highlightDist = from._drawMode == 'highlight' or to._drawMode == 'highlight'
          local alpha = highlightDist and 1 or 0.5
          local dist = round(from.pos:distance(to.pos))
          debugDrawer:drawTextAdvanced(textPos,
            String(tostring(dist)..'m'),
            ColorF(1, 1, 1, alpha), true, false,
            ColorI(0, 0, 0, alpha * 255)
          )
        else
          log('E', logTag, 'distance marker must be before cornerStart or after cornerEnd, not in between')
        end
      end
      wp:drawDebug(nil, clr, nil) -- wp._drawMode)
    elseif drawMode == 'undistract' then
      if wp.waypointType == 'cornerStart' then
        wp:drawDebug(nil, undistractClr, nil) -- wp._drawMode)
      end
    else
      if wp.waypointType == 'cornerStart' then
        wp:drawDebug(nil, nil, nil) -- wp._drawMode)
      end
    end
  end

  if self.prevNote then
    local clr = undistractClr

    local prevCornerStart = self.prevNote:getCornerStartWaypoint()
    local prevCornerEnd = self.prevNote:getCornerEndWaypoint()
    if prevCornerStart and prevCornerEnd then
      self:drawLink(prevCornerStart, prevCornerEnd, clr)
    end

    if prevCornerEnd then
      prevCornerEnd:drawDebug(nil, undistractClr, nil)
    end

    local selfCornerStart = self:getCornerStartWaypoint()

    local to = selfCornerStart
    local selfDmsBefore = self:getDistanceMarkerWaypointsBeforeStart()
    if #selfDmsBefore > 0 then
      to = selfDmsBefore[1]
    end

    local prevDms = self.prevNote:getDistanceMarkerWaypointsAfterEnd()
    for i,prevDm in ipairs(prevDms) do
      prevDm:drawDebug(nil, undistractClr, nil)
      local linkDm = prevDms[i+1]
      if linkDm then
        self:drawLink(prevDm, linkDm, clr)
      end
    end

    local from = prevCornerEnd
    if #prevDms > 0 then
      local linkDm = prevDms[1]
      self:drawLink(prevCornerEnd, linkDm, clr)
      from = prevDms[#prevDms]
    end

    clr = distClr
    if from and to then
      self:drawLink(from, to, clr)
      local textPos = (from.pos + to.pos) / 2
      local highlightDist = from._drawMode == 'highlight' or to._drawMode == 'highlight'
      local alpha = highlightDist and 1 or 0.5
      local dist = round(from.pos:distance(to.pos))
      debugDrawer:drawTextAdvanced(textPos,
        String(tostring(dist)..'m'),
        ColorF(1, 1, 1, alpha), true, false,
        ColorI(0, 0, 0, alpha * 255)
      )
    end
  end

  if self.nextNote then
    local clr = undistractClr

    local nextCornerStart = self.nextNote:getCornerStartWaypoint()
    local nextCornerEnd = self.nextNote:getCornerEndWaypoint()

    -- if nextCornerEnd then
      -- self:drawLink(nextCornerStart, nextCornerEnd, clr)
    -- end

    -- nextCornerStart:drawDebug(nil, undistractClr, nil)

    local from = self:getCornerEndWaypoint()
    local selfDmsAfter = self:getDistanceMarkerWaypointsAfterEnd()

    if #selfDmsAfter > 0 then
      from = selfDmsAfter[#selfDmsAfter]
    end

    local to = nextCornerStart

    local nextDmsBefore = self.nextNote:getDistanceMarkerWaypointsBeforeStart()
    for i,nextDm in ipairs(nextDmsBefore) do
      nextDm:drawDebug(nil, undistractClr, nil)
      local linkDm = nextDmsBefore[i+1]
      if linkDm then
        self:drawLink(nextDm, linkDm, clr)
      end
    end
    if #nextDmsBefore > 0 then
      to = nextDmsBefore[1]
      self:drawLink(nextDmsBefore[#nextDmsBefore], nextCornerStart, clr)
    end

    clr = distClr
    if from and to then
      self:drawLink(from, to, clr)
      local textPos = (from.pos + to.pos) / 2
      local highlightDist = from._drawMode == 'highlight' or to._drawMode == 'highlight'
      local alpha = highlightDist and 1 or 0.5
      local dist = round(from.pos:distance(to.pos))
      debugDrawer:drawTextAdvanced(textPos,
        String(tostring(dist)..'m'),
        ColorF(1, 1, 1, alpha), true, false,
        ColorI(0, 0, 0, alpha * 255)
      )
    end
  end
end

function C:drawLink(from, to, clr)
  debugDrawer:drawSquarePrism(
    from.pos,
    to.pos,
    Point2F(1,1),
    Point2F(0,0),
    ColorF(clr[1],clr[2],clr[3],0.25)
  )
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end