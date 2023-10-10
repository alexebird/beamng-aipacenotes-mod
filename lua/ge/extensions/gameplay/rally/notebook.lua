-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init(path, name, forceId)
  self.path = path

  self.id = forceId or path:getNextUniqueIdentifier()
  self.name = name or "Notebook " .. self.id
  self.authors = ''
  self.description = ''
  self.installed = false
  self.voice = 'british_female'

  -- self.voice_params = {
  --   gcp_language_code = 'en-GB',
  --   gcp_voice_name = 'en-GB-Neural2-A',
  -- }

  self.pacenotes = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "pacenotes",
    self,
    require('/lua/ge/extensions/gameplay/rally/pacenote')
  )

  self.sortOrder = 999999
end

function C:allWaypoints()
  local wps = {}
  for i, pacenote in pairs(self.pacenotes.objects) do
    for i, waypoint in pairs(pacenote.pacenoteWaypoints.objects) do
      table.insert(wps, waypoint.id, waypoint)
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

function C:getNextUniqueIdentifier()
  -- self._uid = self._uid + 1
  -- return self._uid
  return self.path:getNextUniqueIdentifier()
end

function C:onSerialize()
  local ret = {
    oldId = self.id,
    name = self.name,
    authors = self.authors,
    description = self.description,
    installed = self.installed,
    voice = self.voice,
    pacenotes = self.pacenotes:onSerialize(),
  }
  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.name = data.name
  self.description = string.gsub(data.description or "", "\\n", "\n")
  self.authors = data.authors or "Anonymous"
  self.installed = data.installed or false
  self.voice = data.voice or "british_female"
  self.pacenotes:onDeserialized(data.pacenotes, oldIdMap)
end

function C:drawDebug(drawMode, clr, extraText)
  self.pacenotes:drawDebug(drawMode, clr, extraText)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end