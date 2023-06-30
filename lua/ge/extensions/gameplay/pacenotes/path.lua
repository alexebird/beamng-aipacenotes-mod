-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init(name)
  self._uid = 0
  self.versions = {}
end

function C:getNextUniqueIdentifier()
  self._uid = self._uid + 1
  return self._uid
end

function C:createNew()
  local newId = self:getNextUniqueIdentifier()
  local newEntry = {
    id = newId,
    installed = false,
    name = 'New version #' .. newId,
    voice = 'british_female',
    authors = '',
    description = '',
    pacenotes = {}, -- this is NOT a /lua/ge/extensions/gameplay/util/sortedList instance like in gameplay/race/path.lua.
  }
  table.insert(self.versions, newEntry)
  return newEntry
end

function C:onSerialize()
  local ret = {
    versions = self.versions,
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  self.versions = data.versions or {}

  local highestId = 0
  for i, ver in ipairs(self.versions) do
    if ver.id > highestId then
      highestId = ver.id
    end
  end

  self._uid = highestId
end

-- function C:copy()
--   local cpy = require('/lua/ge/extensions/gameplay/pacenotes/path')('Copy of ' .. self.name)
--   cpy.onDeserialized(self.onSerialize())
--   return cpy
-- end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end