-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local normalizer = require('/lua/ge/extensions/editor/rallyEditor/normalizer')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local currentVersion = "2"

function C:getNextUniqueIdentifier()
  self._uid = self._uid + 1
  return self._uid
end

function C:init(name)
  self._uid = 0
  self.name = ""
  self.description = ""
  self.authors = ""
  self.version = currentVersion
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

function C:nextImportIdent()
  local importIdentifiers = {}

  for _, pacenote in ipairs(self.pacenotes.sorted) do
    -- Extract the alphanumeric identifier from pacenote names that match "Import_X"
    local identifier = string.match(pacenote.name, "^Import_([%w]+)")
    if identifier then
      table.insert(importIdentifiers, identifier)
    end
  end

  -- Sort the identifiers and return the last one
  if #importIdentifiers > 0 then
    table.sort(importIdentifiers)
    local letter = importIdentifiers[#importIdentifiers]
    local asciiValue = string.byte(letter)
    local nextAsciiValue = asciiValue + 1
    local nextLetter = string.char(nextAsciiValue)
    -- if you hit Z, it will return non alphabetic chars.
    return nextLetter
  end

  return 'A' -- have to start somewhere
end

function C:cleanupPacenoteNames()
  -- for i, v in ipairs(self.pacenotes.sorted) do
  --   v.name = "Pacenote "..i
  -- end

  for i, v in ipairs(self.pacenotes.sorted) do
    -- Pattern to match a name ending with a number: capture the non-numeric part and the numeric part
    local baseName, number = string.match(v.name, "(.-)%s*(%d+)$")

    if baseName and number then
      -- If the name has a number at the end, replace it with the new index
      v.name = baseName .. " " .. i
    else
      -- If the name does not have a number at the end, append the index
      v.name = v.name .. " " .. i
    end
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

  self.version = data.version or currentVersion
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
    lang_set[codriver.language] = codriver
  end
  local languages = {}
  for lang, codriver in pairs(lang_set) do
    table.insert(languages, { language = lang , codriver = codriver })
  end
  table.sort(languages, function(a, b)
    return a.lang < b.lang
  end)
  return languages
end

function C:setAllRadii(newRadius, wpType)
  for i, pacenote in pairs(self.pacenotes.objects) do
    pacenote:setAllRadii(newRadius, wpType)
  end
end

local function stripWhitespace(str)
  return str:gsub("^%s*(.-)%s*$", "%1")
end

local function hasPunctuation(last_char)
  return last_char == "." or last_char == "?" or last_char == "!"
end

function C:normalizeNotes(lang)
  lang = lang or self._default_note_lang

  for _,pacenote in ipairs(self.pacenotes.sorted) do
    local note = pacenote:getNoteFieldNote(lang)

    note = stripWhitespace(note)

    if note ~= '' and note ~= re_util.unknown_transcript_str then
      -- add punction if not present
      local last_char = note:sub(-1)
      if  not hasPunctuation(last_char) then
        note = note .. "?"
      end

      pacenote:setNoteFieldNote(lang, note)
    end
  end
end

-- function C:replaceDigits(lang)
--   lang = lang or self._default_note_lang
--
--   for _,pacenote in ipairs(self.pacenotes.sorted) do
--     local note = pacenote:getNoteFieldNote(lang)
--
--     if note ~= '' then
--       note = normalizer.replaceDigits(note)
--       pacenote:setNoteFieldNote(lang, note)
--     end
--   end
-- end

-- Generalized rounding function
local function custom_round(dist, round_to)
  return math.floor(dist / round_to + 0.5) * round_to
end

-- Function to round the distance based on given rules
local function round_distance(dist)
  if dist >= 1000 then
    return custom_round(dist, 250)/1000, "kilometers"
  elseif dist >= 100 then
    return custom_round(dist, 50)
  -- elseif dist >= 100 then
    -- return custom_round(dist, 10)
  else
    return custom_round(dist, 10)
  end
end

local function distance_to_string(dist)
  local rounded_dist, unit = round_distance(dist)
  local dist_str = tostring(rounded_dist)

  if unit == "kilometers" then
    dist_str = dist_str .. " " .. unit
  elseif rounded_dist >= 100 then
    -- dist_str = dist_str:sub(1, 1) .. " " .. dist_str:sub(2)
  end

  return dist_str
end

local written_out_numbers = {
  ["10"] = "ten",
  ["20"] = "twenty",
  ["30"] = "thirty",
  ["40"] = "forty",
  ["50"] = "fifty",
  ["60"] = "sixty",
  ["70"] = "seventy",
  ["80"] = "eighty",
  ["90"] = "ninety",
  ["100"] = "one hundred",
  ["150"] = "one fifty",
  ["200"] = "two hundred",
  ["250"] = "two fifty",
  ["300"] = "three hundred",
  ["350"] = "three fifty",
  ["400"] = "four hundred",
  ["450"] = "four fifty",
  ["500"] = "five hundred",
  ["550"] = "five fifty",
  ["600"] = "six hundred",
  ["650"] = "six fifty",
  ["700"] = "seven hundred",
  ["750"] = "seven fifty",
  ["800"] = "eight hundred",
  ["850"] = "eight fifty",
  ["900"] = "nine hundred",
  ["950"] = "nine fifty",
}

-- Function to convert numeric distances to their written-out form
local function normalize_distance(dist)
  local dist_str = tostring(dist)
  return written_out_numbers[dist_str] or dist_str
end

function C:autofillDistanceCalls()
  local lang = self._default_note_lang

  -- first clear everything
  for i,pacenote in ipairs(self.pacenotes.sorted) do
    pacenote:setNoteFieldBefore(lang, '')
    pacenote:setNoteFieldAfter(lang, '')
  end

  local next_prepend = ''

  for i,pacenote in ipairs(self.pacenotes.sorted) do
    local note = pacenote:getNoteFieldNote(lang)

    -- Apply any prepended text from the previous iteration
    if next_prepend ~= '' then
      pacenote:setNoteFieldBefore(lang, next_prepend)
      next_prepend = ''
    end

    local pn_next = self.pacenotes.sorted[i + 1]
    if pn_next and not pn_next.missing then
      local dist = pacenote:distanceCornerEndToCornerStart(pn_next)
      local dist_str = distance_to_string(math.floor(dist))
      dist_str = normalize_distance(dist_str) .. '.'

      -- Decide what to do based on the distance
      if dist <= 20 then
        next_prepend = "into"
      elseif dist <= 40 then
        next_prepend = "and"
      else
        pacenote:setNoteFieldAfter(lang, dist_str)
      end
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
