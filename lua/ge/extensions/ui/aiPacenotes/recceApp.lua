-- extension name: ui_aipacenotes_recceApp

local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')

local M = {}

local rallyManager = nil
local flag_NoteSearch = false
local flag_drawDebug = false

local sphereColor = ColorF(1, 0, 0, 1)
local textColor = ColorF(1, 1, 1, 0.9)
local textBackgroundColor = ColorI(0, 0, 0, 128)

local function loadCornerAnglesFile()
  local filename = '/settings/aipacenotes/cornerAngles.json'
  local json = jsonReadFile(filename)
  if not json then
    local err = 'unable to find cornerAngles file: ' .. tostring(filename)
    log('E', 'aipacenotes', err)
    guihooks.trigger('aiPacenotesCornerAnglesLoaded', nil, err)
  end
  guihooks.trigger('aiPacenotesCornerAnglesLoaded', json, nil)
end

local function clearTimeout()
  extensions.gameplay_aipacenotes_client.clear_network_issue()
end

local function desktopGetTranscripts()
  local resp = extensions.gameplay_aipacenotes_client.transcribe_transcripts_get(2)
  if resp.ok then
    guihooks.trigger('aiPacenotesTranscriptsLoaded', resp)
  else
    guihooks.trigger('aiPacenotesDesktopCallNotOk', resp.client_msg)
  end
end

local function listMissionsForLevel()
  local filterFn = function (mission)
    return mission.startTrigger.level == getCurrentLevelIdentifier() and mission.missionType == 'rallyStage'
  end

  local missionList = {}

  for _, mission in ipairs(gameplay_missions_missions.getFilesData() or {}) do
    if filterFn(mission) then
      local missionData = {
        missionID = mission.id,
        missionDir = mission.missionFolder,
        missionName = mission.name,
      }
      table.insert(missionList, missionData)
    end
  end

  -- log('D', 'wtf', dumps(missionList))

  guihooks.trigger('aiPacenotesMissionsLoaded', missionList)
end

-- local function onFirstUpdate()
  -- loadCornerAnglesFile()
-- end

local function updateRallyManager(dtSim)
  if not rallyManager then return end

  if flag_NoteSearch then
    flag_NoteSearch = false
    rallyManager:handleNoteSearch()
  end

  rallyManager:update(dtSim)

  if rallyManager.audioManager then
    rallyManager.audioManager:playNextInQueue()
  end
end

local function drawDebug()
  -- TODO: convert into stream
  local veh = be:getPlayerVehicle(0)
  if not veh then
    return
  end

  -- local vehPos = veh:getPosition()
  -- local camPos = core_camera.getPosition()

  if not rallyManager then return end

  local pacenotes = rallyManager:getNextPacenotes()
  local multiple_notes = #pacenotes > 1

  for i,pacenote in ipairs(pacenotes) do
    local wp_audio_trigger = pacenote:getActiveFwdAudioTrigger()
    wp_audio_trigger:drawDebugRecce(i == 1, multiple_notes, pacenote._cached_fgData.note_text)
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  -- local veh = be:getPlayerVehicle(0)
  -- if not veh then
    -- guihooks.trigger('aiPacenotesRecce', -1, "no vehicle")
    -- return
  -- end

  -- local vehPos = veh:getPosition()
  -- log('D', 'wtf', 'onUpdate vehPos='..dumps(vehPos))

  updateRallyManager(dtSim)
  if flag_drawDebug then
    drawDebug()
  end
end

local function initRallyManager(missionId, missionDir)
  flag_NoteSearch = false
  rallyManager = require('/lua/ge/extensions/gameplay/rally/rallyManager')()
  rallyManager:setOverrideMission(missionId, missionDir)
  local vehObjId = be:getPlayerVehicleID(0)
  -- log('D', 'wtf', dumps(veh.id))
  -- log('D', 'wtf', dumps(veh.objectId))

  rallyManager:setup(vehObjId, 1000, 5)
  rallyManager:handleNoteSearch()
end

local function clearRallyManager()
  rallyManager = nil
end

local function setDrawDebug(val)
  flag_drawDebug = val
end

local function onVehicleResetted()
  -- log('D', 'aipacenotes', 'onVehicleResetted')

  if rallyManager then
    flag_NoteSearch = true
    rallyManager.audioManager:resetAudioQueue()
  end

  -- if self.pinIn.reset.value then
  -- self.rallyManager:reset()
  -- end
  -- if resetAudioQueue then
  --   resetAudioQueue = false
  --   rallyManager.audioManager:resetAudioQueue()
  -- end
end

-- local function onVehicleSwitched()
--   log('D', 'aipacenotes', 'onVehicleSwitched')
-- end
--
-- local function onVehicleSpawned()
--   log('D', 'aipacenotes', 'onVehicleSpawned')
-- end

M.onVehicleResetted = onVehicleResetted
-- M.onVehicleSpawned = onVehicleSpawned
-- M.onVehicleSwitched = onVehicleSwitched

M.loadCornerAnglesFile = loadCornerAnglesFile
M.listMissionsForLevel = listMissionsForLevel
M.desktopGetTranscripts = desktopGetTranscripts
M.initRallyManager = initRallyManager
M.clearRallyManager = clearRallyManager
M.clearTimeout = clearTimeout
M.setDrawDebug = setDrawDebug
M.onUpdate = onUpdate
-- M.onFirstUpdate = onFirstUpdate

return M