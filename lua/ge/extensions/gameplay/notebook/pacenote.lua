-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')

local C = {}
-- local modes = {"manual","navgraph"}
local logTag = 'aipacenotes_pacenote'

local clr_white = {1.0, 1.0, 1.0}
local clr_black = {0.0, 0.0, 0.0}
local clr_orange = {1.0, 0.64, 0.0}
local clr_blue = {0.0, 0.0, 1.0}
local clr_grey = {0.25, 0.25, 0.25}
local clr_pink = {1.0, 0.0, 1.0}

local shapeAlpha_normal = 0.25
local textAlpha_normal = 0.5
local shapeAlpha_selected = 0.8
local textAlpha_selected = 1.0
local shapeAlpha_previous = 0.25
local textAlpha_previous = 0.5
local shapeAlpha_internote_link = 0.8
local textAlpha_internote_link = 1.0

local linkHeightRadiusShinkFactor = 0.5
local linkFromWidth = 1.0
local linkToWidth = 0.25

function C:init(notebook, name, forceId)
  self.notebook = notebook
  self.id = forceId or notebook:getNextUniqueIdentifier()
  self.name = name or ("Pacenote " .. self.id)
  self.note = nil -- used for interfacing with existing flowgraph race code
  self.notes = {}
  self.segment = -1
  self.pacenoteWaypoints = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "pacenoteWaypoints",
    self,
    require('/lua/ge/extensions/gameplay/notebook/pacenoteWaypoint')
  )

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

function C:setFieldsForFlowgraph(lang)
  self.note = self.notes[lang]
  local wp_trigger = self:getActiveFwdAudioTrigger()
  if not wp_trigger then
    log('E', logTag, 'audio trigger not found')
  end
  self.radius = wp_trigger.radius
  self.pos = wp_trigger.pos
  self.normal = wp_trigger.normal
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

function C:getDistanceMarkerWaypointsInBetween()
  local cornerStartFound = false
  local wps = {}

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == waypointTypes.wpTypeCornerStart then
      cornerStartFound = true
    elseif wp.waypointType == waypointTypes.wpTypeCornerEnd then
      break
    end

    if cornerStartFound and wp.waypointType == waypointTypes.wpTypeDistanceMarker then
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

function C:getDistanceMarkerWaypoints()
  local wps = {}

  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == waypointTypes.wpTypeDistanceMarker then
      table.insert(wps, wp)
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
end

function C:setNavgraph(navgraphName, fallback)
  log('W', logTag, 'setNavgraph() not implemented')
end

function C:intersectCorners(fromCorners, toCorners)
  local wp = self:getActiveFwdAudioTrigger()
  if not wp then
    return false
  end
  return wp:intersectCorners(fromCorners, toCorners)
end

function C:getActiveFwdAudioTrigger()
  for i,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger then -- TODO and wp.name == 'curr' then
      return wp
    end
  end
  return nil
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
  elseif wp.waypointType == waypointTypes.wpTypeCornerEnd or wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger or wp.waypointType == waypointTypes.wpTypeRevAudioTrigger then
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

