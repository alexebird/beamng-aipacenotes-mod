local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes_pacenote'

local pn_drawMode_noSelection = 'no_selection'
local pn_drawMode_partitionedSnaproad = 'partitioned_snaproad'
local pn_drawMode_background = 'background'
local pn_drawMode_next = 'next'
local pn_drawMode_previous = 'previous'
local pn_drawMode_selected = 'selected'

C.noteFields = {
  before = 'before',
  note = 'note',
  after = 'after',
}

function C:init(notebook, name, forceId)
  self.notebook = notebook
  self.id = forceId or notebook:getNextUniqueIdentifier()
  self.name = name or ("Pacenote " .. self.id)
  self.todo = false
  self.playback_rules = nil
  self.isolate = false
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

  local note = lang_data[self.noteFields.note]
  local before = lang_data[self.noteFields.before]
  local after = lang_data[self.noteFields.after]

  if useNote(note) then
    -- txt = txt .. ' ' .. note
    txt = note
  else
    -- if theres no note, dont bother with distance calls
    return txt
  end

  if not string.find(txt, re_util.var_dl) then
    txt = re_util.var_dl..' '..txt
  end

  if useNote(before) then
    -- txt = txt .. before
    txt = string.gsub(txt, re_util.var_dl, before)
  else
    txt = string.gsub(txt, re_util.var_dl, '')
  end

  if useNote(after) then
    if not string.find(txt, re_util.var_dt) then
      txt = txt .. ' ' .. re_util.var_dt .. re_util.default_punctuation_distance_call
    end
    -- txt = txt .. ' ' .. after
    txt = string.gsub(txt, re_util.var_dt, after)
  else
    txt = string.gsub(txt, re_util.var_dt, '')
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

function C:clearCachedFgData()
  self._cached_fgData = nil
end

function C:asFlowgraphData(missionSettings, codriver)
  -- TODO reuse validations here.
  if self._cached_fgData then
    return self._cached_fgData
  end

  local fname = self:audioFname(codriver, missionSettings.dynamic.missionDir)

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

  if self.todo then
    table.insert(self.validation_issues, 'marked TODO')
  end

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
        table.insert(self.validation_issues, 'missing puncuation(. ? !) for language '..note_lang..". (try 'Set Puncuation' button)")
      end
    end
  end
end

function C:is_valid()
  return #self.validation_issues == 0
end

function C:nameForSelect()
  local txt = self.name
  local lang = self.notebook:selectedCodriverLanguage()
  local note = self.notes[lang].note
  if not note or note == '' then
    note = '<empty>'
  end

  txt = txt..' - '..note

  if self:is_valid() then
    return txt
  else
    return '[!] '..txt
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
  for lang,langData in pairs(self.notes) do
    langData._out = self:joinedNote(lang)
  end

  -- print(dumps(self.notes))

  local ret = {
    oldId = self.id,
    name = self.name,
    playback_rules = self.playback_rules,
    isolate = self.isolate or false,
    todo = self.todo or false,
    notes = self.notes,
    metadata = self.metadata,
    pacenoteWaypoints = self.pacenoteWaypoints:onSerialize(),
  }

  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.name = data.name
  self.playback_rules = data.playback_rules
  self.isolate = data.isolate or false
  self.todo = data.todo or false
  self.notes = data.notes
  self.metadata = data.metadata or {}
  self.pacenoteWaypoints:onDeserialized(data.pacenoteWaypoints, oldIdMap)
end

function C:markTodo()
  self.todo = true
end

function C:clearTodo()
  self.todo = false
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

