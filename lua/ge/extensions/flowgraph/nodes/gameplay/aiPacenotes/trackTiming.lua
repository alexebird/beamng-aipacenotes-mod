local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local socket = require('socket')
local mime = require("mime")
local bit32 = bit

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Track Timing'
C.description = 'Track timing data.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'table',  name = 'raceData', tableType = 'raceData', description = 'Race data.'},
  { dir = 'in', type = 'table',  name = 'pathData', tableType = 'pathData', description = 'Path data.'},
  { dir = 'in', type = 'number', name = 'damage', description = 'Vehicle damage.'},
}

local function getLevelId(missionId)
  return string.match(missionId, "([^/]+)")
end

local function getLevelInfo(missionId)
  local levelId = getLevelId(missionId)
  local levelInfo = core_levels.getLevelByName(levelId)

  return {
    id = levelId,
    authors = levelInfo.authors,
    description = levelInfo.description,
    title = levelInfo.title,
    size = levelInfo.size,
  }

  -- {
  --   authors = "BeamNG",
  --   biome = "levels.driver_training.biome",
  --   country = "levels.common.country.germany",
  --   defaultSpawnPointName = "spawn_default",
  --   description = "levels.driver_training.info.description",
  --   dir = "/levels/driver_training",
  --   features = "levels.driver_training.features",
  --   fullfilename = "/levels/driver_training/main/",
  --   levelName = "driver_training",
  --   minimap = { {
  --       file = "levels/driver_training/drivertraining_minimap.png",
  --       offset = { -511.5, 512.5, 0 },
  --       size = { 1024, 1024, 92.099998474121 }
  --     } },
  --   misFilePath = "/levels/driver_training/",
  --   official = false,
  --   previews = <1>{ "/levels/driver_training/driver_training_preview.jpg", "/levels/driver_training/driver_training_preview_2.jpg" },
  --   roads = "levels.driver_training.roads",
  --   size = { 1024, 1024 },
  --   spawnPoints = { {
  --       objectname = "spawn_north",
  --       previews = { "/levels/driver_training/spawn_north_preview.jpg" },
  --       translationId = "levels.driver_training.spawnpoints.spawn_north"
  --     }, {
  --       objectname = "spawn_west",
  --       previews = { "/levels/driver_training/spawn_west_preview.jpg" },
  --       translationId = "levels.driver_training.spawnpoints.spawn_west"
  --     }, {
  --       flag = "default",
  --       objectname = "spawn_default",
  --       previews = <table 1>,
  --       translationId = "levels.driver_training.spawnpoints.spawn_driver_experience_center"
  --     } },
  --   suitablefor = "levels.driver_training.suitablefor",
  --   title = "levels.driver_training.info.title"
  -- }
  --
  --
  -- translateLanguage('levels.utah.info.title', 'foo')
end

local function getMissionInfo(missionId)
  local miss = gameplay_missions_missions.getMissionById(missionId)

  return {
    id               = miss.id,
    name             = miss.name,
    missionTypeLabel = miss.missionTypeLabel,
    missionType      = miss.missionType,
    date             = miss.date,
    author           = miss.author,
    description      = miss.description,
    fgPath           = miss.fgPath,
    missionFolder    = miss.missionFolder,
    retryBehaviour   = miss.retryBehaviour,
  }

  --miss.id
  --miss.name
  --miss.missionTypeLabel
  --miss.missionType
  --miss.date
  --miss.author
  --miss.description
  --miss.fgPath
  --miss.missionFolder
  --miss.retryBehaviour
  --miss.previewFile = "/ui/modules/gameContext/noPreview.jpg",
  --miss.thumbnailFile = "/ui/modules/gameContext/noThumb.jpg",
  --miss.startTrigger = {
  --  level = "driver_training",
  --  pos = { -394.5310059, 68.92810059, 50.96923065 },
  --  radius = 5.170642376,
  --  rot = { 0.09119108694, -0.2855890806, 0.9087983414, 0.2901872452 },
  --  type = "coordinates"
  --},
  --
  --miss.missionTypeData
  --missionTypeData = {
  --  allowFlip = true,
  --  allowRecover = true,
  --  allowRollingStart = false,
  --  bronzeTime = 180,
  --  bronzeTimePenalty = 20,
  --  bronzeTimeTotal = 180,
  --  closed = false,
  --  defaultLaps = 1,
  --  endScreenText = "end screen text.",
  --  flipLimit = 5,
  --  flipPenalty = 5,
  --  goldTime = 60,
  --  goldTimePenalty = 0,
  --  goldTimeTotal = 60,
  --  justFinishPenalty = 30,
  --  mapPreviewMode = "navgraph",
  --  recoverLimit = 5,
  --  recoverPenalty = 5,
  --  reversible = false,
  --  silverTime = 120,
  --  silverTimePenalty = 10,
  --  silverTimeTotal = 120,
  --  startScreenText = "start screen text."
  --},
