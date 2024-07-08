-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt


-- getPlayerVehicle(0):queueLuaCommand("extensions.unload('aipacenotes')")
-- getPlayerVehicle(0):queueLuaCommand("extensions.aipacenotes.sendVehicleReading()")

local M = {}

local lastReading = nil

-- local abs = math.abs
--
-- local relativeOdometer = 0
-- local submitedStatOdo = 0
-- local submitedTime = 0
--
-- local function onReset()
--   M.submitStatistic()
-- end
--
-- local function updateGFX(dt)
--   relativeOdometer = relativeOdometer + abs(electrics.values.wheelspeed or 0) * dt
--   submitedTime = submitedTime+dt
--   if ai.mode == "disabled" and submitedTime > 30 then
--     M.submitStatistic()
--     submitedTime = 0
--   end
-- end
--
-- local function startRecording()
--   --relativeOdometer = 0
-- end
--
-- local function getRelativeRecording()
--   return relativeOdometer
-- end

local function onExtensionLoaded()
  log('D', 'vAip', 'loaded aipacenotes vehicle extension')
end

local function test()
  log('D', 'vAip', 'test')
end

-- local vehicle = getPlayerVehicle(0)
-- vehicle:queueLuaCommand("print(dumps(obj:calcBeamStats()))")
-- vehicle:queueLuaCommand("stats = lpack.encode(obj:calcBeamStats()) ; obj:queueGameEngineLua(\"print(stats))\")")
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
local function getStats()
  log('D', 'vAip', 'stats')
  local res = obj:calcBeamStats()
  -- print(dumps(res))
  return res
end

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
-- ^ full electrics for a particular vehicle.
local function printElectrics()
  log('D', 'vAip', 'printElectrics')
  local res = electrics.values
  print(dumps(res))
end

local function getDriveModeKey()
  local drivemode = controller.getController('driveModes')
  if drivemode then
    return drivemode.getCurrentDriveModeKey()
  else
    return 'nil'
  end
end

local function takeReading()
  lastReading = {
    stats = getStats(),
    driveMode = getDriveModeKey(),
  }
end

-- print(dumps(controller.mainController.engineInfo))
-- wheels.wheelRotators
local function sendVehicleReading()
  log('D', 'vAip', 'sendVehicleReading')

  local payload = jsonEncode(lastReading)
  -- print(payload)
  obj:queueGameEngineLua('extensions.gameplay_racelink.receiveVehicleReading([['..payload..']])')
end

local function updateGFX(dt)
  takeReading()
end

-- public interface
-- M.onReset = onReset
M.updateGFX = updateGFX

-- M.startRecording = startRecording
-- M.getRelativeRecording = getRelativeRecording
-- M.submitStatistic = submitStatistic

M.onExtensionLoaded = onExtensionLoaded

M.test = test
-- M.stats = stats
-- M.printElectrics = printElectrics
M.sendVehicleReading = sendVehicleReading

return M
