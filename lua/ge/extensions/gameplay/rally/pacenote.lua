-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local waypointTypes = require('/lua/ge/extensions/gameplay/rally/waypointTypes')

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

  -- self.pacenoteWaypointsByType = {}

  self.prevNote = nil
  self.nextNote = nil

  self._drawMode = 'none'
  self.sortOrder = 999999
end

function C:getNextUniqueIdentifier()
  return self.notebook:getNextUniqueIdentifier()
end

-- function C:indexWaypointsByType()
--   self.pacenoteWaypointsByType = {}

--   for i, wp in pairs(self.pacenoteWaypoints.objects) do
--     local wpType = wp.waypointType
--     if self.pacenoteWaypointsByType[wpType] == nil then
--       self.pacenoteWaypointsByType[wpType] = {}
--     end
--     table.insert(self.pacenoteWaypointsByType[wpType], wp)
--   end
-- end

function C:validateWaypointTypes()
  -- TODO
  return true
end

function C:getCornerStartWaypoint()
  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == waypointTypes.wpTypeCornerStart then
      return wp
    end
  end
  return nil
end

function C:getCornerEndWaypoint()
  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == waypointTypes.wpTypeCornerEnd then
      return wp
    end
  end
  return nil
end

function C:getAudioTriggerWaypoints()
  local wps = {}

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
      table.insert(wps, wp)
    elseif wp.waypointType == waypointTypes.wpTypeRevAudioTrigger then
      table.insert(wps, wp)
    end
  end

  return wps
end

function C:getDistanceMarkerWaypointsAfterEnd()
  local cornerEndFound = false
  local wps = {}

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == waypointTypes.wpTypeCornerEnd then
      cornerEndFound = true 
    end

    if cornerEndFound and wp.waypointType == waypointTypes.wpTypeDistanceMarker then
      table.insert(wps, wp)
    end
  end

  return wps
end

function C:getDistanceMarkerWaypointsBeforeStart()
  local wps = {}

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == waypointTypes.wpTypeDistanceMarker then
      table.insert(wps, wp)
    elseif wp.waypointType == waypointTypes.wpTypeCornerStart then
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

  -- self:indexWaypointsByType()
end


function C:setNavgraph(navgraphName, fallback)
  log('W', logTag, 'setNavgraph() not implemented')
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
  local wp = self:getActiveFwdAudioTrigger()
  if not wp then
    -- log('D', logTag, 'couldnt find waypoint for intersectCorners()')
    return false
  -- else
  --   log('D', logTag, 'found wp')
  end
  return wp:intersectCorners(fromCorners, toCorners)
end

function C:getActiveFwdAudioTrigger()
  -- local wpListForType = self.pacenoteWaypointsByType[waypointTypes.wpTypeFwdAudioTrigger]
  -- if wpListForType then
    -- for i,wp in pairs(wpListForType) do
    for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
      if wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger then -- TODO and wp.name == 'curr' then
        -- log('D', 'wtf', 'wp.name='..wp.name)
        return wp
      end
    end
  -- else
    -- log('W', logTag, 'no fwd audio waypoints found')
    return nil
  -- end