end

local function odometerReading(vehId)
  -- core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(vehId), 'odometer')
  local odo = core_vehicleBridge.getCachedVehicleData(vehId, 'odometer')

  -- core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(vehId), 'fuel')
  local fuel = core_vehicleBridge.getCachedVehicleData(vehId, 'fuel')
  local fuelVol = core_vehicleBridge.getCachedVehicleData(vehId, 'fuelVolume')
  local fuelCap = core_vehicleBridge.getCachedVehicleData(vehId, 'fuelCapacity')
  print('fuel: '..dumps(fuel))

  -- core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(vehId), 'stats')
  -- local stats = core_vehicleBridge.getCachedVehicleData(vehId, 'stats')
  -- print(dumps(stats))

  return odo or 0
end

function C:workOnce()
  self.path = self.pinIn.pathData.value
  if not self.path then
    log('W', logTag, 'no pathData')
    return
  end

  self.race = self.pinIn.raceData.value
  if not self.race then
    log('W', logTag, 'no raceData')
    return
  end

  self.vehId = self.pinIn.vehId.value
  if not self.vehId then
    log('W', logTag, 'no vehId')
    return
  end

  local state = self.race.states[self.vehId]

  local vehicle = getPlayerVehicle(0)
  vehicle:queueLuaCommand("print(dumps(obj:calcBeamStats()))")
  vehicle:queueLuaCommand("stats = lpack.encode(obj:calcBeamStats()) ; obj:queueGameEngineLua(\"print(stats))\")")


  -- vehicle:queueLuaCommand([[ local stats = dumps(obj:calcBeamStats()) obj:queueGameEngineLua("print(dumps(" .. stats .. "))") ]])
  -- {
  --   beam_count = 4777,
  --   beams_broken = 0,
  --   beams_deformed = 8,
  --   node_count = 768,
  --   torsionbar_count = 23,
  --   torsionbars_broken = 0,
  --   torsionbars_deformed = 0,
  --   total_weight = 1647.9207763672,
  --   wheel_count = 4,
  --   wheel_weight = 79.99991607666
  -- }
  --
  -- vehicle:queueLuaCommand([[ local val = dumps(electrics.values) obj:queueGameEngineLua("print(dumps(" .. val .. "))") ]])
  -- {
  --   abs = 0,
  --   absActive = 0,
  --   accXSmooth = -0.00057202057039794,
  --   accYSmooth = 0.0015347735725859,
  --   accZSmooth = -9.8079265469987,
  --   airflowspeed = 2.7350635397827e-05,
  --   airspeed = 0.00013801365110767,
  --   altitude = 51.192974599738,
  --   avgWheelAV = 0.0003091733015026,
  --   boost = 0,
  --   boostMax = 19.009999999999,
  --   brake = 0,
  --   brake_input = 0,
  --   brakelight_signal_L = 0,
  --   brakelight_signal_R = 0,
  --   brakelights = 0,
  --   checkengine = false,
  --   clutch = 0,
  --   clutchRatio = 1,
  --   clutchRatio1 = 0,
  --   clutchRatio2 = 0,
  --   clutch_input = 0,
  --   doorFLCoupler_notAttached = 0,
  --   doorFRCoupler_notAttached = 0,
  --   doorRLCoupler_notAttached = 0,
  --   doorRRCoupler_notAttached = 0,
  --   driveshaft = 122.37542274097,
  --   dseWarningPulse = 0,
  --   engineLoad = 0.24098445292475,
  --   engineRunning = 1,
  --   engineThrottle = 0,
  --   esc = 1,
  --   escActive = false,
  --   exhaustFlow = 0.24099216713122,
  --   fog = 0,
  --   freezeState = false,
  --   fuel = 0.96409312866013,
  --   fuelCapacity = 50,
  --   fuelVolume = 48.204656433006,
  --   gear = "D",
  --   gearIndex = 1,
  --   gearModeIndex = 4,
  --   gear_A = 0.27272727272727,
  --   gear_M = 1,
  --   gearboxMode = "realistic",
  --   hasABS = 1,
  --   hasESC = 1,
  --   hasTCS = 1,
  --   hazard = 0,
  --   hazard_enabled = 0,
  --   highbeam = 0,
  --   highbeam_wigwag_L = 0,
  --   highbeam_wigwag_R = 0,
  --   hoodCatchCoupler_notAttached = 0,
  --   hoodLatchCoupler_notAttached = 0,
  --   horn = 0,
  --   idlerpm = 1000,
  --   ignition = true,
  --   ignitionLevel = 2,
  --   isABSBrakeActive = 0,
  --   isShifting = false,
  --   isTCBrakeActive = 0,
  --   isYCBrakeActive = 0,
  --   lightbar = 0,
  --   lights = 0,
  --   lights_state = 0,
  --   lowbeam = 0,
  --   lowfuel = false,
  --   lowhighbeam = 0,
  --   lowhighbeam_signal_L = 0,
  --   lowhighbeam_signal_R = 0,
  --   lowpressure = 0,
  --   maxGearIndex = 7,
  --   maxrpm = 7150,
  --   minGearIndex = -1,
  --   nop = 0,
  --   odometer = 2469.2874341938,
  --   oil = 0,
  --   oiltemp = 92.328678935125,
  --   parking = 0,
  --   parkingbrake = 1,
  --   parkingbrake_input = 1,
  --   parkingbrakelight = 1,
  --   radiatorFanSpin = 0,
  --   reverse = 0,
  --   reverse_wigwag_L = 0,
  --   reverse_wigwag_R = 0,
  --   rpm = 979.16217602286,
  --   rpmTacho = 980.77018681435,
  --   rpmspin = 65.4551111344,
  --   running = true,
  --   signal_L = 0,
  --   signal_R = 0,
  --   signal_left_input = 0,
  --   signal_right_input = 0,
  --   smoothShiftLogicAV = -7.9822216070198e-05,
  --   steering = 4.9508999999047,
  --   steeringUnassisted = -0.01050414893617,
  --   steering_input = -0.01050414893617,
  --   steering_timestamp = 6876.783519,
  --   tailgateCoupler_notAttached = 0,
  --   tcs = 1,
  --   tcsActive = false,
  --   throttle = 0,
  --   throttle_input = 0,
  --   trip = 2469.2874341938,
  --   turboBoost = 0,
  --   turboBoostMax = 19.009999999999,
  --   turboRPM = 0,
  --   turboRpmRatio = 0,
  --   turboSpin = 335.49911669182,
  --   turnsignal = 0,
  --   twoStep = false,
  --   virtualAirspeed = -2.0653657281545,
  --   watertemp = 90.137806993024,
  --   wheelThermals = {
  --     FL = {
  --       brakeCoreTemperature = 14.66723022461,
  --       brakeSurfaceTemperature = 14.667230224609,
  --       brakeThermalEfficiency = 0.91430962108076
  --     },
  --     FR = {
  --       brakeCoreTemperature = 14.66723022461,
  --       brakeSurfaceTemperature = 14.667230224609,
  --       brakeThermalEfficiency = 0.91430962108076
  --     },
  --     RL = {
  --       brakeCoreTemperature = 14.66723022461,
  --       brakeSurfaceTemperature = 14.667230224609,
  --       brakeThermalEfficiency = 0.91430962108076
  --     },
  --     RR = {
  --       brakeCoreTemperature = 14.66723022461,
  --       brakeSurfaceTemperature = 14.667230224609,
  --       brakeThermalEfficiency = 0.91430962108076
  --     }
  --   },
  --   wheelspeed = 9.9395113968525e-05
  -- }

  -- probably not going to use
  -- vehicle:queueLuaCommand([[ local val = dumps(controller.mainController.engineInfo) obj:queueGameEngineLua("print(dumps(" .. val .. "))") ]])
  -- vehicle:queueLuaCommand([[ local val = dumps(wheels.wheelRotators) obj:queueGameEngineLua("print(dumps(" .. val .. "))") ]])

  local vdata = core_vehicle_manager.getPlayerVehicleData()
  local vehicleConfig = vdata.config

  -- includes level id
  local missionId = gameplay_missions_missionManager.getForegroundMissionId()

  local pathnodesExtracted = {}
  for i,pn in ipairs(self.path.pathnodes.sorted) do
    local pnData = {
      i = i,
      id = pn.id,
      name = pn.name,
      pos = pn.pos,
      normal = pn.normal,
      radius = pn.radius,
      visible = pn.visible,
      recovery = pn.recovery,
    }
    table.insert(pathnodesExtracted, pnData)
  end

  local spExtracted = {}
  for i,sp in ipairs(self.path.startPositions.sorted) do
    local spData = {
      i = i,
      id = sp.id,
      name = sp.name,
      pos = sp.pos,
      rot = sp.rot,
    }
    table.insert(spExtracted, spData)
  end

  local segExtracted = {}
  for i,seg in ipairs(self.path.segments.sorted) do
    local segData = {
      i = i,
      id = seg.id,
      name = seg.name,
      from = seg.from,
      to = seg.to,
    }
    table.insert(segExtracted, segData)
  end

  local pathData = {
    defaultStartPosition = self.path.defaultStartPosition,
    startPositions = spExtracted,
    startNode = self.path.startNode,
    endNode = self.path.endNode,
    pathnodes = pathnodesExtracted,
    segments = segExtracted,
  }

  local fnameTick = '/settings/aipacenotes/racelink/tick.json'
  local tickJson = nil
  if FS:fileExists(fnameTick) then
    tickJson = jsonReadFile(fnameTick)
  end
  -- {"last_tick_at":"2024-06-26T21:24:47.391Z","version":"dev"}

  local aipVersionFname = '/aip-version.txt'
  local aipVersion = 'dev'
  if FS:fileExists(aipVersionFname) then
    aipVersion = readFile(aipVersionFname)
  end

  local function removeControlChars(str)
    local utf8_pattern = "[%z\1-\31\127]"
    return str:gsub(utf8_pattern, function(c)
      return ''
    end)
  end

  local function removeNonASCII(input)
    local non_ascii_pattern = "[\128-\255]"
    return input:gsub(non_ascii_pattern, '')
  end

  local devices = {}
  for name,info in pairs(core_input_bindings.devices) do
    devices[name] = removeControlChars(removeNonASCII(info[2]))
  end
  -- core_input_bindings.devices
  -- {
  --   joystick0 = { "{0006346E-0000-0000-0000-504944564944}", "MOZA R12 Base\2?", "0006346E" },
  --   joystick1 = { "{100130B7-0000-0000-0000-504944564944}", "Heusinkveld Sim Pedals Sprint", "100130B7" },
  --   keyboard0 = { "{6F1D2B61-D5A0-11CF-BFC7-444553540000}", "Keyboard", "6F1D2B61" },
  --   mouse0 = { "{6F1D2B60-D5A0-11CF-BFC7-444553540000}", "Mouse", "6F1D2B60" }
  -- }


  -- envsensors.temperature = obj:getEnvTemperature()
  -- envsensors.pressure = obj:getEnvPressure()
  -- lsensors.gravity = obj:getGravity()


  gameplay_aipacenotes.getRallyManager():putOdometerReading(odometerReading(self.vehId))

  local jsonData = {
    finished_at = socket.gettime(),
    timing_data = state.historicTimes[#state.historicTimes],
    vehicle_config = vehicleConfig,
    -- mission_id = missionId,
    race_course = pathData,
    uuid = worldEditorCppApi.generateUUID(),
    recoveries = gameplay_aipacenotes.getRallyManager().recoveries,
    odometer = gameplay_aipacenotes.getRallyManager().odometerReadings,
    level = getLevelInfo(missionId),
    mission = getMissionInfo(missionId),
    restrictScenario = settings.getValue("restrictScenarios"),
    -- damage = map.objects[self.vehId].damage,
    damage = self.pinIn.damage.value,
    gravity = core_environment.getGravity(),
    racelinkTick = tickJson,
    aipVersion = aipVersion,
    devices = devices,
  }

  -- local function escapeControlCharacters(str)
  --   return str:gsub('[%z\1-\31\127]', function(c)
  --     local byte = string.byte(c)
  --     if byte == 8 then return '\\b'
  --     elseif byte == 9 then return '\\t'
  --     elseif byte == 10 then return '\\n'
  --     elseif byte == 12 then return '\\f'
  --     elseif byte == 13 then return '\\r'
  --     else return string.format('\\u%04X', byte)
  --     end
  --   end)
  -- end

  -- local function chcksm(c)
  --   local d = 0xABCDEF
  --   for e = 1, #c do
  --     local f = c:byte(e)
  --     d = bit32.bxor(d, f) * 3
  --     d = bit32.bxor(d, bit32.rshift(d, 16))
  --   end
  --   return d
  -- end

  -- local fname = '/settings/aipacenotes/results/latest_results.txt'
  local attemptDate = string.gsub(tostring(os.date()), ' ', '-')
  attemptDate = string.gsub(attemptDate, ':', '-')
  local attemptMission = string.gsub(missionId, '/', '-')
  local fname = '/settings/aipacenotes/results/aipresult_'..attemptMission..'_'..attemptDate..'_'..tostring(os.time())
  local contents = jsonEncode(jsonData)
  -- contents = escapeControlCharacters(contents)

  -- local cs = chcksm(contents)
  -- cs = string.format("%X", cs)
  -- cs = mime.b64(cs)
  -- contents = mime.b64(contents)

  local f = io.open(fname, "w")
  if f then
    f:write(contents)
    -- f:write("---".."\n")
    -- f:write(cs.."\n")
    f:close()

    local hash = FS:hashFileSHA1(fname)
    local fnamecs = fname..'.'..hash..'.txt'
    FS:renameFile(fname, fnamecs)
  else
    log(logTag, 'E', 'error opening file')
  end
end

return _flowgraph_createNode(C)
