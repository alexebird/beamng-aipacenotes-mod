-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local logTag = 'aipacenotes-transcripts'

local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

function C:getNextUniqueIdentifier()
  if not self._uid then
    self._uid = 0
  end
  self._uid = self._uid + 1
  return self._uid
end

function C:init(fname)
  self.fname = fname

  self.transcripts = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "transcripts",
    self,
    require('/lua/ge/extensions/gameplay/aipacenotes/transcripts/entry')
  )
end

function C:load()
  local json = jsonReadFile(self.fname)
  if not json then
    log('E', logTag, 'couldnt find notebook file')
    return false
  end
  self:onDeserialized(json)
  log('I', logTag, 'loaded '.. (#self.transcripts.sorted) ..' transcripts from '..self.fname)
  return true
end

function C:onSerialize()
  local ret = {
    transcripts = self.transcripts:onSerialize(),
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  local oldIdMap = {}

  self.transcripts:clear()
  -- log('D', logTag, dumps(data.transcripts))
  self.transcripts:onDeserialized(data.transcripts, oldIdMap)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
