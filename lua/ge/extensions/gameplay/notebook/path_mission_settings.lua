-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

local default_settings = {
  notebook = {
        filename = "primary.notebook.json",
        codriver = "Sophia",
  }
}

function C:getNextUniqueIdentifier()
  self._uid = self._uid + 1
  return self._uid
end

function C:init(name)
  self._uid = 0
  self.notebook = default_settings.notebook
  self.missionDir = nil -- can be set by AIP Loader flowgraph node.

  self.id = self:getNextUniqueIdentifier()
end

function C:onSerialize()
  local ret = {
    notebook = self.notebook,
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  self.notebook = data.notebook or ""
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end