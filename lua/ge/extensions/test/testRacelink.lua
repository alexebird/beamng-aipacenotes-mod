-- extension name: test_testRacelink
--
--
-- extensions.load("test_testRacelink")
-- extensions.unload("test_testRacelink")
-- extensions.unload("test_testRacelink") extensions.load("test_testRacelink") test_testRacelink.testTracker()

local logTag = 'test-racelink'

local M = {}

-- local rallyManager = nil


-- local function onUpdate(dtReal, dtSim, dtRaw)
-- end

-- local function onVehicleResetted(vehicleID)
-- end

-- local function onVehicleSwitched(oid, nid, player)
--   log('D', logTag, 'onVehicleSwitched')
-- end
--
-- local function onVehicleSpawned(vid, v)
--   log('D', logTag, 'onVehicleSpawned')
-- end
--
-- local function onVehicleActiveChanged(vehicleID, active)
-- end

local function pp(x)
  print(dumps(x))
end

local function reload_module(name)
  package.loaded[name] = nil
  return require(name)
end

local function testTracker()
  local Tracker = reload_module('/lua/ge/extensions/gameplay/aipacenotes/racelink/tracker')

  -- local veh = getPlayerVehicle()
  local vehId = be:getPlayerVehicleID(0)
  local veh = be:getObjectByID(vehId)

  local x = Tracker(vehId)

  x:setMissionId("driver_training/rallyStage/aip-test3")

  assert( x.uuid ~= nil)

  local reading = x:getAllData()
  pp(reading.odometer)
  pp(reading.fuel)
  pp(reading.level)
  pp(reading.mission)

  print("passed")

  return x
end


-- extension hooks
-- M.onUpdate = onUpdate
-- M.onVehicleResetted = onVehicleResetted
-- M.onVehicleSpawned = onVehicleSpawned
-- M.onVehicleSwitched = onVehicleSwitched
-- M.onVehicleActiveChanged = onVehicleActiveChanged

-- aipacenotes API
-- M.initRallyManager = initRallyManager
-- M.clearRallyManager = clearRallyManager

-- M.isReady = isReady
-- M.getRallyManager = function() return rallyManager end

-- M.setDrawDebug = setDrawDebug
-- M.toggleDrawDebug = toggleDrawDebug

M.testTracker = testTracker

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

