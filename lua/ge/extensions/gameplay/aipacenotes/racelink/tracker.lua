local socket = require('socket')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local jbeamIO = require('jbeam/io')

local C = {}
local logTag = 'racelink-tracker'

function C:init(vehId)
  self.session_uuid = self:makeUuid()
  self.vehId = vehId
  self:registerElectrics()

  self:reset()

  log('I', logTag, 'Tracker.init vehId='..tostring(self.vehId)..' uuid='..self.uuid)
end

function C:reset()
  self.missionId = nil
  self.uuid = self:makeUuid()

  self.vehicleStructureReadings = {}
  self.vehicleDrivingReadings = {}
  self.vehicleLuaReadings = {}

  self.flips = {}
  self.recoveries = {}
  self.raceTimingReadings = {}
  self.racePathReadings = {}

  self.missionVarsReadings = {}
end

function C:takeVehicleStructureReading()
  local data = self:getVehicleStructureReading()
  table.insert(self.vehicleStructureReadings, data)
end

function C:takeVehicleDrivingReading()
  local data = self:getVehicleDrivingReading()
  table.insert(self.vehicleDrivingReadings, data)
end


function C:triggerVehicleLuaReading()
  local veh = be:getObjectByID(self.vehId)
  veh:queueLuaCommand("extensions.aipacenotes.sendVehicleReading()")
end

function C:putVehicleLuaReading(data)
  data.reading_taken_at = self:getClockTime()
  table.insert(self.vehicleLuaReadings, data)
end

function C:putMissionVarsReading(data)
  data.reading_taken_at = self:getClockTime()
  table.insert(self.missionVarsReadings, data)
end

function C:makeUuid()
  return worldEditorCppApi.generateUUID()
end

-- use for manual override
function C:setMissionId(missionId)
  self.missionId = missionId
end

function C:registerElectrics()
  core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(self.vehId), 'fuel')
  core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(self.vehId), 'fuelCapacity')
  core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(self.vehId), 'fuelVolume')

  core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(self.vehId), 'odometer')

  core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(self.vehId), 'gearboxMode')
end

function C:startTracking()
  self:reset()
end

function C:addRecovery(recoveryType, race)
  if not self.vehId then
    log('W', logTag, 'no vehId')
    return
  end

  if not race then
    log('W', logTag, 'cant addRecovery because no raceData')
    return
  end

  local state = race.states[self.vehId]
  local currSeg = state.currentSegments
  local time = race.time

  local recoveryEntry = {
    reading_taken_at = self:getClockTime(),
    recoveryType = recoveryType,
    currSegmentId = currSeg,
    time = time,
    damage = map.objects[self.vehId].damage,
  }

  if recoveryType == 'flip' then
    table.insert(self.flips, recoveryEntry)
  elseif recoveryType == 'recovery' then
    table.insert(self.recoveries, recoveryEntry)
  else
    log('E', logTag, 'unknown recovery type: '..tostring(recoveryType))
  end
end

function C:getDamage()
  return map.objects[self.vehId].damage
end

function C:getEnvironment()
  -- getTimeOfDay
  -- getTemperatureK
  --
  -- envsensors.temperature = obj:getEnvTemperature()
  -- envsensors.pressure = obj:getEnvPressure()
  -- lsensors.gravity = obj:getGravity()

  return {
    gravity = core_environment.getGravity(),
  }
end

function C:getClockTime()
  return socket.gettime()
end

function C:printReading()
  print(dumps(self:getVehicleDrivingReading()))
end

