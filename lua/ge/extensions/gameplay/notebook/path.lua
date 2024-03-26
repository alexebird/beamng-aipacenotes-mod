local logTag = 'aipacenotes'
local C = {}
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local SettingsManager = require('/lua/ge/extensions/gameplay/aipacenotes/settingsManager')

local currentVersion = "2"

function C:getNextUniqueIdentifier()
  self._uid = self._uid + 1
  return self._uid
end

function C:init(name)
  self._uid = 0

  SettingsManager.reset()

  self.name = name or re_util.default_notebook_name
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

  self.codrivers:create() -- add default

  self.pacenotes = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "pacenotes",
    self,
    require('/lua/ge/extensions/gameplay/notebook/pacenote')
  )

  self:loadStaticPacenotes()

  self.id = self:getNextUniqueIdentifier()
  self.fname = nil
  self.validation_issues = {}
end

function C:appendPacenotes(pacenotes)
  for _,pn in ipairs(pacenotes) do
    local newPn = self.pacenotes:create()
    newPn:onDeserialized(pn, {})
  end
end

function C:deleteAllPacenotes()
  self.pacenotes = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "pacenotes",
    self,
    require('/lua/ge/extensions/gameplay/notebook/pacenote')
  )
end

function C:missionId()
  if not self.fname then return nil end
  local pattern = "/gameplay/missions/(.-)/"..re_util.aipPath
  local segment = self.fname:match(pattern)
  return segment
end

function C:getMissionDir()
  if not self.fname then return nil end

  -- looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2\aipacenotes\notebooks\
  local notebooksDir = self:dir()
  -- log('D', 'wtf', 'notebooksDir: '..notebooksDir)
  local aipDir = re_util.stripBasename(notebooksDir)
  -- log('D', 'wtf', 'aipDir: '..aipDir)
  -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2\aipacenotes
  local missionDir = re_util.stripBasename(aipDir)
  -- log('D', 'wtf', 'missionDir: '..missionDir)
  -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2

  return missionDir
end

function C:dir()
  if not self.fname then return nil end
  local dir, filename, ext = path.split(self.fname)
  return dir
end

function C:basename()
  if not self.fname then return nil end
  local dir, filename, ext = path.split(self.fname)
  return filename
end

function C:basenameNoExt()
  if not self.fname then return nil end
  local _, filename, _ = path.splitWithoutExt(self.fname)
  _, filename, _ = path.splitWithoutExt(filename)
  return filename
end

function C:setFname(newFname)
  self.fname = newFname
end

function C:save(fname)
  fname = fname or self.fname
  if not fname then
    log('W', logTag, 'couldnt save notebook because no filename was set')
    return false
  end

  local json = self:onSerialize()
  local saveOk = jsonWriteFile(fname, json, true)
  if not saveOk then
    log('E', logTag, 'error saving notebook')
  end
  log('I', logTag, 'saved notebook: '..fname)
  return saveOk
end

function C:reload()
  if not self.fname then return end

  local json = jsonReadFile(self.fname)
  if not json then
    log('E', logTag, 'couldnt find notebook file')
  end

  self:onDeserialized(json)
end

function C:validate()
  self.validation_issues = {}

  local codriverNameSet = {}
  local uniqueCount = 0
  for _,codriver in ipairs(self.codrivers.sorted) do
    if not codriverNameSet[codriver.name] then
      -- Count only if the name hasn't been encountered before
      uniqueCount = uniqueCount + 1
      codriverNameSet[codriver.name] = true
    end
  end
  if uniqueCount < #self.codrivers.sorted then
    table.insert(self.validation_issues, 'Duplicate codriver names')
  elseif #self.codrivers.sorted == 0 then
    table.insert(self.validation_issues, 'At least one Codriver is required')
  end
end

function C:is_valid()
  return #self.validation_issues == 0
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
  for i, v in ipairs(self.pacenotes.sorted) do
    -- Pattern to match a name ending with a number: capture the non-numeric part and the numeric part
    local baseName, number = string.match(v.name, "(.-)%s*([%d%.]+)$")

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

-- local function calcPointForSegment(racePath, segmentId)
--   local pathnodes = racePath.pathnodes.objects
--   local segment = racePath.segments.objects[segmentId]
--   local from = pathnodes[segment.from]
--   local to = pathnodes[segment.to]
--   local center = (from.pos + to.pos) / 2
--   -- log("D", 'wtf', dumps(center))
--   -- debugDrawer:drawSphere((center),
--   --   50,
--   --   ColorF(1, 0, 0, 1)
--   -- )
--   return center
-- end

