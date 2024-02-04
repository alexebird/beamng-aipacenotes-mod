local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

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
  self.playback_rules = nil
  self.notes = {}
  for _,lang in ipairs(self.notebook:getLanguages()) do
    lang = lang.language
    self.notes[lang] = {}
    for _,val in pairs(self.noteFields) do
      self.notes[lang][val] = ''
    end
  end
  self.pacenoteWaypoints = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "pacenoteWaypoints",
    self,
    require('/lua/ge/extensions/gameplay/notebook/pacenoteWaypoint')
  )
  self.metadata = {}

  self.sortOrder = 999999
  self.validation_issues = {}
  self.draw_debug_lang = nil
  self._cached_fgData = nil
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

function C:allToTerrain()
  for _,wp in ipairs(self.pacenoteWaypoints.sorted) do
    wp.pos.z = core_terrain.getTerrainHeight(wp.pos)
  end
end

function C:joinedNote(lang)
  local txt = ''
  local lang_data = self.notes[lang]

  if not lang_data then
    return txt
  end

  local useNote = function(text)
    return text and
      text ~= '' and
      text ~= re_util.autofill_blocker and
      text ~= re_util.autodist_internal_level1
  end

  local before = lang_data[self.noteFields.before]
  if useNote(before) then
    txt = txt .. before
  end

  local note = lang_data[self.noteFields.note]
  if useNote(note) then
    txt = txt .. ' ' .. note
  end

  local after = lang_data[self.noteFields.after]
  if useNote(after) then
    txt = txt .. ' ' .. after
  end

  -- trim string
  txt = txt:gsub("^%s*(.-)%s*$", "%1")

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

-- function C:setFieldsForFlowgraph(lang)
--   self.note = self:joinedNote(lang)
--
--   local wp_trigger = self:getActiveFwdAudioTrigger()
--   if not wp_trigger then
--     log('E', logTag, 'audio trigger not found')
--   end
--   self.radius = wp_trigger.radius
--   self.pos = wp_trigger.pos
--   self.normal = wp_trigger.normal
-- end

function C:asFlowgraphData(missionSettings, codriver)
  -- TODO reuse validations here.
  if self._cached_fgData then
    return self._cached_fgData
  end

  local fname = self:audioFname(codriver, missionSettings.dynamic.missionDir)
  if not FS:fileExists(fname) then
    log('E', logTag, "pacenote audio file not found: "..fname)
    return nil
  end

  local wp_trigger = self:getActiveFwdAudioTrigger()
  if not wp_trigger and not self.metadata.static then
    log('W', logTag, 'audio trigger not found')
    -- error("no active audio trigger waypoint found for pacenote '".. self.name .."'")
  end

  local fgData = {
    id = self.id,
    trigger_waypoint = wp_trigger,
    pacenote = self,
    notebook = self.notebook,
    note_text = self:joinedNote(codriver.language),
    audioFname = fname,
  }
  self._cached_fgData = fgData
  return fgData
end

function C:validate()
  self.validation_issues = {}

  if not self:getCornerStartWaypoint() then
    table.insert(self.validation_issues, 'missing CornerStart waypoint')
  end

  if not self:getCornerEndWaypoint() then
    table.insert(self.validation_issues, 'missing CornerEnd waypoint')
  end

  if not self:getActiveFwdAudioTrigger() then
    table.insert(self.validation_issues, 'missing AudioTrigger waypoint')
  end

  if self.name == '' then
    table.insert(self.validation_issues, 'missing pacenote name')
  end

  for note_lang, note_data in pairs(self.notes) do
    local note_field = self:getNoteFieldNote(note_lang)
    if note_field ~= re_util.autofill_blocker then
      local last_char = note_field:sub(-1)
      if note_field == '' then
        table.insert(self.validation_issues, 'missing note for language '..note_lang)
      elseif note_field == re_util.unknown_transcript_str then
        table.insert(self.validation_issues, "'"..re_util.unknown_transcript_str.."' note for language "..note_lang)
      elseif not re_util.hasPunctuation(last_char) then
        table.insert(self.validation_issues, 'missing puncuation(. ? !) for language '..note_lang..". (try 'Normalize Note Text' button)")
      end
    end
  end
end

function C:is_valid()
  return #self.validation_issues == 0
end

function C:nameForSelect()
  if self:is_valid() then
    return self.name
  else
    return '[!] '..self.name
  end
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
    playback_rules = self.playback_rules,
    notes = self.notes,
    metadata = self.metadata,
    pacenoteWaypoints = self.pacenoteWaypoints:onSerialize(),
  }

  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.name = data.name
  self.playback_rules = data.playback_rules
  self.notes = data.notes
  self.metadata = data.metadata or {}
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