end

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

  local linkClr = {0, 1, 0} -- green
  local undistractClr = {0.2, 0.2, 0.2} -- gray
  local undistractClrEmphasis = {0.0, 0.0, 0.0} -- gray
  local distClr = {1, 0.6, 0.2} -- orange

  -- drawMode = drawMode or self._drawMode
  drawMode = self._drawMode


  ----------------------------------------------------------------------------------------
  -- draw nodes for the current pacenote
  --

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    -- wp:drawDebug(self._drawMode, clr, extraText)
    if drawMode == 'highlight' then
      local clr = nil
      if wp.waypointType == waypointTypes.wpTypeCornerStart then
        clr = linkClr
        local cornerEnd = self:getCornerEndWaypoint()
        if cornerEnd then
          self:drawLink(wp, cornerEnd, clr)
        else
          log('W', logTag, 'pacenote "'..self.name..'" cornerEnd is nil')
        end
      elseif wp.waypointType == waypointTypes.wpTypeCornerEnd then
        clr = {1, 0, 0} -- red
        -- log('D', 'wtf', 'HEREa')
        -- log('D', 'wtf', 'ce='..wp.name)
        -- wp:drawDebug(nil, clr, nil) -- wp._drawMode)
      elseif wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
        clr = {0, 0, 1} -- blue
        self:drawLink(wp, self:getCornerStartWaypoint(), clr)
      elseif wp.waypointType == waypointTypes.wpTypeRevAudioTrigger then
        -- clr = {0, 0.5, 1} -- slightly more cyan than blue
        -- self:drawLink(wp, self:getCornerEndWaypoint(), clr)
      elseif wp.waypointType == waypointTypes.wpTypeDistanceMarker then
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
              if wp2.waypointType == waypointTypes.wpTypeCornerStart or wp2.waypointType == waypointTypes.wpTypeDistanceMarker then
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
              if wp2.waypointType == waypointTypes.wpTypeCornerEnd or wp2.waypointType == waypointTypes.wpTypeDistanceMarker then
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
      -- if wp.waypointType == waypointTypes.wpTypeCornerEnd then
        -- log('D', 'wtf', 'drawing wp name='..wp.name..' clr='..dumps(clr))
        wp:drawDebug(nil, clr, nil, '*', 1.0) -- wp._drawMode)
        -- log('D', 'wtf', '--------------------------------------------------------------------------------')
      -- end
    -- elseif drawMode == 'undistract' then
    --   if wp.waypointType == 'cornerStart' then
    --     wp:drawDebug(nil, undistractClr, nil) -- wp._drawMode)
    --   end
    -- else
    --   if wp.waypointType == 'cornerStart' then
    --     wp:drawDebug(nil, nil, nil) -- wp._drawMode)
    --   end
    end
  end


  ----------------------------------------------------------------------------------------
  -- draw a couple nodes from the previous pacenote
  --

  if self.prevNote then
    local clr = undistractClr

    local prevCornerStart = self.prevNote:getCornerStartWaypoint()
    local prevCornerEnd = self.prevNote:getCornerEndWaypoint()
    if prevCornerStart and prevCornerEnd then
      self:drawLink(prevCornerStart, prevCornerEnd, clr)
    end

    -- draw a more dim version of audio trigger waypoints.
    local prevTriggers = self.prevNote:getAudioTriggerWaypoints()
    local clrDarkBlue = {0, 0, 0.3}
    for i,wp in ipairs(prevTriggers) do
      self:drawLink(wp, prevCornerStart, clrDarkBlue)
      wp:drawDebug(nil, clrDarkBlue)
    end

    prevCornerStart:drawDebug(nil, undistractClr, nil, '['.. waypointTypes.shortenWaypointType(waypointTypes.wpTypeCornerStart) ..']')
    prevCornerEnd:drawDebug(nil, undistractClr, nil) -- maybe use undistractClrEmphasis here

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
        String('['..waypointTypes.shortenWaypointType(from.waypointType)..']->'..tostring(dist)..'m'),
        ColorF(1, 1, 1, alpha), true, false,
        ColorI(0, 0, 0, alpha * 255)

      )
    end
  end

  ----------------------------------------------------------------------------------------
  -- draw a couple nodes from the next pacenote
  --
  if self.nextNote then
    local nextCornerStart = self.nextNote:getCornerStartWaypoint()
    local nextCornerEnd = self.nextNote:getCornerEndWaypoint()

    if nextCornerStart and nextCornerEnd then
      self:drawLink(nextCornerStart, nextCornerEnd, undistractClrEmphasis)
    end

    if nextCornerStart then
      nextCornerStart:drawDebug(nil, undistractClr, nil, '['.. waypointTypes.shortenWaypointType(waypointTypes.wpTypeCornerStart) ..']')
    end
    if nextCornerEnd then
      nextCornerEnd:drawDebug(nil, undistractClr, nil)
    end

    -- draw a more dim version of audio trigger waypoints.
    local nextTriggers = self.nextNote:getAudioTriggerWaypoints()
    local clrDarkBlue = {0, 0, 0.3}
    for i,wp in ipairs(nextTriggers) do
      if nextCornerStart then
        self:drawLink(wp, nextCornerStart, clrDarkBlue)
      end
      wp:drawDebug(nil, clrDarkBlue)
    end

    local from = self:getCornerEndWaypoint()
    local selfDmsAfter = self:getDistanceMarkerWaypointsAfterEnd()

    if #selfDmsAfter > 0 then
      from = selfDmsAfter[#selfDmsAfter]
    end

    local to = nextCornerStart

    local clr = undistractClrEmphasis
    local nextDmsBefore = self.nextNote:getDistanceMarkerWaypointsBeforeStart()
    for i,nextDm in ipairs(nextDmsBefore) do
      nextDm:drawDebug(nil, clr, nil)
      local linkDm = nextDmsBefore[i+1]
      if linkDm then
        self:drawLink(nextDm, linkDm, clr)
      end
    end
    if #nextDmsBefore > 0 then
      to = nextDmsBefore[1]
      if nextCornerStart then
        self:drawLink(nextDmsBefore[#nextDmsBefore], nextCornerStart, clr)
      end
    -- else
      -- to:drawDebug(nil, clr, nil)
    end

    clr = distClr
    if from and to then
      self:drawLink(from, to, clr)
      local textPos = (from.pos + to.pos) / 2
      local highlightDist = from._drawMode == 'highlight' or to._drawMode == 'highlight'
      local alpha = highlightDist and 1 or 0.5
      local dist = round(from.pos:distance(to.pos))
      debugDrawer:drawTextAdvanced(textPos,
        String(tostring(dist)..'m->['..waypointTypes.shortenWaypointType(to.waypointType)..']'),
        ColorF(1, 1, 1, alpha), true, false,
        ColorI(0, 0, 0, alpha * 255)
      )
    end
  end



  ----------------------------------------------------------------------------------------
  -- draw the rest of the pacenotes.
  --

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if not ((self.nextNote and wp.pacenote.id == self.nextNote.id) and (self.prevNote and wp.pacenote.id == self.prevNote.id)) then
      if drawMode == 'highlight' then
        -- pass, already taken care of in the above loop.
      elseif drawMode == 'undistract' then
        if wp.waypointType == 'cornerStart' then
          -- wp:drawDebug(nil, undistractClr, nil) -- wp._drawMode)
        end
      else
        if wp.waypointType == 'cornerStart' then
          wp:drawDebug(nil, nil, nil) -- wp._drawMode)
        end
      end
    end
  end
end

function C:drawLink(from, to, clr)
  debugDrawer:drawSquarePrism(
    from.pos,
    to.pos,
    Point2F(1,1),
    Point2F(0.25,0.25),
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