-- local function findClosestSegmentCenter(pos, segmentCenters)
--   local minDist = 4294967295
--   local closest_seg_id = nil
--   local dist = nil
--
--   for seg_id,center_pos in pairs(segmentCenters) do
--     dist = pos:distance(center_pos)
--     if dist < minDist then
--       minDist = dist
--       closest_seg_id = seg_id
--     end
--   end
--
--   return closest_seg_id
-- end

-- function C:autoAssignSegments(racePath)
--   local segment_centers = {}
--
--   for seg_id,segment in pairs(racePath.segments.objects) do
--     local center = calcPointForSegment(racePath, seg_id)
--     segment_centers[seg_id] = center
--   end
--
--   -- clear the segments. probably not necessary.
--   for _,pacenote in ipairs(self.pacenotes.sorted) do
--     pacenote.segment = -1
--   end
--
--   for _,pacenote in ipairs(self.pacenotes.sorted) do
--     local audioTrigger = pacenote:getActiveFwdAudioTrigger()
--     if audioTrigger then
--       local closest_seg_id = findClosestSegmentCenter(audioTrigger.pos, segment_centers)
--       pacenote.segment = closest_seg_id
--     end
--   end
-- end

local function drawPacenotesAsRainbow(pacenotes, selection_state)
  for _,pacenote in ipairs(pacenotes) do
    pacenote:drawDebugPacenoteNoSelection(selection_state)
  end
end

local function drawPacenotesAsBackground(pacenotes, skip_pn, selection_state)
  -- old style
  -- for _,pacenote in ipairs(pacenotes) do
  --   if pacenote.id ~= skip_pn.id then
  --     pacenote:drawDebugPacenoteBackground(selection_state)
  --   end
  -- end

  -- new style
  local skip_i = nil
  for i,pacenote in ipairs(pacenotes) do
    if pacenote.id == skip_pn.id then
      skip_i = i
      break
    end
  end

  if skip_i then
    local show_after_count = 1
    local start_i = skip_i+1
    local end_i = start_i+show_after_count-1
    for i = start_i,end_i do
      local pacenote = pacenotes[i]
      if pacenote then
        pacenote:drawDebugPacenoteBackground(selection_state)
      end
    end

    local show_before_count = 1
    start_i = skip_i-show_before_count
    end_i = skip_i-1
    for i = start_i,end_i do
      local pacenote = pacenotes[i]
      if pacenote then
        pacenote:drawDebugPacenoteBackground(selection_state)
      end
    end
  end
end

function C:getAdjacentPacenoteSet(selected_pn_id)
  local pacenotes = self.pacenotes.sorted

  local function getOrNullify(i)
    local pn = pacenotes[i]
    if pn and not pn.missing then
      return pn
    else
      return nil
    end
  end

  for i,pacenote in ipairs(pacenotes) do
    if pacenote.id == selected_pn_id then
      return getOrNullify(i-1), pacenote, getOrNullify(i+1)
    end
  end

  return nil, nil, nil
end

function C:drawDebugNotebook(selection_state)
  local pacenotes = self.pacenotes.sorted
  local pn_prev, pn_sel, pn_next = self:getAdjacentPacenoteSet(selection_state.selected_pn_id)

  if pn_sel and selection_state.selected_wp_id then
    pn_sel:drawDebugPacenoteSelected(selection_state)

    if editor_rallyEditor.getPrefShowPreviousPacenote() and pn_prev and pn_prev.id ~= pn_sel.id then
      pn_prev:drawDebugPacenotePrev(selection_state, pn_sel)
    end

    if editor_rallyEditor.getPrefShowNextPacenote() and pn_next and pn_next.id ~= pn_sel.id then
      pn_next:drawDebugPacenoteNext(selection_state, pn_sel)
    end
  elseif pn_sel then
    pn_sel:drawDebugPacenoteSelected(selection_state)
    drawPacenotesAsBackground(pacenotes, pn_sel, selection_state)
  else
    drawPacenotesAsRainbow(pacenotes, selection_state)
  end
end

