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
  core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(vehId), 'odometer')
  local odo = core_vehicleBridge.getCachedVehicleData(vehId, 'odometer')
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
