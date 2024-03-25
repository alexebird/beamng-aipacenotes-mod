local MainSettings = require('/lua/ge/extensions/gameplay/aipacenotes/mainSettings')
local MissionSettings = require('/lua/ge/extensions/gameplay/notebook/missionSettings')
local RecceSettings = require('/lua/ge/extensions/gameplay/aipacenotes/recceSettings')

local M = {}

local mainSettings = nil
local missionSettings = nil
local recceSettings = nil

local function load()
  mainSettings = MainSettings()
  mainSettings:load()

  missionSettings = MissionSettings()
  missionSettings:load()

  recceSettings = RecceSettings()
  recceSettings:load()
end

M.load = load

return M