local function drawWaypoint(wp, wp_drawMode, note_text, dist_text,
                            hover_wp_id, selected_wp_id,
                            shapeAlpha, textAlpha)

  if not wp then return end

  local hover = hover_wp_id and hover_wp_id == wp.id
  local cs_prefix = nil
  local clr = nil

  -- determine if the waypoint is selected
  if selected_wp_id and selected_wp_id == wp.id then
    wp_drawMode = 'selected_wp'
  end

  -- enumerate all wp_drawModes
  if wp_drawMode == 'selected_wp' then
    cs_prefix = true
    clr = clr_white
  elseif wp_drawMode == 'selected_pn' then
    cs_prefix = true
    clr = wp:colorForWpType()
  elseif wp_drawMode == 'normal' then
    cs_prefix = false
    clr = rainbowColor(#wp.pacenote.notebook.pacenotes.sorted, (wp.pacenote.sortOrder-1), 1)
    shapeAlpha = shapeAlpha_normal
    textAlpha = textAlpha_normal
  end

  local text = textForDrawDebug(wp, cs_prefix, note_text, dist_text)
  wp:drawDebug(hover, text, clr, shapeAlpha, textAlpha)
end

local function drawLink2(from, to, clr, alpha)
  if not (from and to) then return end
   -- could also set based on radius, but there are clipping issues.
  local fromHeight = from.radius * linkHeightRadiusShinkFactor
  local toHeight = to.radius * linkHeightRadiusShinkFactor
  debugDrawer:drawSquarePrism(
    from.pos,
    to.pos,
    Point2F(fromHeight, linkFromWidth),
    Point2F(toHeight, linkToWidth),
    ColorF(clr[1],clr[2],clr[3],alpha)
  )
end

local function prettyDistanceStringMeters(from, to)
  if not (from and to) then return "?m" end
  local dist = round(from.pos:distance(to.pos))
  return tostring(dist)..'m' --'->['..waypointTypes.shortenWaypointType(to.waypointType)..']'
end

local function drawLinkLabel(from, to, text, alpha, clr_fg, clr_bg)
  -- make the position in the middle of from and to.
  local textPos = (from.pos + to.pos) / 2

  clr_fg = clr_fg or clr_white
  clr_bg = clr_bg or clr_black

  debugDrawer:drawTextAdvanced(textPos,
    String(text),
    ColorF(clr_fg[1],clr_fg[2],clr_fg[3], alpha),
    true,
    false,
    ColorI(clr_bg[1]*255,clr_bg[2]*255,clr_bg[3]*255, alpha * 255)
  )
end

function C:drawDebugSelected(note_text, hover_wp_id, selected_wp_id, pacenote_next)
  local dist_text = nil
  local wp_drawMode = 'selected_pn'

  -- draw the fwd audio triggers and link them to CS.
  if editor_rallyEditor.getPrefShowAudioTriggers() then
    for _,wp in ipairs(self:getAudioTriggerWaypoints()) do
      dist_text = prettyDistanceStringMeters(wp, self:getCornerStartWaypoint())
      drawWaypoint(wp, wp_drawMode, note_text, dist_text,
        hover_wp_id, selected_wp_id, shapeAlpha_selected, textAlpha_selected)
      drawLink2(wp, self:getCornerStartWaypoint(), clr_blue, shapeAlpha_selected)
    end
    dist_text = nil
  end

  -- draw beforeStart distance markers, draw link, draw link distance label
  if editor_rallyEditor.getPrefShowDistanceMarkers() then
    local nextwp = self:getCornerStartWaypoint()
    for _,wp in ipairs(self:getDistanceMarkerWaypointsBeforeStart()) do
      drawWaypoint(wp, wp_drawMode, note_text, dist_text,
        hover_wp_id, selected_wp_id, shapeAlpha_selected, textAlpha_selected)
      drawLink2(wp, nextwp, clr_orange, shapeAlpha_selected)
      local distStr = prettyDistanceStringMeters(wp, nextwp)
      drawLinkLabel(wp, nextwp, distStr, textAlpha_selected)
      nextwp = wp
    end
  end

  -- draw the CS
  drawWaypoint(self:getCornerStartWaypoint(), wp_drawMode, note_text, dist_text,
    hover_wp_id, selected_wp_id, shapeAlpha_selected, textAlpha_selected)

  -- draw the distance markers, links, and labels, that are between CS and CE
  local prevwp = self:getCornerStartWaypoint()
  local prevIsCS = true
  for _,wp in ipairs(self:getDistanceMarkerWaypointsInBetween()) do
    drawWaypoint(wp, wp_drawMode, note_text, dist_text,
      hover_wp_id, selected_wp_id, shapeAlpha_selected, textAlpha_selected)
    drawLink2(prevwp, wp, clr_orange, shapeAlpha_selected)
    local distStr = prettyDistanceStringMeters(prevwp, wp)
    drawLinkLabel(prevwp, wp, distStr, textAlpha_selected, clr_black, clr_orange)
    prevwp = wp
    prevIsCS = false
  end

  -- draw the CE
  if pacenote_next then
    dist_text = prettyDistanceStringMeters(self:getCornerEndWaypoint(), pacenote_next:waypointForBeforeLink())
  end
  drawWaypoint(self:getCornerEndWaypoint(), wp_drawMode, note_text, dist_text,
    hover_wp_id, selected_wp_id, shapeAlpha_selected, textAlpha_selected)
  dist_text = nil

  -- draw the link into CE depending on some logic.
  if prevIsCS then
    drawLink2(prevwp, self:getCornerEndWaypoint(), clr_grey, shapeAlpha_selected)
  else
    drawLink2(prevwp, self:getCornerEndWaypoint(), clr_orange, shapeAlpha_selected)
    local distStr = prettyDistanceStringMeters(prevwp, self:getCornerEndWaypoint())
    drawLinkLabel(prevwp, self:getCornerEndWaypoint(), distStr, textAlpha_selected, clr_black, clr_orange)
  end

  -- draw the distance markers after CE, links, labels.
  if editor_rallyEditor.getPrefShowDistanceMarkers() then
    local prevwp = self:getCornerEndWaypoint()
    for _,wp in ipairs(self:getDistanceMarkerWaypointsAfterEnd()) do
      drawWaypoint(wp, wp_drawMode, note_text, dist_text,
        hover_wp_id, selected_wp_id, shapeAlpha_selected, textAlpha_selected)
      drawLink2(prevwp, wp, clr_orange, shapeAlpha_selected)
      local distStr = prettyDistanceStringMeters(prevwp, wp)
      drawLinkLabel(prevwp, wp, distStr, textAlpha_selected)
      prevwp = wp
    end
  end
end

function C:drawDebugPrevious(note_text, hover_wp_id)
  local dist_text = nil
  local wp_drawMode = 'selected_pn'
  local selected_wp_id = nil

  for _,wp in ipairs(self:getAudioTriggerWaypoints()) do
    -- dist_text = prettyDistanceStringMeters(wp, self:getCornerStartWaypoint())
    drawWaypoint(wp, wp_drawMode, note_text, dist_text,
      hover_wp_id, selected_wp_id, shapeAlpha_previous, textAlpha_previous)
    drawLink2(wp, self:getCornerStartWaypoint(), clr_blue, shapeAlpha_previous)
    -- drawLinkLabel(wp, self:getCornerStartWaypoint(), alpha_dist_label)
  end

  -- local nextwp = self:getCornerStartWaypoint()
  -- for _,wp in ipairs(self:getDistanceMarkerWaypointsBeforeStart()) do
  --   drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id)
  --   drawLink2(wp, nextwp, clr_orange, alpha)
  --   drawLinkLabel(wp, nextwp, alpha_dist_label)
  --   nextwp = wp
  -- end

  drawWaypoint(self:getCornerStartWaypoint(), wp_drawMode, note_text, dist_text,
    hover_wp_id, selected_wp_id, shapeAlpha_previous, textAlpha_previous)
  drawWaypoint(self:getCornerEndWaypoint(), wp_drawMode, note_text, dist_text,
    hover_wp_id, selected_wp_id, shapeAlpha_previous, textAlpha_previous)
  drawLink2(self:getCornerStartWaypoint(), self:getCornerEndWaypoint(), clr_grey, shapeAlpha_previous)

  local prevwp = self:getCornerEndWaypoint()
  for _,wp in ipairs(self:getDistanceMarkerWaypointsAfterEnd()) do
    drawWaypoint(wp, wp_drawMode, note_text, dist_text,
      hover_wp_id, selected_wp_id, shapeAlpha_previous, textAlpha_previous)
    drawLink2(prevwp, wp, clr_orange, shapeAlpha_previous)
    local distStr = prettyDistanceStringMeters(prevwp, wp)
    drawLinkLabel(prevwp, wp, distStr, textAlpha_previous)
    prevwp = wp
  end
