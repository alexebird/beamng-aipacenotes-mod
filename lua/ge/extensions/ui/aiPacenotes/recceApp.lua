-- extension name: ui_aipacenotes_recceApp

local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local Recce = require('/lua/ge/extensions/gameplay/aipacenotes/recce')
local RecceSettings = require('/lua/ge/extensions/gameplay/aipacenotes/recceSettings')
local RallyManager = require('/lua/ge/extensions/gameplay/rally/rallyManager')
local Snaproad = require('/lua/ge/extensions/gameplay/aipacenotes/snaproad')
local logTag = 'aipacenotes-recce'

local M = {}

-- loaded extension state
local recce_settings = nil

-- loaded mission state
local missionDir = nil
local missionId = nil
local rallyManager = nil
local snaproad = nil
local flag_NoteSearch = false
local flag_drawDebug = false
local flag_drawDebugSnaproads = false

-- recording state
local vehicleCapture = nil
local cutCapture = nil
-- recording settings state
local shouldRecordDriveline = false
local shouldRecordVoice = false


local function isFreeroam()
  return core_gamestate.state and core_gamestate.state.state == "freeroam"
end

local function initCaptures()
  vehicleCapture = nil
  cutCapture = nil

  if isFreeroam() and missionDir then
    local veh = be:getPlayerVehicle(0)
    vehicleCapture = require('/lua/ge/extensions/gameplay/aipacenotes/vehicleCapture')(
      veh,
      missionDir
    )
    cutCapture = require('/lua/ge/extensions/gameplay/aipacenotes/cutCapture')(
      veh,
      missionDir
    )
  end
end

-- local function loadCornerAngles()
  -- local json, err = re_util.loadCornerAnglesFile()
  --
  -- if json then
  --   local cornerAngles = json
  --   guihooks.trigger('aiPacenotesCornerAnglesLoaded', json, nil)
  -- else
  --   log('E', 'aipacenotes', err)
  --   guihooks.trigger('aiPacenotesCornerAnglesLoaded', nil, err)
  -- end

--   local style = recce_settings:getCornerCallStyle()
--   guihooks.trigger('aiPacenotes.recceApp.cornerAnglesLoaded', style)
-- end

-- local function clearTimeout()
  -- extensions.gameplay_aipacenotes_client.clear_network_issue()
-- end

local function desktopGetTranscripts()
  local resp = extensions.gameplay_aipacenotes_client.transcribe_transcripts_get(2)
  if resp.ok then
    guihooks.trigger('aiPacenotesTranscriptsLoaded', resp)
  else
    guihooks.trigger('aiPacenotesInputActionDesktopCallNotOk', resp.client_msg)
  end
end

-- local function listMissionsForLevel()
local function refresh()
  local level = getCurrentLevelIdentifier()

  local filterFn = function (mission)
    return mission.startTrigger.level == level and mission.missionType == 'rallyStage'
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

  recce_settings:load()

  local last_mid = nil
  local last_load_state = false
  local style = nil
  if recce_settings then
    last_mid = recce_settings:getLastMissionId(level)
    last_load_state = recce_settings:getLastLoadState(level)
    style = recce_settings:getCornerCallStyle()
  end

  -- log('D', 'wtf', dumps(last_mid))

  local resp = {
    missions = missionList,
    last_mission_id = last_mid,
    last_load_state = last_load_state,
    corner_angles_style = style,
  }
  guihooks.trigger('aiPacenotes.recceApp.refreshed', resp)
end

-- local function onFirstUpdate()
  -- loadCornerAnglesFile()
-- end

