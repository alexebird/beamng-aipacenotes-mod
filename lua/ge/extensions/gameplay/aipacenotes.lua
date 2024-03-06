-- extension name: gameplay_aipacenotes

local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local logTag = 'aipacenotes'

local M = {}

local rallyManager = nil
local flag_NoteSearch = false
local flag_drawDebug = false

local function isFreeroam()
  return core_gamestate.state and core_gamestate.state.state == "freeroam"
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
end

local function initRallyManager(missionId, missionDir)
  flag_NoteSearch = false
  rallyManager = require('/lua/ge/extensions/gameplay/rally/rallyManager')()
  rallyManager:setOverrideMission(missionId, missionDir)
  rallyManager:setup(100, 5)
  rallyManager:handleNoteSearch()
end

local function clearRallyManager()
  rallyManager = nil
end

local function setDrawDebug(val)
  flag_drawDebug = val
end

local function isReady()
  if rallyManager then
    return true
  end

  return false
end

-- local function onFirstUpdate()
--   log('D', logTag, 'onFirstUpdate')
-- end

local function onUpdate(dtReal, dtSim, dtRaw)
  if isFreeroam() then
    clearRallyManager()
    return
  end

  updateRallyManager(dtSim)
  -- updateVehicleCapture()

  -- if flag_drawDebug and not (editor and editor.isEditorActive()) then
    -- drawDebug()
  -- end
end

local function onVehicleResetted(vehicleID)
  log('I', logTag, 'aipacenotes onVehicleResetted')

  if rallyManager then
    flag_NoteSearch = true
    rallyManager.audioManager:resetAudioQueue()
    -- rallyManager:reset() -- needed someday? it's used in the flowgraph reset code.
  end
end

local function onVehicleSwitched(oid, nid, player)
  log('D', logTag, 'onVehicleSwitched')
end

local function onVehicleSpawned(vid, v)
  log('D', logTag, 'onVehicleSpawned')
end

local function onVehicleActiveChanged(vehicleID, active)
end

local function helloWorld()
  log('D', logTag, 'Hello, world!')
end

-- extension hooks
M.onUpdate = onUpdate
-- M.onFirstUpdate = onFirstUpdate -- not used
M.onVehicleResetted = onVehicleResetted
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleActiveChanged = onVehicleActiveChanged

-- aipacenotes API
M.initRallyManager = initRallyManager
M.clearRallyManager = clearRallyManager
M.setDrawDebug = setDrawDebug
M.helloWorld = helloWorld

M.isReady = isReady
M.getRallyManager = function() return rallyManager end

return M



-- lua/ge/main.lua|399 col 3| extensions.hook('onClientPreStartMission', levelPath)
-- lua/ge/main.lua|408 col 3| extensions.hook('onClientPostStartMission', levelPath)
-- lua/ge/main.lua|414 col 3| extensions.hookNotify('onClientStartMission', levelPath)
-- lua/ge/main.lua|425 col 3| extensions.hookNotify('onClientEndMission', levelPath)
-- lua/ge/main.lua|434 col 3| extensions.hook('onEditorEnabled', enabled)
-- lua/ge/main.lua|451 col 3| extensions.hook('onPreRender', dtReal, dtSim, dtRaw)
-- lua/ge/main.lua|454 col 3| extensions.hook('onDrawDebug', Lua.lastDebugFocusPos, dtReal, dtSim, dtRaw)
-- lua/ge/main.lua|475 col 7| extensions.hook('onWorldReadyState', worldReadyState)
-- lua/ge/main.lua|483 col 3| extensions.hook('onFirstUpdate')
-- lua/ge/main.lua|504 col 3| extensions.hook('onUpdate', dtReal, dtSim, dtRaw)
-- lua/ge/main.lua|507 col 5| extensions.hook('onGuiUpdate', dtReal, dtSim, dtRaw)
-- lua/ge/main.lua|523 col 3| extensions.hook('onUiReady')
-- lua/ge/main.lua|563 col 3| extensions.hook('onBeamNGWaypoint', args)
-- lua/ge/main.lua|568 col 3| extensions.hook('onBeamNGTrigger', data)
-- lua/ge/main.lua|575 col 3| extensions.hook('onFilesChanged', files)
-- lua/ge/main.lua|579 col 5| extensions.hook('onFileChanged', v.filename, v.type)
-- lua/ge/main.lua|581 col 3| extensions.hook('onFileChangedEnd')
-- lua/ge/main.lua|586 col 3| extensions.hook('onPhysicsEngineEvent', args)
-- lua/ge/main.lua|599 col 3| extensions.hook('onVehicleSpawned', vid, v)
-- lua/ge/main.lua|610 col 3| extensions.hook('onVehicleSwitched', oid, nid, player)
-- lua/ge/main.lua|615 col 3| extensions.hook('onVehicleResetted', vehicleID)
-- lua/ge/main.lua|621 col 3| extensions.hook('onVehicleActiveChanged', vehicleID, active)
-- lua/ge/main.lua|625 col 3| extensions.hook('onMouseLocked', locked)
-- lua/ge/main.lua|630 col 3| extensions.hook('onVehicleDestroyed', vid)
-- lua/ge/main.lua|641 col 3| extensions.hook('onCouplerAttached', objId1, objId2, nodeId, obj2nodeId)
-- lua/ge/main.lua|645 col 3| extensions.hook('onCouplerDetached', objId1, objId2, nodeId, obj2nodeId)
-- lua/ge/main.lua|653 col 3| extensions.hook('onCouplerDetach', objId, nodeId)
-- lua/ge/main.lua|657 col 3| extensions.hook('onAiModeChange', vehicleID, newAiMode)
-- lua/ge/main.lua|707 col 5| extensions.hook('onPhysicsUnpaused')
-- lua/ge/main.lua|709 col 5| extensions.hook('onPhysicsPaused')
-- lua/ge/main.lua|739 col 3| extensions.hook('onResetGameplay', playerID)
-- lua/ge/main.lua|804 col 3| extensions.hook('onPreWindowClose')
-- lua/ge/main.lua|808 col 3| extensions.hook('onPreExit')
-- lua/ge/main.lua|813 col 5| extensions.hook('onExit')
