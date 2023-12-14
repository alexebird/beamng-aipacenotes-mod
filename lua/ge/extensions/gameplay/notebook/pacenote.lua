-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')

local C = {}
local logTag = 'aipacenotes_pacenote'

C.noteFields = {
  before = 'before',
  note = 'note',
  after = 'after',
}

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

  self.draw_debug_lang = nil
end

-- used by pacenoteWaypoints.lua
function C:getNextUniqueIdentifier()
  return self.notebook:getNextUniqueIdentifier()
end

function C:getNextWaypointType()
  local foundTypes = {
    [waypointTypes.wpTypeCornerStart] = false,
    [waypointTypes.wpTypeCornerEnd] = false,
    [waypointTypes.wpTypeFwdAudioTrigger] = false,
  }

  for _,wp in pairs(self.pacenoteWaypoints.objects) do
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

function C:setAllRadii(newRadius, wpType)
  for _,wp in ipairs(self.pacenoteWaypoints.sorted) do
    if not wpType or wp.waypointType == wpType then
      wp.radius = newRadius
    end
  end
end

function C:joinedNote(lang)
  local txt = ''
  local lang_data = self.notes[lang]

  local before = lang_data[self.noteFields.before]
  if before and before ~= '' then
    txt = txt .. before
  end

  local note = lang_data[self.noteFields.note]
  if note and note ~= '' then
    txt = txt .. ' ' .. note
  end

  local after = lang_data[self.noteFields.after]
  if after and after ~= '' then
    txt = txt .. ' ' .. after
  end

  return txt
end

function C:getNoteFieldBefore(lang)
  local lang_data = self.notes[lang]
  if not lang_data then return '' end
  local val = lang_data[self.noteFields.before]
  if not val then
    return ''
  end
  return val
end

function C:getNoteFieldNote(lang)
  local lang_data = self.notes[lang]
  if not lang_data then return '' end
  local val = lang_data[self.noteFields.note]
  if not val then
    return ''
  end
  return val
end

function C:getNoteFieldAfter(lang)
  local lang_data = self.notes[lang]
  if not lang_data then return '' end
  local val = lang_data[self.noteFields.after]
  if not val then
    return ''
  end
  return val
end

function C:setNoteFieldBefore(lang, val)
  local lang_data = self.notes[lang]
  if not lang_data then return end
  lang_data[self.noteFields.before] = val
end

function C:setNoteFieldNote(lang, val)
  local lang_data = self.notes[lang]
  if not lang_data then return end
  lang_data[self.noteFields.note] = val
end

function C:setNoteFieldAfter(lang, val)
  local lang_data = self.notes[lang]
  if not lang_data then return end
  lang_data[self.noteFields.after] = val
end

function C:setFieldsForFlowgraph(lang)
  self.note = self:joinedNote(lang)

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

function C:getDefaultNoteLang()
  return self.notebook._default_note_lang
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
      txt = '['..waypointTypes.shortenWaypointType(wp.waypointType)
      if dist_text then
        txt = txt..','..dist_text
      end
      txt = txt..'] ' .. note_text
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

