-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')

local C = {}
local modes = {"manual","navgraph"}
local logTag = 'aipacenotes_pacenote'

function C:init(notebook, name, forceId)
  self.notebook = notebook
  self.id = forceId or notebook:getNextUniqueIdentifier()
  self.name = name or "Pacenote " .. self.id
  -- self.note = ""
  self.notes = {}
  self.segment = -1
  self.pacenoteWaypoints = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "pacenoteWaypoints",
    self,
    require('/lua/ge/extensions/gameplay/notebook/pacenoteWaypoint')
  )

  -- self.pacenoteWaypoints.postClear = function() self:indexWaypointsByType() end
  -- self.pacenoteWaypoints.postRemove = function() self:indexWaypointsByType() end
  -- self.pacenoteWaypoints.postCreate = function() self:indexWaypointsByType() end

  -- self.pacenoteWaypointsByType = {}

  -- self.prevNote = nil
  -- self.nextNote = nil

  -- self._drawMode = 'none'
  self.sortOrder = 999999
end

-- used by pacenoteWaypoints.lua
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

function C:setAllRadii(newRadius, wpType)
  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if not wpType or wp.waypointType == wpType then
      wp.radius = newRadius
    end
  end
end

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
    notes = self.notes,
    segment = self.segment,
    pacenoteWaypoints = self.pacenoteWaypoints:onSerialize(),
  }

  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.name = data.name
  self.notes = data.notes
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

local function textForDrawDebug(wp, cs_prefix, note_text, dist_text)
  local txt = ''
  if wp.waypointType == waypointTypes.wpTypeCornerStart then
    if cs_prefix then
      txt = '['..waypointTypes.shortenWaypointType(wp.waypointType)..'] ' .. note_text
    else
      txt = note_text
    end
  elseif wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger or wp.waypointType == waypointTypes.wpTypeRevAudioTrigger then
    txt = '['..waypointTypes.shortenWaypointType(wp.waypointType)
    if dist_text then
      txt = txt..','..dist_text
    end
    txt = txt..']'
  else
    txt = '['..waypointTypes.shortenWaypointType(wp.waypointType) ..']'
  end
  return txt
end