function C:drawDebugNotebookForPartitionedSnaproad()
  local pacenotes = self.pacenotes.sorted
  -- local pn_prev, pn_sel, pn_next = self:getAdjacentPacenoteSet(selection_state.selected_pn_id)

  -- if pn_sel and selection_state.selected_wp_id then
  --   pn_sel:drawDebugPacenoteSelected(selection_state)
  --
  --   if editor_rallyEditor.getPrefShowPreviousPacenote() and pn_prev and pn_prev.id ~= pn_sel.id then
  --     pn_prev:drawDebugPacenotePrev(selection_state, pn_sel)
  --   end
  --
  --   if editor_rallyEditor.getPrefShowNextPacenote() and pn_next and pn_next.id ~= pn_sel.id then
  --     pn_next:drawDebugPacenoteNext(selection_state, pn_sel)
  --   end
  -- elseif pn_sel then
  --   pn_sel:drawDebugPacenoteSelected(selection_state)
  --   drawPacenotesAsBackground(pacenotes, pn_sel, selection_state)
  -- else
    -- drawPacenotesAsRainbow(pacenotes, selection_state)
  -- end

  local selection_state = {
    hover_wp_id = nil,
    selected_wp_id = nil,
  }
  for _,pacenote in ipairs(pacenotes) do
    pacenote:drawDebugPacenotePartitionedSnaproad(selection_state)
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
    -- static_pacenotes = self.static_pacenotes:onSerialize(),
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

  self:loadStaticPacenotes()
end

function C:loadStaticPacenotes()
  -- self.static_pacenotes:clear()
  self.static_pacenotes = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "static_pacenotes",
    self,
    require('/lua/ge/extensions/gameplay/notebook/pacenote')
  )

  -- local static_pn_data = self:generateStaticPacenotesData()
  local static_pn_data = {static_pacenotes = {}}

  local fname = re_util.staticPacenotesFname

  -- log('I', logTag, 'reading static_pacenotes file: ' .. tostring(fname))
  local json = jsonReadFile(fname)
  if json then
    static_pn_data = json
  else
    log('E', logTag, 'unable to read static_pacenotes file at: ' .. tostring(fname))
  end

  self.static_pacenotes:onDeserialized(static_pn_data.static_pacenotes, {})
end

-- static notes are hardcoded and set on onDeserialized only.
-- function C:generateStaticPacenotesData()
--   local notes = {}
--   local oldId = 1
--
--   local damage_1 = {
--     oldId = oldId,
--     name = 'damage_1',
--     notes = {
--       english = {
--         before = '',
--         note = 'We just took some damage!',
--         after = '',
--       }
--     },
--     metadata = {static=true},
--     pacenoteWaypoints = {}
--   }
--   table.insert(notes, damage_1)
--   oldId = oldId+1
--
--   local go_time_1 = {
--     oldId = oldId,
--     name = 'go_1/c',
--     notes = {
--       english = {
--         before = '',
--         note = 'Go!',
--         after = '',
--       }
--     },
--     metadata = {static=true},
--     pacenoteWaypoints = {}
--   }
--   table.insert(notes, go_time_1)
--   oldId = oldId+1
--
--   local numbers = {'one', 'two', 'three'}
--   for i,num in ipairs(numbers) do
--     local countdown = {
--       oldId = oldId,
--       name = 'countdown_'..i..'/c',
--       notes = {
--         english = {
--           before = '',
--           note = num,
--           after = '',
--         }
--       },
--       metadata = {static=true},
--       pacenoteWaypoints = {}
--     }
--     table.insert(notes, countdown)
--     oldId = oldId+1
--   end
--
--   local finish_1 = {
--     oldId = oldId,
--     name = 'finish_1/c',
--     notes = {
--       english = {
--         before = '',
--         note = 'Thats it, bring the car to a stop.',
--         after = '',
--       }
--     },
--     metadata = {static=true},
--     pacenoteWaypoints = {}
--   }
--   table.insert(notes, finish_1)
--   oldId = oldId+1
--
--   return notes
-- end

-- function C:copy()
--   local cpy = require('/lua/ge/extensions/gameplay/notebook/path')('Copy of ' .. self.name)
--   cpy.onDeserialized(self.onSerialize())
--   return cpy
-- end

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
    if not lang_set[codriver.language] then
      lang_set[codriver.language] = {}
    end
    table.insert(lang_set[codriver.language], codriver)
  end
  local languages = {}
  for lang, codrivers in pairs(lang_set) do
    table.insert(languages, { language = lang , codrivers = codrivers })
  end
  table.sort(languages, function(a, b)
    if a.lang and b.lang then
      return a.lang < b.lang
    else
      return false
    end
  end)
  return languages
end

function C:setAllRadii(newRadius, wpType)
  for i, pacenote in pairs(self.pacenotes.objects) do
    pacenote:setAllRadii(newRadius, wpType)
  end
end

function C:allToTerrain()
  for i, pacenote in pairs(self.pacenotes.objects) do
    pacenote:allToTerrain()
  end
end