local function drawWaypoint(wp, wp_drawMode,
                            note_text, dist_text,
                            hover_wp_id, selected_wp_id,
                            alpha)
  -----------------------------------------------
  if not wp then return end

  local hover = hover_wp_id and hover_wp_id == wp.id
  local cs_prefix = nil
  local clr = nil

  local shapeAlpha = alpha * cc.pacenote_shapeAlpha_factor
  local textAlpha = alpha

  -- determine if the waypoint is selected
  if selected_wp_id and selected_wp_id == wp.id then
    wp_drawMode = 'selected_wp'
  end

  -- enumerate all wp_drawModes
  if wp_drawMode == 'selected_wp' then
    cs_prefix = true
    clr = cc.waypoint_clr_sphere_selected
  elseif wp_drawMode == 'selected_pn' then
    cs_prefix = true
    clr = wp:colorForWpType()
  elseif wp_drawMode == 'normal' then
    cs_prefix = false
    clr = rainbowColor(#wp.pacenote.notebook.pacenotes.sorted, (wp.pacenote.sortOrder-1), 1)
  end

  local text = textForDrawDebug(wp, cs_prefix, note_text, dist_text)
  wp:drawDebug(hover, text, clr, shapeAlpha, textAlpha)
end

local function drawLink(from, to, clr, alpha)
  if not (from and to) then return end
  local fromHeight = from.radius * cc.pacenote_linkHeightRadiusShinkFactor
  local toHeight = to.radius * cc.pacenote_linkHeightRadiusShinkFactor
  local shapeAlpha = alpha * cc.pacenote_shapeAlpha_factor
  debugDrawer:drawSquarePrism(
    from.pos,
    to.pos,
    Point2F(fromHeight, cc.pacenote_linkFromWidth),
    Point2F(toHeight, cc.pacenote_linkToWidth),
    ColorF(clr[1], clr[2], clr[3], shapeAlpha)
  )
end

local function formatDistanceStringMeters(dist)
  return tostring(round(dist))..'m'
end

local function prettyDistanceStringMeters(from, to)
  if not (from and to) then return "?m" end
  local d = from.pos:distance(to.pos)
  return formatDistanceStringMeters(d)
end

local function drawLinkLabel(from, to, text, alpha, clr_fg, clr_bg)
  -- make the position in the middle of from and to.
  local textPos = (from.pos + to.pos) / 2

  clr_fg = clr_fg or cc.pacenote_clr_link_fg
  clr_bg = clr_bg or cc.pacenote_clr_link_bg

  debugDrawer:drawTextAdvanced(textPos,
    String(text),
    ColorF(clr_fg[1],clr_fg[2],clr_fg[3], alpha),
    true,
    false,
    ColorI(clr_bg[1]*255,clr_bg[2]*255,clr_bg[3]*255, alpha * 255)
  )
end

function C:drawDebugPacenoteHelper(drawConfig, hover_wp_id, selected_wp_id, pacenote_prev, pacenote_next)
  local dist_text = nil
  local wp_drawMode = 'selected_pn'
  local note_text = self:noteTextForDrawDebug()
  local base_alpha = drawConfig.base_alpha

  -- draw the fwd audio triggers and link them to CS.
  if editor_rallyEditor.getPrefShowAudioTriggers() and drawConfig.at then
    for _,wp in ipairs(self:getAudioTriggerWaypoints()) do
      -- distance is from AT to CS
      dist_text = prettyDistanceStringMeters(wp, self:getCornerStartWaypoint())
      drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
      drawLink(wp, self:getCornerStartWaypoint(), cc.pacenote_clr_at, base_alpha)
    end
  end
  dist_text = nil

  -- draw beforeStart distance markers, draw link, draw link distance label
  if editor_rallyEditor.getPrefShowDistanceMarkers() and drawConfig.di_before then
    local nextwp = self:getCornerStartWaypoint()
    for _,wp in ipairs(self:getDistanceMarkerWaypointsBeforeStart()) do
      drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
      drawLink(wp, nextwp, cc.pacenote_clr_di, base_alpha)
      -- distance is from distance marker to: either next distance marker, or CS
      dist_text = prettyDistanceStringMeters(wp, nextwp)
      drawLinkLabel(wp, nextwp, dist_text, base_alpha, cc.pacenote_clr_di_txt, cc.pacenote_clr_di)
      nextwp = wp
    end
  end
  dist_text = nil

  -- draw the CS
  if drawConfig.cs then
    if pacenote_prev then
      -- distance is from prev CS to this CE, including all after and before distance markers
      dist_text = formatDistanceStringMeters(pacenote_prev:distanceCornerEndToCornerStart(self))
    end
    drawWaypoint(self:getCornerStartWaypoint(), wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
  end
  dist_text = nil

  -- draw the distance markers, links, and labels, that are between CS and CE
  local prevIsCS = true
  local prevwp = self:getCornerStartWaypoint()
  if editor_rallyEditor.getPrefShowDistanceMarkers() and drawConfig.di_middle then
    for _,wp in ipairs(self:getDistanceMarkerWaypointsInBetween()) do
      drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
      drawLink(prevwp, wp, cc.pacenote_clr_di, base_alpha)
      -- distance is from CS to each distance marker
      dist_text = prettyDistanceStringMeters(prevwp, wp)
      drawLinkLabel(prevwp, wp, dist_text, base_alpha, cc.pacenote_clr_di_txt, cc.pacenote_clr_di)
      prevwp = wp
      prevIsCS = false
    end
  end
  dist_text = nil

  -- draw the CE
  if drawConfig.ce then
    if pacenote_next then
      -- distance is from CE to next CS, including all after and before distance markers
      dist_text = formatDistanceStringMeters(self:distanceCornerEndToCornerStart(pacenote_next))
      -- dist_text = prettyDistanceStringMeters(self:getCornerEndWaypoint(), pacenote_next:waypointForBeforeLink())
    end
    drawWaypoint(self:getCornerEndWaypoint(), wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
  end
  dist_text = nil

  -- draw the link into CE depending on some logic.
  if prevIsCS or not editor_rallyEditor.getPrefShowDistanceMarkers() then
    drawLink(prevwp, self:getCornerEndWaypoint(), cc.pacenote_clr_cs_to_ce_direct, base_alpha)
  else
    if editor_rallyEditor.getPrefShowDistanceMarkers() and drawConfig.di_middle then
      drawLink(prevwp, self:getCornerEndWaypoint(), cc.pacenote_clr_di, base_alpha)
      -- distance is from the last middle DI to CE
      dist_text = prettyDistanceStringMeters(prevwp, self:getCornerEndWaypoint())
      drawLinkLabel(prevwp, self:getCornerEndWaypoint(), dist_text, base_alpha, cc.pacenote_clr_di_txt, cc.pacenote_clr_di)
    end
  end
  dist_text = nil

  -- draw the distance markers after CE, links, labels.
  if editor_rallyEditor.getPrefShowDistanceMarkers() and drawConfig.di_after then
    prevwp = self:getCornerEndWaypoint()
    for _,wp in ipairs(self:getDistanceMarkerWaypointsAfterEnd()) do
      drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
      drawLink(prevwp, wp, cc.pacenote_clr_di, base_alpha)
      -- distance is from CE to each DI
      dist_text = prettyDistanceStringMeters(prevwp, wp)
      drawLinkLabel(prevwp, wp, dist_text, base_alpha, cc.pacenote_clr_di_txt, cc.pacenote_clr_di)
      prevwp = wp
    end
  end
end

-- AT, CS, CE, CS->CE, DI
-- function C:drawDebugPrevious(hover_wp_id)
--   local dist_text = nil
--   local wp_drawMode = 'selected_pn'
--   local selected_wp_id = nil
--   local note_text = self:noteTextForDrawDebug()
--
--   -- draw the fwd audio triggers and link them to CS.
--   for _,wp in ipairs(self:getAudioTriggerWaypoints()) do
--     drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, cc.pacenote_alpha_shape_previous, cc.pacenote_alpha_txt_previous)
--     drawLink(wp, self:getCornerStartWaypoint(), clr_blue, cc.pacenote_alpha_shape_previous)
--   end
--
--   -- draw the CS
--   drawWaypoint(self:getCornerStartWaypoint(), wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, cc.pacenote_alpha_shape_previous, cc.pacenote_alpha_txt_previous)
--   -- draw the CE
--   drawWaypoint(self:getCornerEndWaypoint(), wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, cc.pacenote_alpha_shape_previous, cc.pacenote_alpha_txt_previous)
--   -- draw the link to CE
--   drawLink(self:getCornerStartWaypoint(), self:getCornerEndWaypoint(), clr_grey, cc.pacenote_alpha_shape_previous)
--
--   -- draw the distance markers after CE, links, labels.
--   local prevwp = self:getCornerEndWaypoint()
--   for _,wp in ipairs(self:getDistanceMarkerWaypointsAfterEnd()) do
--     drawWaypoint(wp, wp_drawMode, note_text, dist_text, hover_wp_id, selected_wp_id, cc.pacenote_alpha_shape_previous, cc.pacenote_alpha_txt_previous)
--     drawLink(prevwp, wp, cc.pacenote_clr_di, cc.pacenote_alpha_shape_previous)
--     local distStr = prettyDistanceStringMeters(prevwp, wp)
--     drawLinkLabel(prevwp, wp, distStr, cc.pacenote_alpha_txt_previous)
--     prevwp = wp
--   end
-- end

function C:waypointForBeforeLink()
  if editor_rallyEditor.getPrefShowDistanceMarkers() then
    local to_wp = self:getCornerStartWaypoint()
    local before_start = self:getDistanceMarkerWaypointsBeforeStart()
    if #before_start > 0 then
      to_wp = before_start[1]
    end
    return to_wp
  else
    local to_wp = self:getCornerStartWaypoint()
    return to_wp
  end
end

function C:waypointForAfterLink()
  if editor_rallyEditor.getPrefShowDistanceMarkers() then
    local from_wp = self:getCornerEndWaypoint()
    local afterEnd = self:getDistanceMarkerWaypointsAfterEnd()
    if #afterEnd > 0 then
      from_wp = afterEnd[#afterEnd]
    end
    return from_wp
  else
    local from_wp = self:getCornerEndWaypoint()
    return from_wp
  end
end

function C:distanceCornerEndToCornerStart(toPacenote)
  local allWaypoints = {}

  local startWp = self:getCornerEndWaypoint()
  table.insert(allWaypoints, startWp)

  local selfDistMarkers = self:getDistanceMarkerWaypointsAfterEnd()
  for _,wp in ipairs(selfDistMarkers) do
    table.insert(allWaypoints, wp)
  end

  local toDistMarkers = toPacenote:getDistanceMarkerWaypointsBeforeStart()
  for _,wp in ipairs(toDistMarkers) do
    table.insert(allWaypoints, wp)
  end

  local endWp = toPacenote:getCornerStartWaypoint()
  table.insert(allWaypoints, endWp)

  local distance = 0.0
  local lastWp = nil
  for _,wp in ipairs(allWaypoints) do
    if lastWp then
      distance = distance + lastWp.pos:distance(wp.pos)
    end
    lastWp = wp
  end

  return distance
end

function C:drawLinkToPacenote(to_pacenote)
  local from_wp = self:waypointForAfterLink()
  local to_wp = to_pacenote:waypointForBeforeLink()

  local distStrTotal = formatDistanceStringMeters(self:distanceCornerEndToCornerStart(to_pacenote))
  local distStr = prettyDistanceStringMeters(from_wp, to_wp)
  distStr = distStrTotal..'('..distStr..')'

  drawLink(from_wp, to_wp, cc.pacenote_clr_interlink, cc.pacenote_alpha_interlink)
  drawLinkLabel(from_wp, to_wp, distStr, cc.pacenote_alpha_interlink, cc.pacenote_clr_interlink_txt, cc.pacenote_clr_interlink)
end

function C:noteTextForDrawDebug()
  local txt = self.notes[self:getDefaultNoteLang()][self.noteFields.note] or ''
  txt = string.gsub(txt, "\n", " ")
  return txt
end

function C:drawDebugPacenote(drawMode, hover_wp_id, selected_wp_id, pacenote_prev, pacenote_next)
  if drawMode == 'selected' then
    local drawConfig = {
      di_before = true,
      at = true,
      cs = true,
      di_middle = true,
      ce = true,
      di_after = true,
      base_alpha = cc.pacenote_base_alpha_selected,
    }
    self:drawDebugPacenoteHelper(drawConfig, hover_wp_id, selected_wp_id, pacenote_prev, pacenote_next)
  elseif drawMode == 'previous' then
    local drawConfig = {
      di_before = false,
      at = true,
      cs = true,
      di_middle = true,
      ce = true,
      di_after = true,
      base_alpha = cc.pacenote_base_alpha_prev,
    }
    self:drawDebugPacenoteHelper(drawConfig, hover_wp_id, selected_wp_id, pacenote_prev, pacenote_next)
  elseif drawMode == 'next' then
    local drawConfig = {
      di_before = true,
      at = true,
      cs = true,
      di_middle = true,
      ce = true,
      di_after = false,
      base_alpha = cc.pacenote_base_alpha_next,
    }
    self:drawDebugPacenoteHelper(drawConfig, hover_wp_id, selected_wp_id, pacenote_prev, pacenote_next)
  elseif drawMode == 'normal' then
    drawWaypoint(self:getCornerStartWaypoint(), 'normal', self:noteTextForDrawDebug(), nil, hover_wp_id, nil, cc.pacenote_base_alpha_normal)
  end
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
