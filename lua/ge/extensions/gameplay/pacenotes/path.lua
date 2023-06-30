-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

-- function C:getNextUniqueIdentifier()
--   self._uid = self._uid + 1
--   return self._uid
-- end

function C:init(name)
--   self._uid = 0
  self.current_version = ""
  self.date = os.time()
  self.versions = {}
end

---- Debug and Serialization

-- function C:drawDebug()
--   self.pathnodes:drawDebug()
--   self.segments:drawDebug()
--   self.startPositions:drawDebug()
--   self.pacenotes:drawDebug()
-- end

function C:onSerialize()
  local ret = {
    current_version = self.current_version,
    date = os.time() ,
    versions = self.versions,
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  self.current_version = data.current_version or ""
  self.date = data.date or nil
  self.versions = data.versions or {}
end

function C:copy()
  local cpy = require('/lua/ge/extensions/gameplay/race/path')('Copy of ' .. self.name)
  cpy.onDeserialized(self.onSerialize())
  return cpy
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end