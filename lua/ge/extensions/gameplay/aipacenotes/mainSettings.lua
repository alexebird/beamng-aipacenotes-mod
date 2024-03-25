local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

local logTag = 'aipacenotes-mainSettings'

function C:init()
  self.fname_default = re_util.aipSettingsRoot..'/default.mainSettings.json'
  self.fname_languages = re_util.aipSettingsRoot..'/languages.mainSettings.json'
  self.language = nil
  self:_reset()
end

function C:setLanguage(language)
  self.language = language
end

function C:_reset()
  self.settingsData_default = nil
  self.settingsData_languages = nil
end

local function loadFname(settingsFname)
  if not settingsFname  then
    log('W', logTag, 'load: settingsFname is nil')
    return false
  end

  if not FS:fileExists(settingsFname) then
    log('W', logTag, 'load: mainSettings fname doesnt exist: '..tostring(settingsFname))
    return false
  end

  local json = jsonReadFile(settingsFname)
  if not json then
    log('E', logTag, 'load: couldnt find mainSettings file: '..tostring(settingsFname))
    return false
  end

  return json
end

function C:load()
  self:_reset()

  self.settingsData_default = loadFname(self.fname_default)
  if not self.settingsData_default then
    return false
  end

  self.settingsData_languages = loadFname(self.fname_languages)
  if not self.settingsData_languages then
    return false
  end

  -- print(dumps(self.settingsData_default))
  -- print(dumps(self.settingsData_languages))

  return true
end

-- function C:save()
-- end

function C:_mergedSettingsData()
  local languageData = self.settingsData_languages[self.language]
  local settingsData_merged = tableMergeRecursive(self.settingsData_default.default, languageData)
  return settingsData_merged
end

function C:getPunctuationLastNote()
  -- print(dumps(self:_mergedSettingsData()))
  return self:_mergedSettingsData().punctuation.last_note or re_util.default_punctuation_last
end

function C:getPunctuationDefault()
  return self:_mergedSettingsData().punctuation.default or re_util.default_punctuation
end

function C:getDistanceCallLevel1Threshold()
  return self:_mergedSettingsData().distance_calls.level1.threshold or 5
end
function C:getDistanceCallLevel1Text()
  return self:_mergedSettingsData().distance_calls.level1.text or '<none>'
end

function C:getDistanceCallLevel2Threshold()
  return self:_mergedSettingsData().distance_calls.level2.threshold or 20
end
function C:getDistanceCallLevel2Text()
  return self:_mergedSettingsData().distance_calls.level2.text or 'into'
end

function C:getDistanceCallLevel3Threshold()
  return self:_mergedSettingsData().distance_calls.level3.threshold or 40
end
function C:getDistanceCallLevel3Text()
  return self:_mergedSettingsData().distance_calls.level3.text or 'and'
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