local function textForDrawDebug(drawConfig, selection_state, wp, dist_text)
  local note_text = wp.pacenote:noteTextForDrawDebug()
  local txt = nil

  if drawConfig.cs_text and wp:isCs() then
    txt = note_text

    if editor_rallyEditor and editor_rallyEditor.getPrefLockWaypoints() and selection_state.selected_pn_id then
      txt = '[LOCK] '..txt
    end

    if not txt or txt == '' then
      txt = '<empty pacenote>'
    end
    -- end
  elseif drawConfig.ce_text and wp:isCe() then
    txt = '['..waypointTypes.shortenWaypointType(wp.waypointType)
    if dist_text then
      txt = txt..','..dist_text
    end
    txt = txt..']'
  elseif drawConfig.at_text and wp:isAt() then
    if selection_state.selected_wp_id and selection_state.selected_wp_id == wp.id then
      if dist_text then
        txt = '['..dist_text..']'
      end
    elseif drawConfig.pn_drawMode == pn_drawMode_previous or drawConfig.pn_drawMode == pn_drawMode_next then
      txt = '['..waypointTypes.shortenWaypointType(wp.waypointType)
      txt = txt..'] '..note_text
    end
  elseif drawConfig.di_text and wp:isDi() then
    txt = '['..waypointTypes.shortenWaypointType(wp.waypointType) ..']'
  end

  return txt
end

