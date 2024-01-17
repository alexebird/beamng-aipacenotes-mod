-- extension name: ui_aipacenotes_recceApp

local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local M = {}

local rallyManager = nil
local vehicleCapture = nil
local snaproads = nil
local cornerAngles = nil
local flag_NoteSearch = false
local flag_drawDebug = false
local flag_drawDebugSnaproads = false
local ui_selectedCornerAnglesStyle = ""


local function isFreeroam()
  return core_gamestate.state and core_gamestate.state.state == "freeroam"
end

local function initVehicleCapture()
  local veh = be:getPlayerVehicle(0)
  if isFreeroam() then
    vehicleCapture = require('/lua/ge/extensions/gameplay/aipacenotes/vehicleCapture')(
      veh,
      cornerAngles,
      ui_selectedCornerAnglesStyle
    )
  end
end

local function loadCornerAnglesFile()
  local filename = '/settings/aipacenotes/cornerAngles.json'
  local json = jsonReadFile(filename)
  if json then
    cornerAngles = json
    -- initVehicleCapture()
    guihooks.trigger('aiPacenotesCornerAnglesLoaded', json, nil)
  else
    local err = 'unable to find cornerAngles file: ' .. tostring(filename)
    log('E', 'aipacenotes', err)
    guihooks.trigger('aiPacenotesCornerAnglesLoaded', nil, err)
  end
end

local function clearTimeout()
  extensions.gameplay_aipacenotes_client.clear_network_issue()
end

local function desktopGetTranscripts()
  local resp = extensions.gameplay_aipacenotes_client.transcribe_transcripts_get(2)
  if resp.ok then
    guihooks.trigger('aiPacenotesTranscriptsLoaded', resp)
  else
    guihooks.trigger('aiPacenotesInputActionDesktopCallNotOk', resp.client_msg)
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

local function updateVehicleCapture()
  if not vehicleCapture then return end

  vehicleCapture:capture()
end

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
  if not rallyManager then return end

  local nextPacenotes = rallyManager:getNextPacenotes()

  for i,pacenote in ipairs(nextPacenotes) do
    local wp_audio_trigger = pacenote:getActiveFwdAudioTrigger()
    wp_audio_trigger:drawDebugRecce(i, nextPacenotes, pacenote._cached_fgData.note_text)
  end

  if snaproads and flag_drawDebugSnaproads then
    snaproads:drawSnapRoads(nil, cc.clr_orange)
    if #nextPacenotes > 0 then
      local rad = 0.5
      local alpha = 0.5

      local nextNote = nextPacenotes[1]
      local wp_audio_trigger = nextNote:getActiveFwdAudioTrigger()
      local pos = wp_audio_trigger.pos
      debugDrawer:drawSphere(
        (pos),
        rad,
        ColorF(1,1,1,alpha)
      )

      local cs = nextNote:getCornerStartWaypoint()
      debugDrawer:drawSphere(
        (cs.pos),
        rad,
        ColorF(0,1,0,alpha)
      )

      local ce = nextNote:getCornerEndWaypoint()
      debugDrawer:drawSphere(
        (ce.pos),
        rad,
        ColorF(1,0,0,alpha)
      )

      local wp_cs = nextNote:getCornerStartWaypoint()
      if wp_cs then
        local nextSnapPos,_ = snaproads:nextSnapPos(pos, wp_cs.pos)
        debugDrawer:drawSphere(
          (nextSnapPos),
          rad,
          ColorF(1,0,1,alpha)
        )
      end

      local veh = be:getPlayerVehicle(0)
      if not veh then
        guihooks.trigger('aiPacenotesRecce', -1, "no vehicle")
        return
      end
      local vehPos = veh:getPosition()
      local nextSnapPos,_ = snaproads:nextSnapPos(pos, vehPos)
      debugDrawer:drawSphere(
        (nextSnapPos),
        rad,
        ColorF(0,1,1,alpha)
      )
    end
  end
end

local function movePacenoteTowards(pacenote, directionPos)
  local nextWp = pacenote:getActiveFwdAudioTrigger()

  local nextSnapPos, normalAlignPos = snaproads:nextSnapPos(nextWp.pos, directionPos)
  if nextSnapPos then
    local newNormal = re_util.calculateForwardNormal(nextSnapPos, normalAlignPos)
    nextWp:setPos(nextSnapPos)
    nextWp:setNormal(newNormal)
  end
end

local function moveNextPacenoteFarther()
  if not rallyManager then return end
  if not snaproads then return end

  local nextPacenotes = rallyManager:getNextPacenotes()
  if nextPacenotes and #nextPacenotes > 0 then
    local nextNote = nextPacenotes[1]
    if not nextNote then
      return
    end
    movePacenoteTowards(nextPacenotes[1], nextNote:getCornerStartWaypoint().pos)
    rallyManager:saveNotebook()
  end
end

local function moveNextPacenoteCloser()
  if not rallyManager then return end
  if not snaproads then return end

  local nextPacenotes = rallyManager:getNextPacenotes()
  if nextPacenotes and #nextPacenotes > 0 then
    local nextNote = nextPacenotes[1]
    local veh = be:getPlayerVehicle(0)
    if not nextNote or not veh then
      return
    end
    local vehPos = veh:getPosition()
    movePacenoteTowards(nextPacenotes[1], vehPos)
    rallyManager:saveNotebook()
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  updateRallyManager(dtSim)
  updateVehicleCapture()
  if flag_drawDebug and not (editor and editor.isEditorActive()) then
    drawDebug()
  end
end

local function initSnapRoads()
  snaproads = require('/lua/ge/extensions/editor/rallyEditor/snaproads2')()
  snaproads:loadSnapRoads()
end

local function initRallyManager(missionId, missionDir)
  flag_NoteSearch = false
  rallyManager = require('/lua/ge/extensions/gameplay/rally/rallyManager')()
  rallyManager:setOverrideMission(missionId, missionDir)
  local vehObjId = be:getPlayerVehicleID(0)
  rallyManager:setup(vehObjId, 1000, 5)
  rallyManager:handleNoteSearch()
  initSnapRoads()
end

local function clearRallyManager()
  rallyManager = nil
end

local function setDrawDebug(val)
  flag_drawDebug = val
end

local function setDrawDebugSnaproads(val)
  flag_drawDebugSnaproads = val
end

local function onVehicleResetted()
  log('I', 'aipacenotes', 'recceApp detected vehicle reset')

  if rallyManager then
    flag_NoteSearch = true
    rallyManager.audioManager:resetAudioQueue()
    -- self.rallyManager:reset() -- needed someday? it's used in the flowgraph reset code.
  end
end

local function setCornerAnglesStyleName(name)
  ui_selectedCornerAnglesStyle = name
  initVehicleCapture()
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
M.setDrawDebugSnaproads = setDrawDebugSnaproads
M.setCornerAnglesStyleName = setCornerAnglesStyleName
M.moveNextPacenoteCloser = moveNextPacenoteCloser
M.moveNextPacenoteFarther = moveNextPacenoteFarther
M.onUpdate = onUpdate
-- M.onFirstUpdate = onFirstUpdate

return M
