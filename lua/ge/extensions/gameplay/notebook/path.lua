-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:getNextUniqueIdentifier()
  self._uid = self._uid + 1
  return self._uid
end

function C:init(name)
  self._uid = 0
  self.name = ""
  self.description = ""
  self.authors = ""
  self.created_at = os.time()
  self.updated_at = self.created_at

  self.codrivers = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "codrivers",
    self,
    require('/lua/ge/extensions/gameplay/notebook/codriver')
  )

  self.pacenotes = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "pacenotes",
    self,
    require('/lua/ge/extensions/gameplay/notebook/pacenote')
  )

  self.id = self:getNextUniqueIdentifier()

  self._hover_waypoint_id = nil
  self._default_note_lang = 'english'
end

local function extractTrailingNumber(str)
  local num = string.match(str, "%d+%.?%d*$")
  return num and tonumber(num) or nil
end

local function sortByNameNumeric(a, b)
  local numA = extractTrailingNumber(a.name)
  local numB = extractTrailingNumber(b.name)
  
  if numA and numB then
    -- If both have numbers, compare by number
    return numA < numB
  elseif numA then
    -- If only a has a number, it comes first
    return true
  elseif numB then
    -- If only b has a number, it comes first
    return false
  else
    -- If neither has a number, compare by name
    return a.name < b.name
  end
end

function C:sortPacenotesByName()
  local newList = {}
  for i, v in ipairs(self.pacenotes.sorted) do
    table.insert(newList, v)
  end

  table.sort(newList, sortByNameNumeric)

  -- Assign "sortOrder" in the sorted list
  for i, v in ipairs(newList) do
    v.sortOrder = i
  end

  self.pacenotes:sort()
end

function C:cleanupPacenoteNames()
  for i, v in ipairs(self.pacenotes.sorted) do
    -- log("D", "WTF", 'renamed "'..v.name..'" sortOrder='..v.sortOrder)
    v.name = "Pacenote "..i
  end
  -- re-index names.
  self.pacenotes:buildNamesDir()
end

local function calcPointForSegment(racePath, segmentId)
  local pathnodes = racePath.pathnodes.objects
  local segment = racePath.segments.objects[segmentId]
  local from = pathnodes[segment.from]
  local to = pathnodes[segment.to]
  local center = (from.pos + to.pos) / 2
  -- log("D", 'wtf', dumps(center))
  -- debugDrawer:drawSphere((center),
  --   50,
  --   ColorF(1, 0, 0, 1)
  -- )
  return center
end

local function findClosestSegmentCenter(pos, segmentCenters)
  local minDist = 4294967295
  local closest_seg_id = nil
  local dist = nil

  for seg_id,center_pos in pairs(segmentCenters) do
    dist = pos:distance(center_pos)
    if dist < minDist then
      minDist = dist
      closest_seg_id = seg_id
    end
  end

  return closest_seg_id
end

function C:autoAssignSegments(racePath)
  local segment_centers = {}

  for seg_id,segment in pairs(racePath.segments.objects) do
    local center = calcPointForSegment(racePath, seg_id)
    segment_centers[seg_id] = center
  end

  -- clear the segments. probably not necessary.
  for _,pacenote in ipairs(self.pacenotes.sorted) do
    pacenote.segment = -1    
  end

  for _,pacenote in ipairs(self.pacenotes.sorted) do
    local closest_seg_id = findClosestSegmentCenter(pacenote:getCornerStartWaypoint().pos, segment_centers)
    pacenote.segment = closest_seg_id
  end
end

function C:drawPacenoteModeNormal(pacenote)
  pacenote:drawDebugCustom('normal', self._default_note_lang, self._hover_waypoint_id)
end

-- function C:drawPacenoteModePnSelected(pacenote)
--   pacenote:drawDebugCustom('selected_pacenote', self._default_note_lang, self._hover_waypoint_id, selected_wp_id)
-- end

function C:drawPacenoteModeSelected(pacenote, selected_wp_id, pacenote_next)
  pacenote:drawDebugCustom('selected', self._default_note_lang, self._hover_waypoint_id, selected_wp_id, pacenote_next)
end

function C:drawPacenoteModePrevious(pacenote, selected_wp_id)
  pacenote:drawDebugCustom('previous', self._default_note_lang, self._hover_waypoint_id, selected_wp_id)
end

-- function C:drawPacenoteModeNext()
-- end

function C:drawDebug(selected_pacenote_id, selected_waypoint_id)
--   self.pathnodes:drawDebug()
--   self.segments:drawDebug()
--   self.startPositions:drawDebug()
--   if self.installedNotebook then
    -- self.installedNotebook:drawDebug()