local function drawWaypoint(drawConfig, selection_state, wp, dist_text)
  if not wp then return end

  local hover_wp_id = selection_state.hover_wp_id
  local selected_wp_id = selection_state.selected_wp_id
  local hover = hover_wp_id and hover_wp_id == wp.id
  local clr = nil

  local pn_drawMode = drawConfig.pn_drawMode

  local alpha_shape = drawConfig.base_alpha
  local alpha_text = drawConfig.base_alpha
  local clr_textFg = nil
  local clr_textBg = nil
  local radius_factor = nil

  local pn = wp.pacenote
  local valid = pn:is_valid()

  if pn_drawMode == pn_drawMode_selected then
    alpha_text = cc.pacenote_alpha_text_selected
    if selected_wp_id and selected_wp_id == wp.id then
      clr = wp:colorForWpType(pn_drawMode)
      alpha_shape = cc.waypoint_alpha_selected
      -- clr = cc.waypoint_clr_sphere_selected
    else
      clr = wp:colorForWpType(pn_drawMode)
    end

    if not valid then
      clr_textFg = cc.clr_white
      clr_textBg = cc.clr_red_dark
    end
  elseif pn_drawMode == pn_drawMode_previous then
    clr = wp:colorForWpType(pn_drawMode)
    if wp:isCs() then
      radius_factor = drawConfig.cs_radius
    elseif wp:isCe() then
      radius_factor = drawConfig.ce_radius
    elseif wp:isAt() then
      radius_factor = drawConfig.at_radius
    end

    if not valid then
      clr_textFg = cc.clr_white
      clr_textBg = cc.clr_red_dark
    end
  elseif pn_drawMode == pn_drawMode_next then
    clr = wp:colorForWpType(pn_drawMode)
    if wp:isCs() then
      radius_factor = drawConfig.cs_radius
    elseif wp:isCe() then
      radius_factor = drawConfig.ce_radius
    elseif wp:isAt() then
      radius_factor = drawConfig.at_radius
    end

    if not valid then
      clr_textFg = cc.clr_white
      clr_textBg = cc.clr_red_dark
    end
  elseif pn_drawMode == pn_drawMode_partitionedSnaproad then
    alpha_text = 1.0
    clr = wp:colorForWpType(pn_drawMode_previous)
    if not valid then
      clr_textFg = cc.clr_white
      clr_textBg = cc.clr_red_dark
    end
    radius_factor = cc.pacenote_adjacent_radius_factor
  elseif pn_drawMode == pn_drawMode_background then
    if valid then
      clr = cc.waypoint_clr_background
    else
      clr = cc.clr_red_dark
      clr_textFg = cc.clr_white
      clr_textBg = cc.clr_red_dark
    end
    radius_factor = cc.pacenote_adjacent_radius_factor
  elseif pn_drawMode == pn_drawMode_noSelection then
    alpha_text = 1.0
    if valid then
      -- rainbow theme
      -- clr = rainbowColor(#wp.pacenote.notebook.pacenotes.sorted, (wp.pacenote.sortOrder-1), 1)

      -- dark green theme
      -- clr = cc.clr_green_dark
      -- clr_textFg = cc.clr_white
      -- clr_textBg = cc.clr_green_dark

      -- dark theme
      clr = cc.waypoint_clr_background
      clr_textFg = cc.clr_white
      clr_textBg = cc.clr_black

      -- light theme
      -- clr = cc.clr_white
      -- clr_textFg = cc.clr_black
      -- clr_textBg = cc.clr_white
    else
      clr = cc.clr_red_dark
      clr_textFg = cc.clr_white
      clr_textBg = cc.clr_red_dark
    end
  end

  local text = textForDrawDebug(drawConfig, selection_state, wp, dist_text)
  wp:drawDebug(hover, text, clr, alpha_shape, alpha_text, clr_textFg, clr_textBg, radius_factor)
end

local function formatDistanceStringMeters(dist)
  return tostring(round(dist))..'m'
end

local function prettyDistanceStringMeters(from, to)
  if not (from and to) then return "?m" end
  local d = from.pos:distance(to.pos)
  return formatDistanceStringMeters(d)
end

function C:drawDebugPacenoteHelper(drawConfig, selection_state)
  local text_dist = nil
  local wp_all_at = self:getAudioTriggerWaypoints()
  local wp_cs = self:getCornerStartWaypoint()
  local wp_ce = self:getCornerEndWaypoint()
  local wp_dist_before_start = self:getDistanceMarkerWaypointsBeforeStart()
  local wp_dist_between = self:getDistanceMarkerWaypointsInBetween()
  local wp_dist_after_end = self:getDistanceMarkerWaypointsAfterEnd()

  -- (1) draw the fwd audio triggers and link them to CS.
  if drawConfig.at then
    for _,wp in ipairs(wp_all_at) do
      -- distance is from AT to CS
      text_dist = prettyDistanceStringMeters(wp, wp_cs)
      drawWaypoint(drawConfig, selection_state, wp, text_dist)
    end
  end

  -- (2) draw beforeStart distance markers, draw link, draw link distance label
  if drawConfig.di_before then
    for _,wp in ipairs(wp_dist_before_start) do
      drawWaypoint(drawConfig, selection_state, wp, text_dist)
    end
  end

  -- (3) draw the CS
  if drawConfig.cs then
    text_dist = nil
    drawWaypoint(drawConfig, selection_state, wp_cs, text_dist)
  end

  -- (4) draw the distance markers, links, and labels, that are between CS and CE
  if drawConfig.di_middle then
    for _,wp in ipairs(wp_dist_between) do
      text_dist = nil
      drawWaypoint(drawConfig, selection_state, wp, text_dist)
    end
  end

  -- (5) draw the CE
  if drawConfig.ce then
    text_dist = nil
    drawWaypoint(drawConfig, selection_state,  wp_ce, text_dist)
  end

  -- -- (7) draw the distance markers after CE, links, labels.
  if drawConfig.di_after then
    for _,wp in ipairs(wp_dist_after_end) do
      drawWaypoint(drawConfig, selection_state, wp, text_dist)
    end
  end
end

function C:waypointForBeforeLink()
  local to_wp = self:getCornerStartWaypoint()
  return to_wp
end

function C:waypointForAfterLink()
  local from_wp = self:getCornerEndWaypoint()
  return from_wp
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

function C:noteTextForDrawDebug()
  local txt = '<empty note>'

  local lang = self.notebook:selectedCodriverLanguage()
  local joined = self:joinedNote(lang)
  if joined then
    txt = joined
  end
  txt = string.gsub(txt, "\n", " ")
  return txt
end

local function adjustFromPrefs(drawConfig)
  local show_at = editor_rallyEditor.getPrefShowAudioTriggers()
  drawConfig.at = show_at and drawConfig.at
end

function C:drawDebugPacenotePartitionedSnaproad(selection_state)
  local drawConfig = {
    pn_drawMode = pn_drawMode_partitionedSnaproad,
    di_before = false,
    at = false,
    cs = true,
    di_middle = false,
    ce = true,
    di_after = false,
    base_alpha = cc.pacenote_base_alpha_no_sel,
    at_text = false,
    cs_text = true,
    ce_text = false,
    di_text = false,
    cs_radius = cc.pacenote_adjacent_radius_factor,
    ce_radius = cc.pacenote_adjacent_radius_factor,
    at_radius = cc.pacenote_adjacent_radius_factor,
  }
  adjustFromPrefs(drawConfig)
  self:drawDebugPacenoteHelper(drawConfig, selection_state)
end

function C:drawDebugPacenoteNoSelection(selection_state)
  local drawConfig = {
    pn_drawMode = pn_drawMode_noSelection,
    di_before = false,
    at = false,
    cs = true,
    di_middle = false,
    ce = false,
    di_after = false,
    base_alpha = cc.pacenote_base_alpha_no_sel,
    at_text = false,
    cs_text = true,
    ce_text = false,
    di_text = false,
  }
  adjustFromPrefs(drawConfig)
  self:drawDebugPacenoteHelper(drawConfig, selection_state)
end

function C:drawDebugPacenoteBackground(selection_state)
  local drawConfig = {
    pn_drawMode = pn_drawMode_background,
    di_before = false,
    at = false,
    cs = true,
    di_middle = false,
    ce = false,
    di_after = false,
    base_alpha = cc.pacenote_base_alpha_background,
    at_text = false,
    cs_text = true,
    ce_text = false,
    di_text = false,
  }
  adjustFromPrefs(drawConfig)
  self:drawDebugPacenoteHelper(drawConfig, selection_state)
end

function C:drawDebugPacenoteNext(selection_state, pn_sel)
  local drawConfig = {
    pn_drawMode = pn_drawMode_next,
    di_before = false,
    at = true,
    cs = true,
    di_middle = false,
    ce = true,
    di_after = false,
    base_alpha = cc.pacenote_base_alpha_next,
    at_text = false,
    cs_text = true,
    ce_text = false,
    di_text = false,
    cs_radius = cc.pacenote_adjacent_radius_factor,
    ce_radius = cc.pacenote_adjacent_radius_factor,
    at_radius = cc.pacenote_adjacent_radius_factor,
  }
  adjustFromPrefs(drawConfig)
  self:drawDebugPacenoteHelper(drawConfig, selection_state)
end

function C:drawDebugPacenotePrev(selection_state, pn_sel)
  local drawConfig = {
    pn_drawMode = pn_drawMode_previous,
    di_before = false,
    at = true,
    cs = true,
    di_middle = true,
    ce = true,
    di_after = true,
    base_alpha = cc.pacenote_base_alpha_prev,
    at_text = false,
    cs_text = true,
    ce_text = false,
    di_text = false,
    cs_radius = cc.pacenote_adjacent_radius_factor,
    ce_radius = cc.pacenote_adjacent_radius_factor,
    at_radius = cc.pacenote_adjacent_radius_factor,
  }
  adjustFromPrefs(drawConfig)
  self:drawDebugPacenoteHelper(drawConfig, selection_state)
end

function C:drawDebugPacenoteSelected(selection_state)
  local drawConfig = {
    pn_drawMode = pn_drawMode_selected,
    di_before = true,
    at = true,
    cs = true,
    di_middle = true,
    ce = true,
    di_after = true,
    base_alpha = cc.pacenote_base_alpha_selected,
    at_text = true,
    cs_text = true,
    ce_text = false,
    di_text = false,
  }
  adjustFromPrefs(drawConfig)
  self:drawDebugPacenoteHelper(drawConfig, selection_state)
end

function C:audioFname(codriver, missionDir)
  missionDir =  missionDir or editor_rallyEditor.getMissionDir() or 'no_mission'

  local codriverLang = codriver.language
  local noteStr = self:joinedNote(codriverLang)
  local pacenoteHash = re_util.pacenote_hash(noteStr)
  local pacenotesDir = re_util.buildPacenotesDir(missionDir, self.notebook, codriver)
  local fname = pacenotesDir..'/pacenote_'..pacenoteHash..'.ogg'

  return fname
end

function C:playbackAllowed(currLap, maxLap)
  -- local context = { currLap = currLap, maxLap = maxLap }
  local condition = self.playback_rules

  -- log('D', logTag,
  --   "playbackAllowed name='"..self.name..
  --   "' condition='"..tostring(condition)..
  --   "' currLap="..tostring(currLap..
  --   " maxLap="..tostring(maxLap)))

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

function C:_moveWaypointTowardsStepper(snaproad, wp, fwd)
  local newSnapPoint = nil

  if fwd then
    newSnapPoint = snaproad:nextSnapPoint(wp.pos)
  else
    newSnapPoint = snaproad:prevSnapPoint(wp.pos)
  end

  if newSnapPoint then
    wp:setPos(newSnapPoint.pos)
    wp.pacenote.notebook:autofillDistanceCalls()
    local normalVec = snaproad:forwardNormalVec(newSnapPoint)
    if normalVec then
      wp:setNormal(normalVec)
    end

    if wp:isCs() then
      local pn_sel = wp.pacenote
      local wp_sel = wp

      local wp_at = pn_sel:getActiveFwdAudioTrigger()

      local point_cs = snaproad:closestSnapPoint(wp_sel.pos)
      local point_at = snaproad:closestSnapPoint(wp_at.pos, true)

      if point_cs.id <= point_at.id then
        point_at = snaproad:pointsBackwards(point_cs, 1)
        wp_at.pos = point_at.pos

        local normalVec = snaproad:forwardNormalVec(point_at)
        if normalVec then
          wp_at:setNormal(normalVec)
        end
      end

    end
  end
end

function C:moveWaypointTowards(snaproads, wp, fwd, step)
  step = step or 1
  for _ = 1,step do
    self:_moveWaypointTowardsStepper(snaproads, wp, fwd)
  end
end

function C:normalizeNoteText(lang, last, force)
  local note = self:getNoteFieldNote(lang)
  local mainSettings = self.notebook.mainSettings

  force = force or false
  note = re_util.stripWhitespace(note)

  if note ~= re_util.autofill_blocker then
    if note ~= '' and note ~= re_util.unknown_transcript_str then
      -- add punction if not present
      local last_char = note:sub(-1)

      if force and re_util.hasPunctuation(last_char) then
        note = string.sub(note, 1, -2)
        last_char = note:sub(-1)
      end

      if not re_util.hasPunctuation(last_char) then

        local punc = nil
        if last then
          punc = mainSettings:getPunctuationLastNote()
        else
          punc = mainSettings:getPunctuationDefault()
        end

        print('setting punc: '..punc)

        note = note..punc
      end
    end
  end

  local newTxt = note

  -- local newTxt = re_util.normalizeNoteText(self.notebook.mainSettings, note, last, force or false)

  self:setNoteFieldNote(lang, newTxt)
end

function C:toggleIsolate()
  self.isolate = not self.isolate

  local lang = self.notebook:selectedCodriverLanguage()

  if self.isolate then
    if self:getNoteFieldBefore(lang) ~= re_util.autofill_blocker then
      self:setNoteFieldBefore(lang, re_util.autodist_internal_level1)
    end
    if self:getNoteFieldAfter(lang) ~= re_util.autofill_blocker then
      self:setNoteFieldAfter(lang, re_util.autodist_internal_level1)
    end
  else
    if self:getNoteFieldBefore(lang) ~= re_util.autofill_blocker then
      self:setNoteFieldBefore(lang, '')
    end
    if self:getNoteFieldAfter(lang) ~= re_util.autofill_blocker then
      self:setNoteFieldAfter(lang, '')
    end
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
