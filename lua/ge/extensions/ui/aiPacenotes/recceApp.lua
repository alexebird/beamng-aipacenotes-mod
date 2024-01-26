-- extension name: ui_aipacenotes_recceApp

local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local logTag = 'aipacenotes-recce'

local M = {}

local rallyManager = nil
local vehicleCapture = nil
local snaproads = nil
local cornerAngles = nil
local flag_NoteSearch = false
local flag_drawDebug = false
local flag_drawDebugSnaproads = false
local ui_selectedCornerAnglesStyle = ""
local missionDir = nil
local missionId = nil


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
  local json, err = re_util.loadCornerAnglesFile()

  if json then
    cornerAngles = json
    guihooks.trigger('aiPacenotesCornerAnglesLoaded', json, nil)
  else
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

      local nextSnapPos,_ = snaproads:nextSnapPos(pos)
      if nextSnapPos then
        debugDrawer:drawSphere(
          (nextSnapPos),
          rad,
          ColorF(1,0,1,alpha)
        )
      end

      local prevSnapPos,_ = snaproads:prevSnapPos(pos)
      if prevSnapPos then
        debugDrawer:drawSphere(
          (prevSnapPos),
          rad,
          ColorF(0,1,1,alpha)
        )
      end
    end
  end
end

local function moveWaypointTowards(pacenote, fwd)
  local nextWp = pacenote:getActiveFwdAudioTrigger()
  local cs = pacenote:getCornerStartWaypoint()
  local newSnapPos, normalAlignPos = nil, nil

  if fwd then
    newSnapPos, normalAlignPos = snaproads:nextSnapPos(nextWp.pos, cs and cs.pos)
  else
    newSnapPos, normalAlignPos = snaproads:prevSnapPos(nextWp.pos)
  end

  if newSnapPos then
    nextWp:setPos(newSnapPos)
    if normalAlignPos then
      local newNormal = re_util.calculateForwardNormal(newSnapPos, normalAlignPos)
      nextWp:setNormal(newNormal)
    end
  end
end

local function moveNextPacenoteForward()
  log('D', 'wtf', 'moveNextPacenoteForward')
  if not rallyManager then return end
  if not snaproads then return end

  local nextPacenotes = rallyManager:getNextPacenotes()
  if nextPacenotes and #nextPacenotes > 0 then
    local nextNote = nextPacenotes[1]
    if not nextNote then
      return
    end
    moveWaypointTowards(nextNote, true)
    rallyManager:saveNotebook()
  end
end

local function moveNextPacenoteBackward()
  log('D', 'wtf', 'moveNextPacenoteBackward')
  if not rallyManager then return end
  if not snaproads then return end

  local nextPacenotes = rallyManager:getNextPacenotes()
  if nextPacenotes and #nextPacenotes > 0 then
    local nextNote = nextPacenotes[1]
    local veh = be:getPlayerVehicle(0)
    if not nextNote or not veh then
      return
    end
    moveWaypointTowards(nextNote, false)
    rallyManager:saveNotebook()
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
      local dist = vPos:distance(pn:posForVehiclePlacement())
      if dist < nearestPacenoteDist then
        nearestPacenoteDist = dist
        nearestPacenote = pn
        i_nearest = i
      end
    end
  end

  if nearestPacenote then
    local vdist = vPos:distance(nearestPacenote:posForVehiclePlacement())
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
  end

  local playerVehicle = be:getPlayerVehicle(0)
  if playerVehicle and nearestPacenote then
    spawn.safeTeleport(
      playerVehicle,
      nearestPacenote:posForVehiclePlacement(),
      nearestPacenote:rotForVehiclePlacement()
    )
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
      local dist = vPos:distance(pn:posForVehiclePlacement())
      if dist < nearestPacenoteDist then
        nearestPacenoteDist = dist
        nearestPacenote = pn
        i_nearest = i
      end
    end
  end

  if nearestPacenote then
    local vdist = vPos:distance(nearestPacenote:posForVehiclePlacement())
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
  end

  local playerVehicle = be:getPlayerVehicle(0)
  if playerVehicle and nearestPacenote then
    spawn.safeTeleport(
      playerVehicle,
      nearestPacenote:posForVehiclePlacement(),
      nearestPacenote:rotForVehiclePlacement()
    )
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  updateRallyManager(dtSim)
  updateVehicleCapture()
  if flag_drawDebug and not (editor and editor.isEditorActive()) then
    drawDebug()
  end
end

-- local function initSnapRoads()
--   snaproads = require('/lua/ge/extensions/editor/rallyEditor/snaproads2')()
--   snaproads:loadSnapRoads()
-- end

-- VC = vehicle capture
local function initSnapVC()
  log('D', logTag, 'initSnapVC')
  snaproads = require('/lua/ge/extensions/editor/rallyEditor/snapVC')(missionDir)
  snaproads:load()
end

local function initRallyManager(newMissionId, newMissionDir)
  missionDir = newMissionDir
  missionId = newMissionId
  flag_NoteSearch = false
  rallyManager = require('/lua/ge/extensions/gameplay/rally/rallyManager')()
  rallyManager:setOverrideMission(missionId, missionDir)
  local vehObjId = be:getPlayerVehicleID(0)
  rallyManager:setup(vehObjId, 100, 5)
  rallyManager:handleNoteSearch()

  if missionDir then
    -- initSnapRoads()
    initSnapVC()
  end
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
  -- initVehicleCapture()
end

local function getVehiclePosForRequest()
  local vehicle = be:getPlayerVehicle(0)
  local vehiclePos = vehicle:getPosition()
  local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
  -- local x,y,z = vRot * vec3(1,0,0),vRot * vec3(0,1,0),vRot * vec3(0,0,1)
  local vehicle_position = { pos=vehiclePos, quat={x=vRot.x,y=vRot.y,z=vRot.z,w=vRot.w} }
  return vehicle_position
end

local function trascribe_recording_cut()
  local request = {
    vehicle_data = getVehiclePosForRequest(),
  }
  if vehicleCapture then
    request.capture_data = vehicleCapture:asJson()
    vehicleCapture:reset()
  else
    initVehicleCapture()
  end

  local resp = extensions.gameplay_aipacenotes_client.transcribe_recording_cut(request)
  if not resp.ok then
    guihooks.trigger('aiPacenotesInputActionDesktopCallNotOk', resp.client_msg)
  end
end

local function trascribe_recording_stop()
  vehicleCapture = nil
  local resp = extensions.gameplay_aipacenotes_client.transcribe_recording_stop()
  if not resp.ok then
    guihooks.trigger('aiPacenotesInputActionDesktopCallNotOk', resp.client_msg)
  end
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
M.moveNextPacenoteBackward = moveNextPacenoteBackward
M.moveNextPacenoteForward = moveNextPacenoteForward
M.moveVehicleBackward = moveVehicleBackward
M.moveVehicleForward = moveVehicleForward
M.onUpdate = onUpdate
-- M.onFirstUpdate = onFirstUpdate

M.trascribe_recording_cut = trascribe_recording_cut
M.trascribe_recording_stop = trascribe_recording_stop

return M