local function updateVehicleCapture()
  if not vehicleCapture then return end
  if shouldRecordDriveline then
    vehicleCapture:capture()
  end
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

  -- local pacenote = nextPacenotes[1]
  -- if pacenote then
  --   local wp_audio_trigger = pacenote:getActiveFwdAudioTrigger()
  --   wp_audio_trigger:drawDebugRecce(1, nextPacenotes, pacenote._cached_fgData.note_text)
  -- end

  if snaproad and flag_drawDebugSnaproads then
    snaproad:drawDebugRecceApp()

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
      local point_cs = snaproad:closestSnapPoint(cs.pos)
      debugDrawer:drawSphere(
        cs.pos,
        rad,
        ColorF(0,1,0,alpha)
      )

      local ce = nextNote:getCornerEndWaypoint()
      local point_ce = snaproad:closestSnapPoint(ce.pos)
      debugDrawer:drawSphere(
        ce.pos,
        rad,
        ColorF(1,0,0,alpha)
      )

      local nextSnapPoint = snaproad:nextSnapPoint(pos)
      if nextSnapPoint and nextSnapPoint.id ~= point_cs.id then
        debugDrawer:drawSphere(
          nextSnapPoint.pos,
          rad,
          ColorF(1,0,1,alpha)
        )
      end

      local prevSnapPoint = snaproad:prevSnapPoint(pos)
      -- requires getting prevNote to not render the aqua gumdrop
      -- if prevSnapPoint and prevSnapPoint.id ~= point_ce.id then
      if prevSnapPoint then
        debugDrawer:drawSphere(
          prevSnapPoint.pos,
          rad,
          ColorF(0,1,1,alpha)
        )
      end
    end
  end
end

local function moveNextPacenoteATForward()
  log('D', 'wtf', 'moveNextPacenoteATForward')
  if not rallyManager then return end
  if not snaproad then return end

  local nextPacenotes = rallyManager:getNextPacenotes()
  if nextPacenotes and #nextPacenotes > 0 then
    local nextNote = nextPacenotes[1]
    if not nextNote then
      return
    end

    local wp = nextNote:getActiveFwdAudioTrigger()
    snaproad:setPacenote(nextNote)
    snaproad:setFilter(wp)
    nextNote:moveWaypointTowards(snaproad, wp, true)
    rallyManager:saveNotebook()
    snaproad:setFilter(nil)
  end
end

local function moveNextPacenoteATBackward()
  log('D', 'wtf', 'moveNextPacenoteATBackward')
  if not rallyManager then return end
  if not snaproad then return end

  local nextPacenotes = rallyManager:getNextPacenotes()
  if nextPacenotes and #nextPacenotes > 0 then
    local nextNote = nextPacenotes[1]
    local veh = be:getPlayerVehicle(0)
    if not nextNote or not veh then
      return
    end
    local wp = nextNote:getActiveFwdAudioTrigger()
    snaproad:setPacenote(nextNote)
    snaproad:setFilter(wp)
    nextNote:moveWaypointTowards(snaproad, wp, false)
    rallyManager:saveNotebook()
    snaproad:setFilter(nil)
  end
end

local function moveVehicleBackward()
  log('D', 'wtf', 'moveVehicleBackward')

  if not rallyManager then return end
  if not rallyManager.notebook then return end
  if not rallyManager.vehicleTracker then return end

  log('D', 'wtf', 'moveVehicleBackward proceeding')
  -- 1. find closest AT
  -- 2. if car is not within 10m of vehicle placement point for the chosen AT, then place at that AT
  -- 3. else place at prev pacenote AT

  local vPos = rallyManager.vehicleTracker:pos()
  local nearestPacenoteDist = 100000000
  local nearestPacenote = nil
  local i_nearest = nil
  local col = rallyManager.notebook.pacenotes.sorted

  for i,pn in ipairs(col) do
    local at = pn:getActiveFwdAudioTrigger()
    if at then
      local placementPos, _ = pn:vehiclePlacementPosAndRot()
      local dist = vPos:distance(placementPos)
      if dist < nearestPacenoteDist then
        nearestPacenoteDist = dist
        nearestPacenote = pn
        i_nearest = i
      end
    end
  end

  if nearestPacenote then
    local placementPos, _ = nearestPacenote:vehiclePlacementPosAndRot()
    local vdist = vPos:distance(placementPos)
    log('D', 'wtf', 'vdist='..tostring(vdist))
    if vdist < 10 then
      -- go to the next one after closest

      if i_nearest >= 2 then
        nearestPacenote = col[i_nearest-1]
      else
        -- dont wrap around if at end
        nearestPacenote = nil
      end
    end

    if nearestPacenote then
      local pos, rot = nearestPacenote:vehiclePlacementPosAndRot()

      if pos and rot then
        local playerVehicle = be:getPlayerVehicle(0)
        if playerVehicle and nearestPacenote then
          spawn.safeTeleport(playerVehicle, pos, rot)
        end
      end
    end
  end