-- core_input_bindings.bindings
-- { {
--     contents = {
--       bindings = { {
--           action = "shiftDown",
--           control = "button12",
--           player = 0
--         }, {
--           action = "toggleMenues",
--           control = "button0",
--           player = 0
--         }, {
--           action = "clutch",
--           control = "slider",
--           player = 0
--         }, {
--           action = "toggle4WDStatus",
--           control = "button46",
--           player = 0
--         }, {
--           action = "shiftDown",
--           control = "button112",
--           player = 0
--         }, {
--           action = "shiftUp",
--           control = "button13",
--           player = 0
--         }, {
--           action = "rotate_camera_left",
--           control = "button11",
--           player = 0
--         }, {
--           action = "center_camera",
--           control = "button1",
--           player = 0
--         }, {
--           action = "menu_item_up",
--           control = "button4",
--           player = 0
--         }, {
--           action = "toggle_headlights",
--           control = "button21",
--           player = 0
--         }, {
--           action = "menu_item_right",
--           control = "rpov",
--           player = 0
--         }, {
--           action = "menu_item_right",
--           control = "button5",
--           player = 0
--         }, {
--           action = "pause",
--           control = "button33",
--           player = 0
--         }, {
--           action = "parkingbrake",
--           control = "slider2",
--           deadzoneResting = 0.1,
--           player = 0
--         }, {
--           action = "toggleRangeStatus",
--           control = "button36",
--           player = 0
--         }, {
--           action = "menu_item_up",
--           control = "upov",
--           player = 0
--         }, {
--           action = "toggle_slow_motion",
--           control = "button18",
--           player = 0
--         }, {
--           action = "toggleBigMap",
--           control = "button23",
--           player = 0
--         }, {
--           action = "shiftUp",
--           control = "button113",
--           player = 0
--         }, {
--           action = "menu_item_down",
--           control = "dpov",
--           player = 0
--         }, {
--           action = "rotate_camera_up",
--           control = "button8",
--           player = 0
--         }, {
--           action = "switch_camera_next",
--           control = "button114",
--           player = 0
--         }, {
--           action = "toggleDiffMode",
--           control = "button47",
--           player = 0
--         }, {
--           action = "previousESCMode",
--           control = "button46",
--           player = 0
--         }, {
--           action = "parkingbrake_toggle",
--           control = "button115",
--           player = 0
--         }, {
--           action = "accelerate",
--           control = "zaxis",
--           player = 0
--         }, {
--           action = "reset_physics",
--           control = "button34",
--           player = 0
--         }, {
--           action = "menu_item_down",
--           control = "button6",
--           player = 0
--         }, {
--           action = "rotate_camera_right",
--           control = "button9",
--           player = 0
--         }, {
--           action = "brake",
--           control = "rzaxis",
--           player = 0
--         }, {
--           action = "switch_camera_next",
--           control = "button20",
--           player = 0
--         }, {
--           action = "steering",
--           angle = 900,
--           control = "xaxis",
--           ffb = {
--             forceCoef = 150,
--             frequency = 0,
--             gforceCoef = 0.2,
--             lowspeedCoef = true,
--             responseCorrected = false,
--             responseCurve = { { 0, 0 }, { 1, 1 } },
--             smoothing = 50,
--             smoothing2 = 50,
--             smoothing2automatic = false,
--             smoothing2autostr = 470,
--             softlockForce = 1,
--             updateType = 0
--           },
--           isForceEnabled = true,
--           player = 0
--         }, {
--           action = "menu_item_select",
--           control = "button19",
--           player = 0
--         }, {
--           action = "gearR",
--           control = "button116",
--           player = 0
--         }, {
--           action = "toggle_slow_motion",
--           control = "button45",
--           player = 0
--         }, {
--           action = "rotate_camera_down",
--           control = "button10",
--           player = 0
--         }, {
--           action = "menu_item_left",
--           control = "button7",
--           player = 0
--         }, {
--           action = "menu_item_left",
--           control = "lpov",
--           player = 0
--         }, {
--           action = "recover_vehicle_alt",
--           control = "button35",
--           player = 0
--         } },
--       devicetype = "joystick",
--       guid = "{0006346E-0000-0000-0000-504944564944}",
--       name = "MOZA R12 Base\2",
--       vendorName = "Moza",
--       version = 1,
--       vidpid = "0006346E"
--     },
--     devname = "joystick0"
--   }, {
--     contents = {
--       bindings = { {
--           action = "accelerate",
--           control = "rxaxis",
--           player = 0
--         }, {
--           action = "brake",
--           control = "ryaxis",
--           player = 0
--         }, {
--           action = "clutch",
--           control = "rzaxis",
--           player = 0
--         } },
--       devicetype = "joystick",
--       guid = "{100130B7-0000-0000-0000-504944564944}",
--       name = "Heusinkveld Sim Pedals Sprint",
--       vendorName = "Heusinkveld",
--       version = 1,
--       vidpid = "100130B7"
--     },
--     devname = "joystick1"
--   }, {
--     contents = {
--       bindings = { {
--           action = "decreaseDecalScaleY",
--           control = "s",
--           player = 0
--         }, {
--           action = "editorSafeModeToggle",
--           control = "ctrl f11",
--           player = 0
--         }, {
--           action = "camera_8",
--           control = "8",
--   .....
--
-- local ffbid getPlayerVehicle(0):getFFBID('steering')
-- be:getFFBConfig(ffbid)
-- returns json string => '{"ff_max_force":10,"ff_res":0,"ffbParamsJson":"{\\"frequency\\":0,\\"responseCurve\\":[[0,0],[1,1]],\\"responseCorrected\\":false,\\"smoothing2automatic\\":false,\\"gforceCoef\\":0.2,\\"lowspeedCoef\\":true,\\"smoothing\\":50,\\"smoothing2\\":50,\\"smoothing2autostr\\":470,\\"forceCoef\\":150,\\"softlockForce\\":1,\\"updateType\\":0}","ffbSendms":1.0200820000318345}\n'
--
--
-- core_input_bindings.devices
-- {
--   joystick0 = { "{0006346E-0000-0000-0000-504944564944}", "MOZA R12 Base\2?", "0006346E" },
--   joystick1 = { "{100130B7-0000-0000-0000-504944564944}", "Heusinkveld Sim Pedals Sprint", "100130B7" },
--   keyboard0 = { "{6F1D2B61-D5A0-11CF-BFC7-444553540000}", "Keyboard", "6F1D2B61" },
--   mouse0    = { "{6F1D2B60-D5A0-11CF-BFC7-444553540000}", "Mouse", "6F1D2B60" }
--   xinput0   = { "xinput0",                                "XBox Controller 1", "XIDevice" }
-- }
local function removeControlChars(str)
  if not str then return str end
  local utf8_pattern = "[%z\1-\31\127]"
  return str:gsub(utf8_pattern, function(c)
    return ''
  end)
end

local function removeNonASCII(input)
  if not input then return input end
  local non_ascii_pattern = "[\128-\255]"
  return input:gsub(non_ascii_pattern, '')
end

function C:getDevices()
  local hasForceEnabledSteering = false
  local collectedDevices = {}

  for i,deviceBindings in ipairs(core_input_bindings.bindings) do
    local devname = deviceBindings.devname
    local devinfo = {}

    local contents = deviceBindings.contents
    local devicetype = contents.devicetype
    local name = contents.name
    local vendorName = contents.vendorName

    devinfo.devicetype = devicetype
    devinfo.name = removeControlChars(removeNonASCII(name))
    devinfo.vendorName = removeControlChars(removeNonASCII(vendorName))
    devinfo.hasForceEnabledSteering = false

    local bindings = contents.bindings
    for j,binding in ipairs(bindings) do
      if binding.action == 'steering' then
        print(dumps( binding ))
        if binding.isForceEnabled and binding.ffb then
          hasForceEnabledSteering = true
          devinfo.hasForceEnabledSteering = true
          devinfo.forceEnabledSteeringBinding = deepcopy(binding)
        end
      end
    end

    collectedDevices[devname] = devinfo
  end

  return {
    ffbSteering = hasForceEnabledSteering,
    devices = collectedDevices,
  }

  -- local foundFFBSteering = false
  -- local veh = be:getObjectByID(self.vehId)
  -- local ffbid = veh:getFFBID('steering')
  -- if ffbid >= 0 then
  --   foundFFBSteering = true
  -- end
  -- be:getFFBConfig(ffbid)

  -- local devices = {}
  -- for name,info in pairs(deepcopy(core_input_bindings.devices)) do
  --   devices[name] = removeControlChars(removeNonASCII(info[2]))
  -- end

  -- return {
  --   ffbSteering = foundFFBSteering,
  --   devices = devices,
  -- }
end

function C:getAipVersion()
  local aipVersionFname = '/aip-version.txt'
  local aipVersion = 'dev'
  if FS:fileExists(aipVersionFname) then
    aipVersion = readFile(aipVersionFname)
  end
  return aipVersion
end

-- {"last_tick_at":"2024-06-26T21:24:47.391Z","version":"dev"}
function C:getRacelinkTickData()
  local fnameTick = '/settings/aipacenotes/racelink/tick.json'
  local tickJson = 'none'
  if FS:fileExists(fnameTick) then
    tickJson = jsonReadFile(fnameTick)
  end
  return tickJson
end

-- {
--   configs = {
--     ["0-100 km/h"] = 6.5,
--     ["0-100 mph"] = 16,
--     ["0-200 km/h"] = 39.6,
--     ["0-60 mph"] = 6.2,
--     ["100-0 km/h"] = 36,
--     ["100-200 km/h"] = 33,
--     ["60-0 mph"] = 109.3,
--     ["60-100 mph"] = 9.8,
--     BoundingBox = { { -0.6993, -2.047, -0.1987 }, { 1.1993, 2.3499, 1.0798 } },
--     ["Braking G"] = 1.093,
--     ["Config Type"] = "Custom",
--     Configuration = "Rally (SQ)",
--     Description = "Peppy rear wheel driven rally car based on the 240bx coupe USDM model",
--     Drivetrain = "RWD",
--     ["Fuel Type"] = "Gasoline",
--     ["Induction Type"] = "NA",
--     Name = "BX-Series Rally (SQ)",
--     ["Off-Road Score"] = 34,
--     Population = 100,
--     Power = 178,
--     PowerPeakRPM = "5550 - 6350",
--     Propulsion = "ICE",
--     Source = "BeamNG - Official",
--     -- NOTE Source becomes "Custom" if it's a custom config. it stays as BeamNG if you just make a part change but dont save a config.
--     ["Top Speed"] = 55.55410229,
--     Torque = 235,
--     TorquePeakRPM = "4300 - 5450",
--     Transmission = "Sequential",
--     Value = 45000,
--     Weight = 1175,
--     ["Weight/Power"] = 6.601123596,
--     aggregates = {
--       ["0-100 km/h"] = {
--         max = 6.5,
--         min = 6.5
--       },
--       ["0-60 mph"] = {
--         max = 6.2,
--         min = 6.2
--       },
--       ["Body Style"] = {
--         Coupe = true
--       },
--       Brand = {
--         Ibishu = true
--       },
--       ["Config Type"] = {
--         Custom = true
--       },
--       Country = {
--         Japan = true
--       },
--       ["Derby Class"] = {
--         ["Compact Car"] = true
--       },
--       Drivetrain = {
--         RWD = true
--       },
--       ["Fuel Type"] = {
--         Gasoline = true
--       },
--       ["Induction Type"] = {
--         NA = true
--       },
--       ["Off-Road Score"] = {
--         max = 34,
--         min = 34
--       },
--       Propulsion = {
--         ICE = true
--       },
--       Source = {
--         ["BeamNG - Official"] = true
--       },
--       ["Top Speed"] = {
--         max = 55.55410229,
--         min = 55.55410229
--       },
--       Transmission = {
--         Sequential = true
--       },
--       Type = {
--         Car = true
--       },
--       Value = {
--         max = 45000,
--         min = 45000
--       },
--       Weight = {
--         max = 1175,
--         min = 1175
--       },
--       ["Weight/Power"] = {
--         max = 6.601123596,
--         min = 6.601123596
--       },
--       Years = {
--         max = 1994,
--         min = 1990
--       }
--     },
--     defaultPaint = <1>{
--       baseColor = { 0.65, 0.65, 0.65, 1.2 },
--       clearcoat = 1,
--       clearcoatRoughness = 0.06,
--       metallic = 0.9,
--       roughness = 0.6
--     },
--     defaultPaintName1 = "Silver",
--     defaultPaintName2 = "Sea Blue",
--     is_default_config = false,
--     key = "240bx_coupe_rally_sq",
--     model_key = "bx",
--     preview = "/vehicles/bx/240bx_coupe_rally_sq.jpg"
--   },
--   current = {
--     color = <userdata 1>,
--     config_key = "240bx_coupe_rally_sq",
--     key = "bx",
--     pc_file = "vehicles/bx/240bx_coupe_rally_sq.pc",
--     -- NOTE pc_file becomes a dumped table of parts tree if you make a part change.
--     position = vec3(-394.5715942,68.81899261,51.20552444)
--   },
--   model = {
--     Author = "BeamNG",
--     ["Body Style"] = "Coupe",
--     Brand = "Ibishu",
--     Country = "Japan",
--     ["Derby Class"] = "Compact Car",
--     Name = "BX-Series",
--     Type = "Car",
--     Years = {
--       max = 1994,
--       min = 1990
--     },
--     aggregates = {
--       ["0-100 km/h"] = {
--         max = 9,
--         min = 2.7
--       },
--       ["0-60 mph"] = {
--         max = 8.5,
--         min = 2.6
--       },
--       ["Body Style"] = {
--         Coupe = true,
--         Liftback = true
--       },
--       Brand = {
--         Ibishu = true
--       },
--       ["Config Type"] = {
--         Custom = true,
--         Factory = true,
--         Police = true
--       },
--       Country = {
--         Japan = true
--       },
--       ["Derby Class"] = {
--         ["Compact Car"] = true
--       },
--       Drivetrain = {
--         RWD = true
--       },
--       ["Fuel Type"] = {
--         Gasoline = true
--       },
--       ["Induction Type"] = {
--         NA = true,
--         Turbo = true,
--         ["Turbo + N2O"] = true
--       },
--       ["Off-Road Score"] = {
--         max = 34,
--         min = 21
--       },
--       Propulsion = {
--         ICE = true
--       },
--       Source = {
--         ["BeamNG - Official"] = true
--       },
--       ["Top Speed"] = {
--         max = 100.2674628,
--         min = 44.62657233
--       },
--       Transmission = {
--         Automatic = true,
--         Manual = true,
--         Sequential = true
--       },
--       Type = {
--         Car = true,
--         PropParked = true,
--         PropTraffic = true
--       },
--       Value = {
--         max = 85000,
--         min = 28500
--       },
--       Weight = {
--         max = 1315,
--         min = 1175
--       },
--       ["Weight/Power"] = {
--         max = 8.793103448,
--         min = 0.9270516717
--       },
--       Years = {
--         max = 1994,
--         min = 1990
--       }
--     },
--     defaultPaint = <2>{
--       baseColor = { 0.31, 0, 0.03, 1.2 },
--       clearcoat = 1,
--       clearcoatRoughness = 0.06,
--       metallic = 0.5,
--       roughness = 0.6
--     },
--     defaultPaintName1 = "Deep Plum",
--     default_pc = "200bx_type_l_M",
--     key = "bx",
--     logo = "/ui/images/appDefault.png",
--     paints = {
--       Aquamarine = {
--         baseColor = { 0.05, 0.5, 0.7, 1.2 },
--         clearcoat = 1,
--         clearcoatRoughness = 0.06,
--         metallic = 0,
--         roughness = 1
--       },
--       ...
--     },
--     preview = "/vehicles/bx/default.jpg"
--   },
--   userDefault = false
-- } <- output from core_vehicles.getCurrentVehicleDetails()
-- can be used in freeroam
--
--
-- TODO
-- jbeamIO = require('jbeam/io')
-- vd = core_vehicle_manager.getVehicleData(46856)
-- jbeamIO.getAvailableParts(vd.ioCtx)
--
-- jbeamIO.getAvailableParts(vd.ioCtx)[config.mainPartName]
--  {
--   authors = "BeamNG",
--   description = "Cherrier Vivace",
--   slotInfoUi = {
--     licenseplate_design_2_1 = {
--       allowTypes = { "licenseplate_design_2_1" },
--       denyTypes = {},
--       description = "License Plate Design",
--       name = "licenseplate_design_2_1"
--     },
--     paint_design = {
--       allowTypes = { "paint_design" },
--       denyTypes = {},
--       description = "Paint Design",
--       name = "paint_design"
--     },
--     vivace_body = {
--       allowTypes = { "vivace_body" },
--       coreSlot = true,
--       denyTypes = {},
--       description = "Body",
--       name = "vivace_body"
--     },
--     vivace_mod = {
--       allowTypes = { "vivace_mod" },
--       denyTypes = {},
--       description = "Additional Modification",
--       name = "vivace_mod"
--     }
--   }
-- }
-- Then recursively iterate slotInfoUi
--
--config.parts
local function populatePartNames(vehicleData)
  -- local rv = {}
  local partNameToDescriptionMap = {}
  local slotNameToDescriptionMap = {}
  local config = vehicleData.config

  local avail = jbeamIO.getAvailableParts(vehicleData.ioCtx)

  local function cachePart(partId)
    -- print('caching "'..partId..'"')
    local partInfo = avail[partId]
    if partInfo then
      partNameToDescriptionMap[partId] = partInfo.description

      for slotId, slotInfo in pairs(partInfo.slotInfoUi) do
        slotNameToDescriptionMap[slotId] = slotInfo.description
      end
    else
      -- print('no partInfo for '..partId)
    end
  end

  -- local mainPartName = config.mainPartName
  cachePart(config.mainPartName)
  -- local mainPartNameNice = avail[config.mainPartName].description
  -- print('mainPartName='..mainPartName..' nice='..mainPartNameNice)
  --
  for slot,part in pairs(config.parts) do
    -- print(slot..'='..part)
    -- print(slot..'->'..'asdf')
    -- print('-------------------------------------------------------------')
    cachePart(part)
  end

  return partNameToDescriptionMap, slotNameToDescriptionMap
end

function C:getVehicleStructureReading()
  local vehicleData = core_vehicle_manager.getVehicleData(self.vehId)
  local config = deepcopy(vehicleData.config)
  config.paints = nil
  local vars = deepcopy(vehicleData.vdata.variables)

  local vehicleDetails = core_vehicles.getCurrentVehicleDetails()
  vehicleDetails = deepcopy(vehicleDetails)

  vehicleDetails.configs.defaultPaint = nil
  vehicleDetails.configs.defaultPaintName1 = nil
  vehicleDetails.configs.defaultPaintName2 = nil

  vehicleDetails.current.color = nil
  vehicleDetails.current.position = nil

  vehicleDetails.model.paints = nil
  vehicleDetails.model.defaultPaint = nil
  vehicleDetails.model.defaultPaintName1 = nil

  local rv = {
    reading_taken_at = self:getClockTime(),

    core_vehicles = {
      getCurrentVehicleDetails = vehicleDetails
    },

    core_vehicle_manager = {
      getVehicleData = {
        config = config,
        vdata = {
          variables = vars,
        }
      }
    }
  }

  -- local database = jbeamIO.getAvailableParts(vehicleData.ioCtx)

  -- local partNameToDescriptionMap, slotNameToDescriptionMap = createNameToDescriptionMaps(config, avail)

  local partToDescriptionMap, slotToDescriptionMap = populatePartNames(vehicleData)

  -- print("/nSlot Descriptions:")
  -- for slot, description in pairs(slotToDescriptionMap) do
  --   print(slot, description)
  -- end
  --
  -- print("\nPart Descriptions:")
  -- for part, description in pairs(partToDescriptionMap) do
  --   print(part, description)
  -- end

  -- for slot,part in pairs(config.parts) do
    -- print(slot .. ' -> ' .. part)
    -- print(tostring(slotToDescriptionMap[slot])..'('.. slot ..')' .. ' -> ' .. tostring(partToDescriptionMap[part])..'('.. part ..')')
  -- end

  rv.partNiceNames = partToDescriptionMap
  rv.slotNiceNames = slotToDescriptionMap

  return rv
end

function C:takeRacePathReading(racePath)
  if not racePath then
    return nil
  end

  local pathnodesExtracted = {}
  for i,pn in ipairs(racePath.pathnodes.sorted) do
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
  for i,sp in ipairs(racePath.startPositions.sorted) do
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
  for i,seg in ipairs(racePath.segments.sorted) do
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
    defaultStartPosition = racePath.defaultStartPosition,
    startPositions = spExtracted,
    startNode = racePath.startNode,
    endNode = racePath.endNode,
    pathnodes = pathnodesExtracted,
    segments = segExtracted,
  }

  table.insert(self.racePathReadings, pathData)
end

function C:takeRaceTimingReading(race)
  if not race then
    return nil
  end

  local state = race.states[self.vehId]
  local timingData = deepcopy(state.historicTimes[#state.historicTimes])

  table.insert(self.raceTimingReadings, timingData)
end

function C:getSettings()
  return {
    restrictScenarios = settings.getValue("restrictScenarios"),
    absBehavior = settings.getValue("absBehavior"),
    escBehavior = settings.getValue("escBehavior"),
    defaultGearboxBehavior = settings.getValue("defaultGearboxBehavior"),
    gearboxSafety = settings.getValue("gearboxSafety"),
    autoClutch = settings.getValue("autoClutch"),
    autoThrottle = settings.getValue("autoThrottle"),
    steeringStabilizationEnabled = settings.getValue("steeringStabilizationEnabled"),
    steeringUndersteerReductionEnabled = settings.getValue("steeringUndersteerReductionEnabled"),
    steeringSlowdownEnabled = settings.getValue("steeringSlowdownEnabled"),
    steeringLimitEnabled = settings.getValue("steeringLimitEnabled"),
    steeringAutocenterEnabled = settings.getValue("steeringAutocenterEnabled"),
    spawnVehicleIgnitionLevel = settings.getValue("spawnVehicleIgnitionLevel"),
    startThermalsPreHeated = settings.getValue("startThermalsPreHeated"),
    startBrakeThermalsPreHeated = settings.getValue("startBrakeThermalsPreHeated"),
    disableDynamicCollision = settings.getValue("disableDynamicCollision"),
  }

  -- restrictScenarios = settings.getValue("restrictScenarios"),
  -- settings.getValue("absBehavior")
  -- settings.getValue("escBehavior")
  -- settings.getValue("startBrakeThermalsPreHeated")
  -- settings.getValue("startBrakeThermalsPreHeated")
  --defaultGearboxBehavior
  --gearboxSafety
  --autoClutch
  --autoThrottle
  --steeringStabilizationEnabled
  --steeringUndersteerReductionEnabled
  --steeringSlowdownEnabled
  --steeringLimitEnabled
  --steeringAutocenterEnabled
  --spawnVehicleIgnitionLevel
  --startThermalsPreHeated
  --startBrakeThermalsPreHeated
  --disableDynamicCollision
end

function C:getElectrics()
  local fuel = core_vehicleBridge.getCachedVehicleData(self.vehId, 'fuel')
  local fuelVol = core_vehicleBridge.getCachedVehicleData(self.vehId, 'fuelVolume')
  local fuelCap = core_vehicleBridge.getCachedVehicleData(self.vehId, 'fuelCapacity')

  local odo = core_vehicleBridge.getCachedVehicleData(self.vehId, 'odometer')

  local gearboxMode = core_vehicleBridge.getCachedVehicleData(self.vehId, 'gearboxMode')

  return {
    fuel = fuel,
    fuelVolume = fuelVol,
    fuelCapacity = fuelCap,
    odometer = odo,
    gearboxMode = gearboxMode,
  }
end

function C:getForegroundMissionId()
  if self.missionId then
    return self.missionId
  end

  local missionId, _, _ = re_util.detectMissionIdHelper()
  return missionId
end

local function extractLevelId(missionId)
  return string.match(missionId, "([^/]+)")
end

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
function C:getLevelInfo()
  local missionId = self:getForegroundMissionId()

  if not missionId then
    return nil
  end

  local levelId = extractLevelId(missionId)
  local levelInfo = core_levels.getLevelByName(levelId)

  return {
    id = levelId,
    authors = levelInfo.authors,
    description = levelInfo.description,
    title = levelInfo.title,
    size = levelInfo.size,
  }
end

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
function C:getMissionInfo()
  local missionId = self:getForegroundMissionId()

  if not missionId then
    return nil
  end

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
    missionTypeData  = miss.missionTypeData
  }
end

-- can be used in freeroam
function C:getVehicleDrivingReading()
  local reading = {
    reading_taken_at = self:getClockTime(),
    electrics = self:getElectrics(),
    damage = self:getDamage(),
  }
  return reading
end

-- only can be used when a mission is loaded
function C:getMissionReading()
  local reading = {
    level = self:getLevelInfo(),
    mission = self:getMissionInfo(),
    flowgraphVars = self.missionVarsReadings,
  }
  return reading
end

-- only can be used when a mission is loaded
function C:getRaceReading()
  local reading = {
    course = self.racePathReadings,
    timing = self.raceTimingReadings,
    flips = self.flips,
    recoveries = self.recoveries,
  }
  return reading
end

function C:getAllData()
  local data = {
    uuid = self.uuid,
    reading_taken_at = self:getClockTime(),
    racelinkTick = self:getRacelinkTickData(),
    aipVersion = self:getAipVersion(),

    -- can be used in freeroam
    devices = self:getDevices(),
    settings = self:getSettings(),
    environment = self:getEnvironment(),

    vehicle = {
      structure = self.vehicleStructureReadings,
      driving = self.vehicleDrivingReadings,
      vlua = self.vehicleLuaReadings,
    },
    mission = self:getMissionReading(),
    race = self:getRaceReading(),
  }

  return data
end

function C:write()
  local missionId = self:getForegroundMissionId()

  if not missionId then
    missionId = 'unknown'
  end

  local nowTimestamp = string.gsub(tostring(os.date()), ' ', '-')
  nowTimestamp = string.gsub(nowTimestamp, ':', '-')
  local attemptMission = string.gsub(missionId, '/', '-')
  local fname = '/settings/aipacenotes/results/aipresult_'..attemptMission..'_'..nowTimestamp..'_'..tostring(os.time())
  local jsonData = self:getAllData()
  local contents = jsonEncode(jsonData)

  local f = io.open(fname, "w")
  if f then
    f:write(contents)
    f:close()

    local hash = FS:hashFileSHA1(fname)
    local fnamecs = fname..'.'..hash..'.txt'
    FS:renameFile(fname, fnamecs)
  else
    log(logTag, 'E', 'error opening file')
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