function C:missionSettings()
  local ms = SettingsManager.getMissionSettings()
  if not ms then
    SettingsManager.load(self)
    ms = SettingsManager.getMissionSettings()
  end
  return ms
end

function C:mainSettings()
  local ms = SettingsManager.getMainSettings()
  if not ms then
    SettingsManager.load(self)
    ms = SettingsManager.getMainSettings()
  end
  return ms
end

function C:selectedCodriver()
  if not self:missionSettings() then
    error('must set mission settings on notebook')
  end

  local codriver = self:getCodriverByName(self:missionSettings().notebook.codriver)

  if not codriver then
    log('I', logTag, 'RallyManager setup no codriver')
    error('couldnt load codriver: '..self:missionSettings().notebook.codriver)
  end

  return codriver
end

function C:selectedCodriverLanguage()
  local codriver = self:selectedCodriver()
  return codriver.language
end

function C:normalizeNotes(force)
  local lang = self:selectedCodriverLanguage()
  local last = false

  for i,pacenote in ipairs(self.pacenotes.sorted) do
    last = i == #self.pacenotes.sorted
    pacenote:normalizeNoteText(lang, last, force or false)
  end
end

-- Generalized rounding function
local function custom_round(dist, round_to)
  return math.floor(dist / round_to + 0.5) * round_to
end

-- Function to round the distance based on given rules
local function round_distance(dist)
  if dist >= re_util.dist_km_threshold then
    return custom_round(dist, re_util.dist_round_km) / re_util.dist_km_threshold, re_util.kilo_unit_str
  elseif dist >= re_util.dist_large_threshold then
    return custom_round(dist, re_util.dist_round_large)
  else
    return custom_round(dist, re_util.dist_round_small)
  end
end

local function distance_to_string(dist)
  dist = math.floor(dist)
  local rounded_dist, unit = round_distance(dist)
  local dist_str = tostring(rounded_dist)

  if unit == re_util.kilo_unit_str then
    dist_str = dist_str .. " " .. unit
  elseif rounded_dist >= re_util.dist_large_threshold and rounded_dist % re_util.dist_large_threshold ~= 0 then
    -- separate digits if not a multiple of 100
    dist_str = dist_str:sub(1, 1) .. " " .. dist_str:sub(2)
  end

  return dist_str
end

local function findNextNonIsolated(pacenotes, i)
  i = i + 1
  local pn_next = pacenotes[i]
  while pn_next and pn_next.isolate do
    pn_next = pacenotes[i]
    i = i+1
  end
  return pn_next
end

local function getDistanceCallShorthand(mainSettings, dist)
  if dist <= mainSettings:getDistanceCallLevel1Threshold() then
    return mainSettings:getDistanceCallLevel1Text()
  elseif dist <= mainSettings:getDistanceCallLevel2Threshold() then
    return mainSettings:getDistanceCallLevel2Text()
  elseif dist <= mainSettings:getDistanceCallLevel3Threshold() then
    return mainSettings:getDistanceCallLevel3Text()
  else
    return nil
  end
end


function C:autofillDistanceCalls()
  local lang = self:selectedCodriverLanguage()

  -- first clear everything
  for _,pacenote in ipairs(self.pacenotes.sorted) do
    if pacenote:getNoteFieldBefore(lang) ~= re_util.autofill_blocker and pacenote:getNoteFieldBefore(lang) ~= re_util.autodist_internal_level1 then
      pacenote:setNoteFieldBefore(lang, '')
    end
    if pacenote:getNoteFieldAfter(lang) ~= re_util.autofill_blocker and pacenote:getNoteFieldAfter(lang) ~= re_util.autodist_internal_level1 then
      pacenote:setNoteFieldAfter(lang, '')
    end
  end

  local next_prepend = ''

  for i,pacenote in ipairs(self.pacenotes.sorted) do
    -- Apply any prepended text from the previous iteration
    if not pacenote.isolate and next_prepend ~= '' then
      if pacenote:getNoteFieldBefore(lang) ~= re_util.autofill_blocker then
        pacenote:setNoteFieldBefore(lang, next_prepend)
      end
      next_prepend = ''
    end

    -- local pn_next = self.pacenotes.sorted[i + 1]
    local pn_next = findNextNonIsolated(self.pacenotes.sorted, i)

    if not pacenote.isolate and pn_next and not pn_next.missing then
      local dist = pacenote:distanceCornerEndToCornerStart(pn_next)
      local dist_str = distance_to_string(dist)

      -- Decide what to do based on the distance
      local shorthand = getDistanceCallShorthand(self:mainSettings(), dist)
      if shorthand then
        next_prepend = shorthand
      else
        if pacenote:getNoteFieldAfter(lang) ~= re_util.autofill_blocker then
          pacenote:setNoteFieldAfter(lang, dist_str)
        end
      end
    end

  end
