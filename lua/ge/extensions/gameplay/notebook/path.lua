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
    local audioTrigger = pacenote:getActiveFwdAudioTrigger()
    if audioTrigger then
      local closest_seg_id = findClosestSegmentCenter(audioTrigger.pos, segment_centers)
      pacenote.segment = closest_seg_id
    end
  end
end

function C:drawPacenotesAsRainbow(skip_pn)
  for _,pacenote in ipairs(self.pacenotes.sorted) do
    if not skip_pn or (skip_pn and pacenote.id ~= skip_pn.id) then
      pacenote:drawDebugPacenote('normal', self._hover_waypoint_id, nil, nil, nil)
    end
  end
end

function C:getAdjacentPacenoteSet(pacenoteId)
  local function getOrNullify(i)
    local pn = self.pacenotes.sorted[i]
    if pn and not pn.missing then
      return pn
    else
      return nil
    end
  end

  for i,pacenote in ipairs(self.pacenotes.sorted) do
    if pacenote.id == pacenoteId then
      return getOrNullify(i-1), pacenote, getOrNullify(i+1)
    end
  end

  return nil, nil, nil
end

function C:drawDebugNotebook(selected_pacenote_id, selected_waypoint_id)
  local pn_prev, pn_sel, pn_next = self:getAdjacentPacenoteSet(selected_pacenote_id)

  if pn_sel and selected_waypoint_id then
    pn_sel:drawDebugPacenote('selected', self._hover_waypoint_id, selected_waypoint_id, pn_prev, pn_next)

    if editor_rallyEditor.getPrefShowPreviousPacenote() and pn_prev and pn_prev.id ~= pn_sel.id then
      pn_prev:drawDebugPacenote('previous', self._default_note_lang, self._hover_waypoint_id, nil, nil, nil)
      pn_prev:drawLinkToPacenote(pn_sel)
    end

    if editor_rallyEditor.getPrefShowNextPacenote() and pn_next and pn_next.id ~= pn_sel.id then
      pn_next:drawDebugPacenote('next', self._default_note_lang, self._hover_waypoint_id, nil, nil, nil)
      pn_sel:drawLinkToPacenote(pn_next)
    end
  elseif pn_sel then
    pn_sel:drawDebugPacenote('selected', self._hover_waypoint_id, nil, pn_prev, pn_next)
    self:drawPacenotesAsRainbow(pn_sel)
  else
    self:drawPacenotesAsRainbow(nil)
  end
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
  for i,pacenote in pairs(self.pacenotes.objects) do
    for j,wp in pairs(pacenote.pacenoteWaypoints.objects) do
      wps[wp.id] = wp
      -- table.insert(wps, wp)
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
