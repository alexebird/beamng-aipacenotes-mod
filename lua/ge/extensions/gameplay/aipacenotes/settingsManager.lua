local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local MainSettings = require('/lua/ge/extensions/gameplay/aipacenotes/mainSettings')
local MissionSettings = require('/lua/ge/extensions/gameplay/notebook/missionSettings')
-- local RecceSettings = require('/lua/ge/extensions/gameplay/aipacenotes/recceSettings')

local M = {}

local mainSettings = nil
local missionSettings = nil
-- local recceSettings = nil

local function buildMissionSettingsPath(missionDir)
  local settingsFname = missionDir..'/'..re_util.aipPath..'/'..re_util.missionSettingsFname
  return settingsFname
end

local function loadMissionSettingsForMissionDir(missionDir)
  local settingsFname = buildMissionSettingsPath(missionDir)
  local settings = MissionSettings(settingsFname)
  if settings:load() then
    return settings, nil
  end
  return nil, "error loading mission settings"
end

local function loadMissionSettingsForNotebook(notebook)
  return loadMissionSettingsForMissionDir(notebook:getMissionDir())
end

local function getMissionSettings()
  return missionSettings
end

local function getMainSettings()
  return mainSettings
end

-- MainSettings can be a function of the selected codriver's language, if there
-- are settings set for that language in languages.mainSettings.json.
--
-- The notebook determines the language via the selected codriver
--
-- The MissionSettings tracks the selected codriver.
local function load(notebook)
  local missionSettingsPath = buildMissionSettingsPath(notebook:getMissionDir())
  missionSettings = MissionSettings(missionSettingsPath)
  missionSettings:load()

  mainSettings = MainSettings(notebook:selectedCodriverLanguage())
  mainSettings:load()

  -- recceSettings = RecceSettings()
  -- recceSettings:load()
end


local function reset()
  mainSettings = nil
  missionSettings = nil
end

M.getMissionSettings = getMissionSettings
M.getMainSettings = getMainSettings

M.reset = reset
M.load = load
M.loadMissionSettingsForMissionDir = loadMissionSettingsForMissionDir
M.loadMissionSettingsForNotebook = loadMissionSettingsForNotebook

return M