local function drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
  if not wp then return end

  local hover = hover_wp_id and hover_wp_id == wp.id
  local cs_prefix = nil
  local clr = nil
  -- local shapeAlpha = alpha
  -- local textAlpha = alpha

  -- determine if the waypoint is selected
  if selected_wp_id and selected_wp_id == wp.id then
    wp_drawMode = 'selected_wp'
  end

  -- enumerate all wp_drawModes
  if wp_drawMode == 'selected_wp' then
    cs_prefix = true
    clr = wp:colorForWpType()
    -- shapeAlpha = 0.8
    -- textAlpha = 0.8
  elseif wp_drawMode == 'selected_pn' then
    cs_prefix = true
    clr = wp:colorForWpType()
    -- shapeAlpha = 0.8
    -- textAlpha = 0.8
  elseif wp_drawMode == 'normal' then
    cs_prefix = false
    clr = rainbowColor(#wp.pacenote.notebook.pacenotes.sorted, (wp.pacenote.sortOrder-1), 1)
    shapeAlpha = 0.25
    textAlpha = 0.5
  end

  local text = textForDrawDebug(wp, cs_prefix, note_text, dist_text)

  wp:drawDebug(hover, text, clr, shapeAlpha, textAlpha)
end

-- function C:drawDebugSelectedWaypoint(note_text, hover_wp_id, selected_wp_id)
--   for _,wp in ipairs(self:getAudioTriggerWaypoints()) do
--     drawWaypoint(wp, 'selected_pn', note_text, hover_wp_id, selected_wp_id)
--   end
--   for _,wp in ipairs(self:getDistanceMarkerWaypointsBeforeStart()) do
--     drawWaypoint(wp, 'selected_pn', note_text, hover_wp_id, selected_wp_id)
--   end
--   drawWaypoint(self:getCornerStartWaypoint(), 'selected_pn', note_text, hover_wp_id, selected_wp_id)
--   drawWaypoint(self:getCornerEndWaypoint(), 'selected_pn', note_text, hover_wp_id, selected_wp_id)
--   for _,wp in ipairs(self:getDistanceMarkerWaypointsAfterEnd()) do
--     drawWaypoint(wp, 'selected_pn', note_text, hover_wp_id, selected_wp_id)
--   end
-- end

local function drawLink2(from, to, clr, alpha)
  debugDrawer:drawSquarePrism(
    from.pos,
    to.pos,
    Point2F(1,1),
    Point2F(0.25,0.25),
    ColorF(clr[1],clr[2],clr[3],alpha)
  )
end

local function prettyDistanceStringMeters(from, to)
  local dist = round(from.pos:distance(to.pos))
  return tostring(dist)..'m' --'->['..waypointTypes.shortenWaypointType(to.waypointType)..']'
end

local function drawLinkLabel(from, to, text, alpha, clr_fg, clr_bg)
  local textPos = (from.pos + to.pos) / 2

  clr_fg = clr_fg or {1,1,1}
  clr_bg = clr_bg or {0,0,0}

  debugDrawer:drawTextAdvanced(textPos,
    String(text),
    ColorF(clr_fg[1],clr_fg[2],clr_fg[3], alpha),
    true,
    false,
    ColorI(clr_bg[1]*255,clr_bg[2]*255,clr_bg[3]*255, alpha * 255)
  )
end

function C:drawDebugSelected(note_text, hover_wp_id)
  local shapeAlpha = 0.8
  local textAlpha = 1.0
  local dist_text = nil
  local wp_drawMode = 'selected_pn'

  for _,wp in ipairs(self:getAudioTriggerWaypoints()) do
    dist_text = prettyDistanceStringMeters(wp, self:getCornerStartWaypoint())
    drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
    drawLink2(wp, self:getCornerStartWaypoint(), {0,0,1.0}, shapeAlpha)
  end

  local nextwp = self:getCornerStartWaypoint()
  for _,wp in ipairs(self:getDistanceMarkerWaypointsBeforeStart()) do
    drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
    drawLink2(wp, nextwp, {1.0,0.64,0}, shapeAlpha)
    local distStr = prettyDistanceStringMeters(wp, nextwp)
    drawLinkLabel(wp, nextwp, distStr, textAlpha)
    nextwp = wp
  end

  drawWaypoint(self:getCornerStartWaypoint(), wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
  drawWaypoint(self:getCornerEndWaypoint(), wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
  drawLink2(self:getCornerStartWaypoint(), self:getCornerEndWaypoint(), {0.25,0.25,0.25}, shapeAlpha)

  local prevwp = self:getCornerEndWaypoint()
  for _,wp in ipairs(self:getDistanceMarkerWaypointsAfterEnd()) do
    drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
    drawLink2(prevwp, wp, {1.0,0.64,0}, shapeAlpha)
    local distStr = prettyDistanceStringMeters(prevwp, wp)
    drawLinkLabel(prevwp, wp, distStr, textAlpha)
    prevwp = wp
  end
end

function C:drawDebugPrevious(note_text, hover_wp_id)
  local shapeAlpha = 0.25
  local textAlpha = 0.5
  local dist_text = nil
  local wp_drawMode = 'selected_pn'

  local clr_orange = {1.0,0.64,0}
  local clr_blue = {0,0,1.0}
  local clr_grey = {0.25,0.25,0.25}

  for _,wp in ipairs(self:getAudioTriggerWaypoints()) do
    -- dist_text = prettyDistanceStringMeters(wp, self:getCornerStartWaypoint())
    drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
    drawLink2(wp, self:getCornerStartWaypoint(), clr_blue, shapeAlpha)
    -- drawLinkLabel(wp, self:getCornerStartWaypoint(), alpha_dist_label)
  end

  -- local nextwp = self:getCornerStartWaypoint()
  -- for _,wp in ipairs(self:getDistanceMarkerWaypointsBeforeStart()) do
  --   drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id)
  --   drawLink2(wp, nextwp, clr_orange, alpha)
  --   drawLinkLabel(wp, nextwp, alpha_dist_label)
  --   nextwp = wp
  -- end

  drawWaypoint(self:getCornerStartWaypoint(), wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
  drawWaypoint(self:getCornerEndWaypoint(), wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
  drawLink2(self:getCornerStartWaypoint(), self:getCornerEndWaypoint(), clr_grey, shapeAlpha)

  local prevwp = self:getCornerEndWaypoint()
  for _,wp in ipairs(self:getDistanceMarkerWaypointsAfterEnd()) do
    drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, shapeAlpha, textAlpha)
    drawLink2(prevwp, wp, clr_orange, shapeAlpha)
    local distStr = prettyDistanceStringMeters(prevwp, wp)
    drawLinkLabel(prevwp, wp, distStr, textAlpha)
    prevwp = wp
  end
end

function C:drawLinkToPacenote(to_pacenote)
  local clr_orange = {1.0,0.64,0}
  local clr_pink = {1.0,0.0,1.0}
  local clr = clr_pink
  local shapeAlpha = 0.8
  local textAlpha = 1.0
  
  local from_wp = self:getCornerEndWaypoint()
  local afterEnd = self:getDistanceMarkerWaypointsAfterEnd()
  if #afterEnd > 0 then
    from_wp = afterEnd[#afterEnd]
  end


  local to_wp = to_pacenote:getCornerStartWaypoint()
  local before_start = to_pacenote:getDistanceMarkerWaypointsBeforeStart()
  if #before_start > 0 then
    to_wp = before_start[1]
  end

  local distStr = prettyDistanceStringMeters(from_wp, to_wp)
  distStr = '<'..distStr..'>'

  drawLink2(from_wp, to_wp, clr, shapeAlpha)
  drawLinkLabel(from_wp, to_wp, distStr, textAlpha, {0,0,0}, clr)
end

function C:drawDebugCustom(drawMode, note_language, hover_wp_id, selected_wp_id)
  local note_text = self.notes[note_language] or ''

  if drawMode == 'selected' then
    -- self:drawDebugSelected(note_text, hover_wp_id, selected_wp_id)
  -- elseif drawMode == 'selected_pacenote' then
    self:drawDebugSelected(note_text, hover_wp_id, selected_wp_id)
  elseif drawMode == 'previous' then
    self:drawDebugPrevious(note_text, hover_wp_id, selected_wp_id)
  elseif drawMode == 'normal' then
    drawWaypoint(self:getCornerStartWaypoint(), 'normal', note_text, dist_text, hover_wp_id, nil, 0.25, 0.5)
    -- local wp_drawMode = 'normal'

    -- local clr = nil
    -- local extraTextSuffix = nil
    -- local extraTextPrefix = nil -- '*'
    -- local textAlpha = nil -- 1.0
    -- local drawArrow = false
    -- local hover = hover_wp_id and hover_wp_id == cs.id
    -- cs:drawDebug(wp_drawMode, clr, extraTextSuffix, extraTextPrefix, textAlpha, drawArrow, hover, note_language)
  end

  -- step 1 determine the pacenote's state
  -- - normal -> rainbow
  -- - hover -> white
  -- - selected -> white with less alpha
  -- local drawMode = 'normal'

  -- local isWpSelected = selected_wp_id and cs and selected_wp_id == cs.id
  -- if isWpSelected then
  --   drawMode = 'selected'
  -- end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end