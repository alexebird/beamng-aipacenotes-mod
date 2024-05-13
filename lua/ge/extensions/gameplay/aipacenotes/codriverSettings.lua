local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

local logTag = 'aipacenotes'

local default_settings = {
  volume = 0.8,
  timing = 8.0,
}

function C:init()
  self.fname = re_util.aipSettingsRoot..'/codriver.json'
  self:_reset()
end

function C:_reset()
  self.volume = default_settings.volume
  self.timing = default_settings.timing
end

function C:load()
  self:_reset()

  if not self.fname  then
    log('W', logTag, 'load: codriver settings fname is nil: '..tostring(self.fname))
    return false
  end

  if not FS:fileExists(self.fname) then
    log('W', logTag, 'load: codriver settings fname doesnt exist: '..tostring(self.fname))
    return false
  end

  local json = jsonReadFile(self.fname)
  if not json then
    log('E', logTag, 'load: couldnt find codriver settings file: '..tostring(self.fname))
    return false
  end

  self:onDeserialized(json)
  log('I', logTag, 'loaded codriver settings from '..tostring(self.fname))

  return true
end

function C:save()
  local json = self:onSerialize()
  jsonWriteFile(self.fname, json, true)
end

function C:onSerialize()
  local ret = {
    volume = self.volume,
    timing = self.timing,
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  self.volume = data.volume or default_settings.volume
  self.timing = data.timing or default_settings.timing
end

function C:setVolume(val)
  self.volume = val
  self:save()
end
function C:getVolume()
  return self.volume
end

function C:setTiming(val)
  self.timing = val
  self:save()
end
function C:getTiming()
  return self.timing
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
