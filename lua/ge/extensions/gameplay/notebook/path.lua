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

--   self.sortOrder = 999999

  self.id = self:getNextUniqueIdentifier()

  self._hover_waypoint_id = nil
  self._default_note_lang = 'english'

--   self.pathnodes = require('/lua/ge/extensions/gameplay/util/sortedList')("pathnodes", self, require('/lua/ge/extensions/gameplay/race/pathnode'))
--   self.segments = require('/lua/ge/extensions/gameplay/util/sortedList')("segments", self, require('/lua/ge/extensions/gameplay/race/segment'))
--   self.startPositions = require('/lua/ge/extensions/gameplay/util/sortedList')("startPositions", self, require('/lua/ge/extensions/gameplay/race/startPosition'))

--   self.notebooks = require('/lua/ge/extensions/gameplay/util/sortedList')("notebooks", self, require('/lua/ge/extensions/gameplay/rally/notebook'))
--   self.installedNotebook = nil

  -- This is for backwards compatibility with the un-modded path.lua. Various places
  -- throughout the code expect this variable to be set.
  -- Since we know this field is only used outside of World Editor, we can just set it once upon load.
--   self.pacenotes = nil

--   self.pathnodes.postCreate = function(o)
--     if self.startNode == -1 then
--       self.startNode = o.id
--     end
--   end
--   self.startPositions.postCreate = function(o)
--     if self.defaultStartPosition == -1 then
--       self.defaultStartPosition = o.id
--     end
--   end
--   self.defaultLaps = 1
--   self.config = {}

--   self.hideMission = false
end
---- Debug and Serialization

function C:drawPacenoteModeNormal(pacenote)
  pacenote:drawDebugCustom('normal', self._default_note_lang, self._hover_waypoint_id)
end

-- function C:drawPacenoteModePnSelected(pacenote)
--   pacenote:drawDebugCustom('selected_pacenote', self._default_note_lang, self._hover_waypoint_id, selected_wp_id)
-- end

function C:drawPacenoteModeSelected(pacenote, selected_wp_id)
  pacenote:drawDebugCustom('selected', self._default_note_lang, self._hover_waypoint_id, selected_wp_id)
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
    self:drawPacenoteModeSelected(pn_sel, selected_waypoint_id)
    if pn_prev and pn_prev.id ~= pn_sel.id then
      self:drawPacenoteModePrevious(pn_prev)
      pn_prev:drawLinkToPacenote(pn_sel)
    end
    -- self:drawPacenoteModeNext(pn_next)
  elseif selected_pacenote_id and not selected_waypoint_id then
    local pn_sel = self.pacenotes.sorted[selected_i]
    self:drawPacenoteModeSelected(pn_sel, selected_waypoint_id)

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
function C:reverse()
  if self.endNode ~= -1 then
    self.startNode, self.endNode = self.endNode, self.startNode
  end
  for _, s in pairs(self.segments.objects) do
    s.from, s.to = s.to, s.from
  end
  self.isReversed = not self.isReversed
end

function C:allWaypoints()
  local wps = {}
  for i, pacenote in pairs(self.pacenotes.objects) do
    for j, wp in pairs(pacenote.pacenoteWaypoints.objects) do
      -- if wp.id == 136 or wp.id == 137 then
        -- log('D', 'wtf', 'waypoint['.. wp.id..','..wp.name ..']')
      -- end
      -- table.insert(wps, wp.id, wp)
      wps[wp.id] = wp
    end
  end
  -- log('D', 'wtf', 'waypoint[137]='..(wps[137].name)..','..wps[137].waypointType)
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