--   end

  local i = 1
  local selected_i = -1
  while i <= #self.pacenotes.sorted do
    local pacenote = self.pacenotes.sorted[i]
    if pacenote.id == selected_pacenote_id then
      selected_i = i
    -- else
      -- drawPacenoteModeNormal(pacenote, self._hover_waypoint_id)
    end
    i = i + 1
  end

  -- if selected_i > 0 then
  if selected_pacenote_id and selected_waypoint_id then
    local prev_i = math.max(selected_i - 1, 1)
    local next_i = math.min(selected_i + 1, #self.pacenotes.sorted)
    -- log('D', 'wtf', 'prev='..prev_i..' i='..selected_i..' next='..next_i)

    local pn_sel = self.pacenotes.sorted[selected_i]
    local pn_prev = self.pacenotes.sorted[prev_i]
    local pn_next = self.pacenotes.sorted[next_i]
    self:drawPacenoteModeSelected(pn_sel, selected_waypoint_id, pn_next)
    if pn_prev and pn_prev.id ~= pn_sel.id then
      self:drawPacenoteModePrevious(pn_prev)
      pn_prev:drawLinkToPacenote(pn_sel)
    end
    -- self:drawPacenoteModeNext(pn_next)
  elseif selected_pacenote_id and not selected_waypoint_id then
    local pn_sel = self.pacenotes.sorted[selected_i]
    local next_i = math.min(selected_i + 1, #self.pacenotes.sorted)
    local pn_next = self.pacenotes.sorted[next_i]
    self:drawPacenoteModeSelected(pn_sel, selected_waypoint_id, pn_next)

    -- draw the rest of the pacenotes
    local i = 1
    while i <= #self.pacenotes.sorted do
      local pacenote = self.pacenotes.sorted[i]
      if i ~= selected_i then
        self:drawPacenoteModeNormal(pacenote)
      end
      i = i + 1
    end
  else
    local i = 1
    while i <= #self.pacenotes.sorted do
      local pacenote = self.pacenotes.sorted[i]
      self:drawPacenoteModeNormal(pacenote)
      i = i + 1
    end
  end

  -- notebook drawdebug modes:
  -- - nothing selected -> normal -> rainbow CornerStarts
  -- - click on a waypoint -> waypoint is selected -> pacenote is selected
  --   - only draw i-1,i,i+1 pacenotes
end

function C:onSerialize()
  local ret = {
    name = self.name,
    description = self.description,
    authors = self.authors,
    updated_at = self.updated_at,
    created_at = self.created_at,
    codrivers = self.codrivers:onSerialize(),
    pacenotes = self.pacenotes:onSerialize(),
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end

  self.name = data.name or ""
  self.description = string.gsub(data.description or "", "\\n", "\n")
  self.authors = data.authors or ""
  self.created_at = data.created_at
  self.updated_at = data.created_at

  local oldIdMap = {}

  self.codrivers:clear()
  self.codrivers:onDeserialized(data.codrivers, oldIdMap)

  self.pacenotes:clear()
  self.pacenotes:onDeserialized(data.pacenotes, oldIdMap)
end

function C:copy()
  local cpy = require('/lua/ge/extensions/gameplay/notebook/path')('Copy of ' .. self.name)
  cpy.onDeserialized(self.onSerialize())
  return cpy
end

-- switches start/endNode, all segments and direction of pathnodes. startPositions are not changed.
-- function C:reverse()
--   if self.endNode ~= -1 then
--     self.startNode, self.endNode = self.endNode, self.startNode
--   end
--   for _, s in pairs(self.segments.objects) do
--     s.from, s.to = s.to, s.from
--   end
--   self.isReversed = not self.isReversed
-- end

function C:allWaypoints()
  local wps = {}
  for i, pacenote in pairs(self.pacenotes.objects) do
    for j, wp in pairs(pacenote.pacenoteWaypoints.objects) do
      wps[wp.id] = wp
    end
  end
  return wps
end

function C:getWaypoint(wpId)
  for i, pacenote in pairs(self.pacenotes.objects) do
    for i, waypoint in pairs(pacenote.pacenoteWaypoints.objects) do
      if waypoint.id == wpId then
        return waypoint
      end
    end
  end
  return nil
end

function C:getLanguages()
  local lang_set = {}
  for _, codriver in pairs(self.codrivers.objects) do
    lang_set[codriver.language] = true
  end
  local languages = {}
  for lang, _ in pairs(lang_set) do
    table.insert(languages, lang)
  end
  table.sort(languages)
  return languages
end

function C:setAllRadii(newRadius, wpType)
  for i, pacenote in pairs(self.pacenotes.objects) do
    pacenote:setAllRadii(newRadius, wpType)
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end