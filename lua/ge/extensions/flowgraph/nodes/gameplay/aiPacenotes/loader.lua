-- local im  = ui_imgui
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aip-fg-loader'

C.name = 'AI Pacenotes Loader'
C.description = 'Do necessary loading for AI Pacenotes.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_p_duration'
-- C.category = 'once'

C.pinSchema = {
  -- { dir = 'in', type = 'flow',   name = 'flow',  description = 'Inflow for this node.' },
  -- { dir = 'in', type = 'flow',   name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'number', name = 'damageThresh', description = 'Damage threshold to play damage audio.', default = 500},
  { dir = 'in', type = 'number', name = 'searchN', description = 'Number of closest pacenotes to search when vehicle position is reset.', default = 5},

  -- { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
  -- { dir = 'out', type = 'table', name = 'rallyManager', tableType = 'rallyManager', description = 'The RallyManager' },
}

-- this is called when the flowgraph code node is created, not when the flowgraph runs.
function C:init()
end

local readyHit = false
function C:reset()
  log('D', logTag, 'running AIP Loader v2')
  readyHit = false

  extensions.unload('gameplay_aipacenotes')
  extensions.load('gameplay_aipacenotes')

  -- extensions.gameplay_aipacenotes.helloWorld()

  gameplay_aipacenotes.initRallyManager()
end

function C:workOnce()
  log('D', logTag, 'workOnce')
  self:reset()
end

local function odometerReading(vehId)
  -- veh = getPlayerVehicle(0)
  -- veh = be:getObjectByID(be:getPlayerVehicleID(0))
  -- core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(be:getPlayerVehicleID(0)), 'odometer')
  -- core_vehicleBridge.getCachedVehicleData(be:getPlayerVehicleID(0), 'odometer')

  core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(vehId), 'odometer')
  local odo = core_vehicleBridge.getCachedVehicleData(vehId, 'odometer')
  -- print('odo: '..tostring(odo))
  return odo or 0
end

function C:work()
  if not readyHit then
    local loaded = extensions.isExtensionLoaded("gameplay_aipacenotes")
    if loaded and gameplay_aipacenotes.isReady() then
      log('D', logTag, 'extension is ready')
      gameplay_aipacenotes.getRallyManager():putOdometerReading(odometerReading(self.pinIn.vehId.value))
      readyHit = true
    end
  end

  self.pinOut.flow.value = false
end

return _flowgraph_createNode(C)
