-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

local default_settings = {
  notebook = {
    filename = "primary.notebook.json",
    codriver = "Sophia",
  },
  transcripts = {
    full_course = "full_course.transcripts.json",
    -- curr = "curr.transcripts.json",
  }
}

function C:getNextUniqueIdentifier()
  self._uid = self._uid + 1
  return self._uid
end

function C:init(fname)
  self._uid = 0
  self.notebook = default_settings.notebook
  self.transcripts = default_settings.transcripts
  self.missionDir = nil -- can be set by AIP Loader flowgraph node.
  self.fname = fname

  self.id = self:getNextUniqueIdentifier()
end

function C:defaultSettings()
  return default_settings
end

function C:onSerialize()
  local ret = {
    notebook = self.notebook,
    transcripts = self.transcripts,
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  self.notebook = data.notebook or default_settings.notebook
  self.transcripts = data.transcripts or default_settings.transcripts
end

function C:write()
  local json = self:onSerialize()
  jsonWriteFile(self.fname, json, true)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