end

function C:getCodriverByName(codriver_name)
  local codriver = nil
  for _,cd in ipairs(self.codrivers.sorted) do
    if cd.name == codriver_name then
      codriver = cd
      break
    end
  end

  return codriver
end

function C:cachePacenoteFgData(codriver)
  for _,pn in ipairs(self.pacenotes.sorted) do
    pn:asFlowgraphData(codriver)
  end
end

function C:findNClosestPacenotes(pos, n)
  -- Table to store objects and their distances
  local distances = {}

  -- Calculate each object's distance from the input position and store it
  for _,pacenote in ipairs(self.pacenotes.sorted) do
    local distance = pos:distance(pacenote:getActiveFwdAudioTrigger().pos)  -- using the provided distance method
    table.insert(distances, {pacenote = pacenote, distance = distance})
  end

  -- Sort the objects by distance
  table.sort(distances, function(a, b) return a.distance < b.distance end)

  -- Retrieve the N closest objects
  local closest = {}
  n = math.min(#self.pacenotes.sorted, n)
  for i = 1, n do
    if distances[i] then  -- Ensure there's an object to add
      table.insert(closest, distances[i].pacenote)
    end
  end

  return closest
end

function C:getStaticPacenoteByName(name)
  for _,spn in ipairs(self.static_pacenotes.sorted) do
    if spn.name == name then
      return spn
    end
  end

  return nil
end

local function normalizeWeights(list)
  local sum = 0.0
  for _, item in ipairs(list) do
    local w = item[3]
    sum = sum + w
  end

  for _, item in ipairs(list) do
    local newW = item[3] / sum
    -- print('('..tostring(item[3])..' - '..tostring(minWeight)..') / ('..tostring(maxWeight)..' - '..tostring(minWeight)..')')
    -- print(tostring(newW))
    item[3] = newW
  end
end

local function fillRemainingWeights(list)
  for _, item in ipairs(list) do
    if not item[3] then
      item[3] = 0.5
    end
  end
end

function C:getRandomStaticPacenote(desiredPrefix)
  local weightedNotes = {}

  for _,spn in ipairs(self.static_pacenotes.sorted) do
    local prefix, id = string.match(spn.name, "^([^_]+)_([%d]+)$")

    if prefix == desiredPrefix then
      local w = nil
      if spn.metadata and spn.metadata.weight then
        w = tonumber(spn.metadata.weight)
        if not w then
          log('W', logTag, 'weight of "'..spn.metadata.weight..'" could not be parsed. setting to 0.')
          w = 0
        end
      end

      id = tonumber(id)
      table.insert(weightedNotes, { prefix, id, w} )
    end
  end

  fillRemainingWeights(weightedNotes)
  normalizeWeights(weightedNotes)

  for i,e in ipairs(weightedNotes) do
    local prefix, id, w = e[1], e[2], e[3]
    print(prefix .. ', ' .. tostring(id) .. ', w='..tostring(w))
  end

  local rand = math.random()
  print('rand: '..tostring(rand))
  local cumulativeWeight = 0
  local rv = weightedNotes[1]

  for _, item in ipairs(weightedNotes) do
    cumulativeWeight = cumulativeWeight + item[3]
    if rand <= cumulativeWeight then
      rv = item
      break
    end
  end

  return rv[1]..'_'..tostring(rv[2])
end

function C:setAdjacentNotes(pacenote_id)
  local pacenotesSorted = self.pacenotes.sorted
  for i, note in ipairs(pacenotesSorted) do
    if pacenote_id == note.id then
      local prevNote = pacenotesSorted[i-1]
      local nextNote = pacenotesSorted[i+1]
      note:setAdjacentNotes(prevNote, nextNote)
    else
      note:clearAdjacentNotes()
    end
  end
end

function C:markAllTodo()
  for _,pn in ipairs(self.pacenotes.sorted) do
    pn:markTodo()
  end
end

function C:clearAllTodo()
  for _,pn in ipairs(self.pacenotes.sorted) do
    pn:clearTodo()
  end
end

function C:markRestTodo(pacenote)
  if not pacenote then return end

  local hitPacenote = false
  for _,pn in ipairs(self.pacenotes.sorted) do
    if pn.id == pacenote.id then
      hitPacenote = true
    end
    if hitPacenote then
      pn:markTodo()
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