end

function C:waypointForBeforeLink()
  local to_wp = self:getCornerStartWaypoint()
  local before_start = self:getDistanceMarkerWaypointsBeforeStart()
  if #before_start > 0 then
    to_wp = before_start[1]
  end
  return to_wp
end

function C:waypointForAfterLink()
  local from_wp = self:getCornerEndWaypoint()
  local afterEnd = self:getDistanceMarkerWaypointsAfterEnd()
  if #afterEnd > 0 then
    from_wp = afterEnd[#afterEnd]
  end
  return from_wp
end

function C:drawLinkToPacenote(to_pacenote)
  local clr = clr_pink

  -- local from_wp = self:getCornerEndWaypoint()
  -- local afterEnd = self:getDistanceMarkerWaypointsAfterEnd()
  -- if #afterEnd > 0 then
  --   from_wp = afterEnd[#afterEnd]
  -- end

  local from_wp = self:waypointForAfterLink()

  -- local to_wp = to_pacenote:getCornerStartWaypoint()
  -- local before_start = to_pacenote:getDistanceMarkerWaypointsBeforeStart()
  -- if #before_start > 0 then
  --   to_wp = before_start[1]
  -- end

  local to_wp = to_pacenote:waypointForBeforeLink()

  local distStr = prettyDistanceStringMeters(from_wp, to_wp)
  distStr = '<'..distStr..'>'

  drawLink2(from_wp, to_wp, clr, shapeAlpha_internote_link)
  drawLinkLabel(from_wp, to_wp, distStr, textAlpha_internote_link, clr_black, clr)
end

function C:drawDebugCustom(drawMode, note_language, hover_wp_id, selected_wp_id, pacenote_next)
  local note_text = self.notes[note_language] or ''

  if drawMode == 'selected' then
    self:drawDebugSelected(note_text, hover_wp_id, selected_wp_id, pacenote_next)
  elseif drawMode == 'previous' then
    self:drawDebugPrevious(note_text, hover_wp_id)
  elseif drawMode == 'normal' then
    local dist_text = nil
    drawWaypoint(self:getCornerStartWaypoint(), 'normal', note_text, dist_text,
      hover_wp_id, nil, shapeAlpha_normal, textAlpha_normal)
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

local function calculateWaypointsCentroid(waypoints)
  local sumX, sumY, sumZ = 0, 0, 0
  local count = 0

  for _,waypoint in ipairs(waypoints) do
    sumX = sumX + waypoint.pos.x
    sumY = sumY + waypoint.pos.y
    sumZ = sumZ + waypoint.pos.z
    count = count + 1
  end

  return {sumX / count, sumY / count, sumZ / count}
end

local function calculateWaypointExtents(waypoints)
  local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge

  for _, waypoint in ipairs(waypoints) do
    minX = math.min(minX, waypoint.pos.x)
    maxX = math.max(maxX, waypoint.pos.x)
    minZ = math.min(minZ, waypoint.pos.z)
    maxZ = math.max(maxZ, waypoint.pos.z)
  end

  return minX, maxX, minZ, maxZ
end

local function calculateRotationDirection(waypoint1, waypoint2)
  return vec3(
    waypoint2.pos.x - waypoint1.pos.x,
    waypoint2.pos.y - waypoint1.pos.y,
    0 -- Keep Z component as 0 to maintain top-down view
  )
end

local function calculateWaypointElevation(waypoints, fovRad, aspectRatio)
  local minX, maxX, minZ, maxZ = calculateWaypointExtents(waypoints)
  local width = maxX - minX
  local depth = maxZ - minZ

  local horizontalFovRad = 2 * math.atan(math.tan(fovRad / 2) * aspectRatio)

  -- Use the larger of the width or depth in relation to the FOV
  local maxDimension = math.max(width, depth)
  local elevation = (maxDimension / 2) / math.tan(horizontalFovRad / 2)

  return elevation
end

local function setTopDownCamera(waypoints, wp1, wp2)
  local centroid = calculateWaypointsCentroid(waypoints)

  -- Get the window aspect ratio
  -- local vm = GFXDevice.getVideoMode()
  -- local windowAspectRatio = vm.width / vm.height
  -- local fovRad = core_camera.getFovRad()
  -- local elevation = calculateWaypointElevation(waypoints, fovRad, windowAspectRatio)
  -- just hardcode elevation for now.
  local elevation = editor_rallyEditor.getPrefTopDownCameraElevation()

  local cameraPosition = {centroid[1], centroid[2], centroid[3] + elevation}
  core_camera.setPosition(0, vec3(cameraPosition))

  local downFacingRotation = quatFromDir(vec3(0, 0, -1), vec3(0, 1, 0))

  local rotationDir = calculateRotationDirection(wp1, wp2)
  local angleRad = math.atan2(rotationDir.y, rotationDir.x)
  angleRad = (math.pi*0.5) - angleRad -- why???
  local waypointRotation = quatFromAxisAngle(vec3(0, 0, 1), angleRad)
  -- core_camera.setRotation(0, waypointRotation)

  local combinedRotation = downFacingRotation * waypointRotation -- operand order matters here!
  -- quaternion multiplication is not commutative.
  core_camera.setRotation(0, combinedRotation)
end

function C:getRotationWaypoints()
  local wpAudioTrigger = self:getActiveFwdAudioTrigger()

  if wpAudioTrigger then
    return wpAudioTrigger, self:getCornerStartWaypoint()
  else
    return self:getCornerStartWaypoint(), self:getCornerEndWaypoint()
  end
end

function C:setCameraToWaypoints()
  local waypoints = self.pacenoteWaypoints.sorted
  local wp1, wp2 = self:getRotationWaypoints()
  setTopDownCamera(waypoints, wp1, wp2)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