end

local function moveVehicleForward()
  log('D', 'wtf', 'moveVehicleBackward')

  if not rallyManager then return end
  if not rallyManager.notebook then return end
  if not rallyManager.vehicleTracker then return end

  log('D', 'wtf', 'moveVehicleForward proceeding')
  -- 1. find closest AT
  -- 2. if car is not within 10m of vehicle placement point for the chosen AT, then place at that AT
  -- 3. else place at next pacenote AT

  local vPos = rallyManager.vehicleTracker:pos()
  local nearestPacenoteDist = 100000000
  local nearestPacenote = nil
  local i_nearest = nil
  local col = rallyManager.notebook.pacenotes.sorted

  for i,pn in ipairs(col) do
    local at = pn:getActiveFwdAudioTrigger()
    if at then
      local placementPos, _ = pn:vehiclePlacementPosAndRot()
      local dist = vPos:distance(placementPos)
      if dist < nearestPacenoteDist then
        nearestPacenoteDist = dist
        nearestPacenote = pn
        i_nearest = i
      end
    end
  end

  if nearestPacenote then
    local placementPos, _ = nearestPacenote:vehiclePlacementPosAndRot()
    local vdist = vPos:distance(placementPos)
    log('D', 'wtf', 'vdist='..tostring(vdist))
    if vdist < 10 then
      -- go to the next one after closest

      if i_nearest <= #col-1 then
        nearestPacenote = col[i_nearest+1]
      else
        -- dont wrap around if at end
        nearestPacenote = nil
      end
    end

    if nearestPacenote then
      local pos, rot = nearestPacenote:vehiclePlacementPosAndRot()

      if pos and rot then
        local playerVehicle = be:getPlayerVehicle(0)
        if playerVehicle and nearestPacenote then
          spawn.safeTeleport(playerVehicle, pos, rot)
        end
      end
    end
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  updateRallyManager(dtSim)
  updateVehicleCapture()
  if flag_drawDebug and not (editor and editor.isEditorActive()) then
    drawDebug()
  end
end

local function loadMission(newMissionId, newMissionDir)
  missionDir = newMissionDir
  missionId = newMissionId
  flag_NoteSearch = false
  -- flag_drawDebug = false
  -- flag_drawDebugSnaproads = false
  rallyManager = RallyManager()
  rallyManager:setOverrideMission(missionId, missionDir)
  rallyManager:setup(100, 10)
  rallyManager:handleNoteSearch()

  if missionDir then
    local recce = Recce(missionDir)
    recce:load()
    snaproad = Snaproad(recce)
  end
end

local function unloadMission()
  rallyManager = nil
  missionDir = nil
  missionId = nil
  snaproad = nil
  flag_NoteSearch = false
  -- flag_drawDebug = false
  -- flag_drawDebugSnaproads = false
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

-- local function setCornerAnglesStyleName(name)
--   ui_selectedCornerAnglesStyle = name
-- end

-- local function getVehiclePosForCut()
--   local vehicle = be:getPlayerVehicle(0)
--   local vehiclePos = vehicle:getPosition()
--   local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
--   local vehicle_position = { pos=vehiclePos, quat={x=vRot.x,y=vRot.y,z=vRot.z,w=vRot.w} }
--   return vehicle_position
-- end

