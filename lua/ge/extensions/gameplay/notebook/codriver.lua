-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')

local C = {}
local modes = {"manual","navgraph"}
local logTag = 'aipacenotes_pacenote'

function C:init(notebook, name, forceId)
  self.notebook = notebook

  self.id = forceId or notebook:getNextUniqueIdentifier()
  self.name = name or "Codriver " .. self.id
  self.language = "english"
  self.voice = "british_lady"

  self.sortOrder = 999999
end

-- used by pacenoteWaypoints.lua
-- function C:getNextUniqueIdentifier()
  -- return self.notebook:getNextUniqueIdentifier()
-- end

function C:onSerialize()
  local ret = {
    oldId = self.id,
    name = self.name,
    language = self.language,
    voice = self.voice,
  }

  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.name = data.name
  self.language = data.language
  self.voice = data.voice
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end