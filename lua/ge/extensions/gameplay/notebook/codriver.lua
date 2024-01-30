local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes'

function C:init(notebook, name, forceId)
  self.notebook = notebook

  if #self.notebook.codrivers.sorted == 0 then
    name = re_util.default_codriver_name
  end

  self.id = forceId or notebook:getNextUniqueIdentifier()
  self.name = name or ("Codriver " .. self.id)
  self.language = re_util.default_codriver_language
  self.voice = re_util.default_codriver_voice

  self.sortOrder = 999999
end

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