local function transcribe_recording_cut()
  log('I', logTag, 'transcribe_recording_cut')

  if cutCapture then
    local cutId = cutCapture:capture()
    if shouldRecordVoice then
      local request = {
        -- vehicle_data = getVehiclePosForCut(),
        cut_id = cutId,
      }
      local resp = extensions.gameplay_aipacenotes_client.transcribe_recording_cut(request)
      if not resp.ok then
        guihooks.trigger('aiPacenotesInputActionDesktopCallNotOk', resp.client_msg)
      end
    end
  end
end

local function transcribe_recording_start(recordDriveline, recordVoice)
  log('I', logTag, 'transcribe_recording_start')

  shouldRecordDriveline = recordDriveline
  shouldRecordVoice = recordVoice

  initCaptures()
end

local function transcribe_recording_stop()
  log('I', logTag, 'transcribe_recording_stop')
  if vehicleCapture and shouldRecordDriveline then
    vehicleCapture:writeCaptures(true)
  end

  vehicleCapture = nil
  cutCapture = nil

  -- local resp = extensions.gameplay_aipacenotes_client.transcribe_recording_stop()
  -- if not resp.ok then
  --   guihooks.trigger('aiPacenotesInputActionDesktopCallNotOk', resp.client_msg)
  -- end
end

local function transcribe_clear_all()
  initCaptures()
  vehicleCapture:truncateCapturesFile()
  cutCapture:truncateCapturesFile()
  cutCapture:truncateTranscriptsFile()
  vehicleCapture = nil
  cutCapture = nil
end

-- local function onVehicleSwitched()
--   log('D', 'aipacenotes', 'onVehicleSwitched')
-- end
--
-- local function onVehicleSpawned()
--   log('D', 'aipacenotes', 'onVehicleSpawned')
-- end


local function setLastMissionId(mid)
  if recce_settings then
    recce_settings:setLastMissionId(getCurrentLevelIdentifier(), mid)
  end
end

local function setLastLoadState(state)
  if recce_settings then
    recce_settings:setLastLoadState(getCurrentLevelIdentifier(), state)
  end
end

local function initRecceApp()
  recce_settings = RecceSettings()
  recce_settings:load()
end

local function onExtensionLoaded()
  print('recceApp.onExtensionLoaded')
  initRecceApp()
  guihooks.trigger('aiPacenotes.recceApp.onExtensionLoaded', {})
end

M.onExtensionLoaded = onExtensionLoaded

M.onVehicleResetted = onVehicleResetted
-- M.onVehicleSpawned = onVehicleSpawned
-- M.onVehicleSwitched = onVehicleSwitched

-- M.loadCornerAngles = loadCornerAngles
-- M.listMissionsForLevel = listMissionsForLevel
M.refresh = refresh
M.desktopGetTranscripts = desktopGetTranscripts
M.loadMission = loadMission
M.initRecceApp = initRecceApp
M.unloadMission = unloadMission
-- M.clearTimeout = clearTimeout
M.setDrawDebug = setDrawDebug
M.setDrawDebugSnaproads = setDrawDebugSnaproads
-- M.setCornerAnglesStyleName = setCornerAnglesStyleName
M.moveNextPacenoteATBackward = moveNextPacenoteATBackward
M.moveNextPacenoteATForward = moveNextPacenoteATForward
M.moveVehicleBackward = moveVehicleBackward
M.moveVehicleForward = moveVehicleForward
M.onUpdate = onUpdate
-- M.onFirstUpdate = onFirstUpdate

M.transcribe_recording_cut = transcribe_recording_cut
M.transcribe_recording_stop = transcribe_recording_stop
M.transcribe_recording_start = transcribe_recording_start
M.transcribe_clear_all = transcribe_clear_all
M.setLastMissionId = setLastMissionId
M.setLastLoadState = setLastLoadState

return M
