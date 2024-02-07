local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

local logTag = 'aipacenotes'

local default_settings = {
  last_mission_ids = {},
  last_load_states = {},
}

function C:init()
  self.fname = re_util.aipSettingsRoot..'/recce.json'

  self.last_mission_ids = default_settings.last_mission_ids
  self.last_load_states = default_settings.last_load_states
end

function C:load()
  if not self.fname  then
    log('W', logTag, 'load: recce settings fname is nil: '..tostring(self.fname))
    return false
  end

  if not FS:fileExists(self.fname) then
    log('W', logTag, 'load: recce settings fname doesnt exist: '..tostring(self.fname))
    return false
  end

  local json = jsonReadFile(self.fname)
  if not json then
    log('E', logTag, 'load: couldnt find recce settings file: '..tostring(self.fname))
    return false
  end

  self:onDeserialized(json)
  log('I', logTag, 'loaded recce settings from '..tostring(self.fname))

  return true
end

function C:save()
  local json = self:onSerialize()
  jsonWriteFile(self.fname, json, true)
end

function C:onSerialize()
  local ret = {
    last_mission_ids = self.last_mission_ids,
    last_load_states = self.last_load_states
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  self.last_mission_ids = data.last_mission_ids or default_settings.last_mission_ids
  self.last_load_states = data.last_load_states or default_settings.last_load_states
end

function C:setLastMissionId(level, id)
  self.last_mission_ids[level] = id
  self:save()
end

function C:getLastMissionId(level)
  return self.last_mission_ids[level]
end

function C:setLastLoadState(level, state)
  self.last_load_states[level] = state
  self:save()
end

function C:getLastLoadState(level)
  return self.last_load_states[level]
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