local function drawWaypoint(wp, wp_drawMode, pn_drawMode,
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
  local clrTextFg = nil
  local clrTextBg = nil

  -- determine if the waypoint is selected
  if selected_wp_id and selected_wp_id == wp.id then
    wp_drawMode = 'selected_wp'
  end

  local pn = wp.pacenote
  local valid = pn:is_valid()

  -- enumerate all wp_drawModes
  if wp_drawMode == 'selected_wp' then
    cs_prefix = true
    clr = cc.waypoint_clr_sphere_selected
  elseif wp_drawMode == 'selected_pn' then
    cs_prefix = true
    clr = wp:colorForWpType(pn_drawMode)
  elseif wp_drawMode == 'background' then
    cs_prefix = false
    textAlpha = textAlpha * 0.9
    shapeAlpha = shapeAlpha * 0.9
    if valid then
      clr = cc.clr_black
    else
      clr = cc.clr_red_dark
      clrTextFg = cc.clr_white
      clrTextBg = cc.clr_red_dark
    end
  elseif wp_drawMode == 'normal' then
    cs_prefix = false
    if valid then
      clr = rainbowColor(#wp.pacenote.notebook.pacenotes.sorted, (wp.pacenote.sortOrder-1), 1)
    else
      clr = cc.clr_red_dark
      clrTextFg = cc.clr_white
      clrTextBg = cc.clr_red_dark
    end
  end

  local text = textForDrawDebug(wp, cs_prefix, note_text, dist_text)
  wp:drawDebug(hover, text, clr, shapeAlpha, textAlpha, clrTextFg, clrTextBg)
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

local function formatDistanceStringMetersWithShorthand(dist)
  local shorthand = re_util.getDistanceCallShorthand(dist)
  if shorthand then
    return shorthand
  else
    return formatDistanceStringMeters(dist)
  end
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
  local pacenote_draw_mode = drawConfig.drawMode

  local clr_at = cc.waypoint_clr_at

  if pacenote_draw_mode == 'previous' or pacenote_draw_mode == 'next' then
    clr_at = cc.waypoint_clr_at_adjacent
  end

  -- draw the fwd audio triggers and link them to CS.
  if editor_rallyEditor.getPrefShowAudioTriggers() and drawConfig.at then
    for _,wp in ipairs(self:getAudioTriggerWaypoints()) do
      -- distance is from AT to CS
      dist_text = prettyDistanceStringMeters(wp, self:getCornerStartWaypoint())
      drawWaypoint(wp, wp_drawMode, pacenote_draw_mode, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
      drawLink(wp, self:getCornerStartWaypoint(), clr_at, base_alpha)
    end
  end
  dist_text = nil

  -- draw beforeStart distance markers, draw link, draw link distance label
  if editor_rallyEditor.getPrefShowDistanceMarkers() and drawConfig.di_before then
    local nextwp = self:getCornerStartWaypoint()
    for _,wp in ipairs(self:getDistanceMarkerWaypointsBeforeStart()) do
      drawWaypoint(wp, wp_drawMode, nil, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
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
      dist_text = formatDistanceStringMetersWithShorthand(pacenote_prev:distanceCornerEndToCornerStart(self))
    end
    drawWaypoint(self:getCornerStartWaypoint(), wp_drawMode, pacenote_draw_mode, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
  end
  dist_text = nil

  -- draw the distance markers, links, and labels, that are between CS and CE
  local prevIsCS = true
  local prevwp = self:getCornerStartWaypoint()
  if editor_rallyEditor.getPrefShowDistanceMarkers() and drawConfig.di_middle then
    for _,wp in ipairs(self:getDistanceMarkerWaypointsInBetween()) do
      drawWaypoint(wp, wp_drawMode, nil, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
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
      dist_text = formatDistanceStringMetersWithShorthand(self:distanceCornerEndToCornerStart(pacenote_next))
    end
    drawWaypoint(self:getCornerEndWaypoint(), wp_drawMode, pacenote_draw_mode, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
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
      drawWaypoint(wp, wp_drawMode, nil, note_text, dist_text, hover_wp_id, selected_wp_id, base_alpha)
      drawLink(prevwp, wp, cc.pacenote_clr_di, base_alpha)
      -- distance is from CE to each DI
      dist_text = prettyDistanceStringMeters(prevwp, wp)
      drawLinkLabel(prevwp, wp, dist_text, base_alpha, cc.pacenote_clr_di_txt, cc.pacenote_clr_di)
      prevwp = wp
    end
  end
end

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

  -- drawLink(from_wp, to_wp, cc.pacenote_clr_interlink, cc.pacenote_alpha_interlink)
  -- drawLinkLabel(from_wp, to_wp, distStr, cc.pacenote_alpha_interlink, cc.pacenote_clr_interlink_txt, cc.pacenote_clr_interlink)
end

function C:noteTextForDrawDebug()
  local noteData = self.notes[self.notebook:editingLanguage()]
  local txt = '<empty note>'
  if noteData then
    local nd = noteData[self.noteFields.note]
    if nd and nd ~= '' then
      txt = nd
    end
  end
  txt = string.gsub(txt, "\n", " ")
  return txt
end

function C:drawDebugPacenote(drawMode, hover_wp_id, selected_wp_id, pacenote_prev, pacenote_next)
  if drawMode == 'selected' then
    local drawConfig = {
      drawMode = drawMode,
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
      drawMode = drawMode,
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
      drawMode = drawMode,
      di_before = true,
      at = true,
      cs = true,
      di_middle = true,
      ce = true,
      di_after = false,
      base_alpha = cc.pacenote_base_alpha_next,
    }
    self:drawDebugPacenoteHelper(drawConfig, hover_wp_id, selected_wp_id, pacenote_prev, pacenote_next)
  elseif drawMode == 'background' then
    drawWaypoint(self:getCornerStartWaypoint(), 'background', nil, self:noteTextForDrawDebug(), nil, hover_wp_id, nil, cc.pacenote_base_alpha_normal)
  elseif drawMode == 'normal' then
    drawWaypoint(self:getCornerStartWaypoint(), 'normal', nil, self:noteTextForDrawDebug(), nil, hover_wp_id, nil, cc.pacenote_base_alpha_normal)
  end
end

-- local function calculateWaypointsCentroid(waypoints)
--   local sumX, sumY, sumZ = 0, 0, 0
--   local count = 0
--
--   for _,waypoint in ipairs(waypoints) do
--     sumX = sumX + waypoint.pos.x
--     sumY = sumY + waypoint.pos.y
--     sumZ = sumZ + waypoint.pos.z
--     count = count + 1
--   end
--
--   return {sumX / count, sumY / count, sumZ / count}
-- end

function C:setCameraToWaypoints()
  local cs = self:getCornerStartWaypoint()
  if cs then
    cs:lookAtMe()
  end
end

function C:audioFname(codriver, missionDir)
  missionDir =  missionDir or editor_rallyEditor.getMissionDir() or 'no_mission'

  local notebookBasename = re_util.normalize_name(self.notebook:basenameNoExt()) or 'none'
  local codriverName = codriver.name
  local codriverLang = codriver.language
  local codriverVoice = codriver.voice
  local codriverStr = re_util.normalize_name(codriverName..'_'..codriverLang..'_'..codriverVoice)
  local noteStr = self:joinedNote(codriverLang)
  local pacenoteHash = re_util.pacenote_hash(noteStr)

  local fname = missionDir..'/'..re_util.notebooksPath..'/generated_pacenotes/'..notebookBasename..'/'..codriverStr..'/pacenote_'..pacenoteHash..'.ogg'

  return fname
end

function C:playbackAllowed(currLap, maxLap)
  -- local context = { currLap = currLap, maxLap = maxLap }
  local condition = self.playback_rules
  log('D', logTag,
    "playbackAllowed name='"..self.name..
    "' condition='"..tostring(condition)..
    "' currLap="..tostring(currLap..
    " maxLap="..tostring(maxLap)))

  -- If condition is nil or empty/whitespace string, return true
  if condition == nil or condition:match("^%s*$") then
    return true, nil
  end

  -- Lowercase the condition for case-insensitive comparison
  local lowerCondition = condition:lower()

  -- Check for 'true' or 't'
  if lowerCondition == 'true' or lowerCondition == 't' then
    return true, nil
  end

  -- Check for 'false' or 'f'
  if lowerCondition == 'false' or lowerCondition == 'f' then
    return false, nil
  end

  -- Attempt to load the condition as Lua code
  local func, err = loadstring("return " .. condition)
  if func then
    -- Function compiled successfully, now execute it safely
    setfenv(func, context)
    local status, result = pcall(func, context)
    if status then
      return result, nil
    else
      -- Handle runtime error in the function
      return false, "Runtime error in condition: " .. result
    end
  else
    -- Handle syntax error in the condition
    return false, "Syntax error in condition: " .. err
  end
end

function C:vehiclePlacementPosAndRot()
  local cs = self:getCornerStartWaypoint()
  local at = self:getActiveFwdAudioTrigger()

  if cs and at then
    -- local distAway = wp2.radius * 2
    local distAway = 7

    local pos1 = at.pos + (at.normal * distAway)
    local pos2 = at.pos + (-at.normal * distAway)
    local pos = nil

    if cs.pos:distance(pos1) > cs.pos:distance(pos2) then
      pos = pos1
    else
      pos = pos2
    end

    local fwd = at.pos - pos
    local up = vec3(0,0,1)
    local rot = quatFromDir(fwd, up):normalized()

    return pos, rot
  else
    return nil, nil
  end
end

function C:nameComponents()
  local baseName, number = string.match(self.name, "(.-)%s*([%d%.]+)$")
  return baseName, number
end

function C:matchesSearchPattern(searchPattern)
  for lang,note in pairs(self.notes) do
    local fullNote = self:joinedNote(lang)
    -- log('D', 'wtf', 'matching "'..fullNote..'" against "'..searchPattern..'"')
    if re_util.matchSearchPattern(searchPattern, fullNote) then
      return true
    end
  end

  return false
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
