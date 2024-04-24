local CodriverSettings = require('/lua/ge/extensions/gameplay/aipacenotes/codriverSettings')
local SettingsManager = require('/lua/ge/extensions/gameplay/aipacenotes/settingsManager')

local M = {}
local logTag = 'aip-codriverApp'


local function loadCodriverSettings()
  local settings = CodriverSettings()
  settings:load()
  return settings
end

local function setTimingSetting(val)
  log('I', logTag, 'codriverApp setTimingSetting val='..tostring(val))

  if extensions.isExtensionLoaded("gameplay_aipacenotes") then
    local rallyManager = gameplay_aipacenotes.getRallyManager()
    if rallyManager then
      rallyManager:setDrivelineTrackerThreshold(val)
    end
  end

  if extensions.isExtensionLoaded("ui_aipacenotes_recceApp") then
    local rallyManager = ui_aipacenotes_recceApp.getRallyManager()
    if rallyManager then
      rallyManager:setDrivelineTrackerThreshold(val)
    end
  end

  local settings = loadCodriverSettings()
  settings:setTiming(val)
end

local function setVolumeSetting(val)
  log('I', logTag, 'codriverApp setVolumeSetting val='..tostring(val))

  local settings = loadCodriverSettings()
  settings:setVolume(val)
end

local function onExtensionLoaded()
  log('I', logTag, 'codriverApp.onExtensionLoaded')
end

M.onExtensionLoaded = onExtensionLoaded

M.setTimingSetting = setTimingSetting
M.setVolumeSetting = setVolumeSetting

return M
