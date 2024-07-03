-- local im  = ui_imgui
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aip-fg-loader'

C.name = 'AI Pacenotes Racelink Init'
C.description = 'Setup Racelink'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_p_duration'
-- C.category = 'once'

C.pinSchema = {
  -- { dir = 'in', type = 'flow',   name = 'flow',  description = 'Inflow for this node.' },
  -- { dir = 'in', type = 'flow',   name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},

  -- { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
  -- { dir = 'out', type = 'table', name = 'rallyManager', tableType = 'rallyManager', description = 'The RallyManager' },
}

-- this is called when the flowgraph code node is created, not when the flowgraph runs.
-- function C:init()
-- end

local readyHit = false
function C:reset()
  log('D', logTag, 'running AIP Loader v2')
  readyHit = false

  extensions.unload('gameplay_racelink')
  extensions.load('gameplay_racelink')

  gameplay_racelink.initTracker(self.pinIn.vehId.value)
end

function C:workOnce()
  log('D', logTag, 'workOnce')
  self:reset()
end

function C:work()
  if not readyHit then
    local loaded = extensions.isExtensionLoaded("gameplay_racelink")
    if loaded and gameplay_racelink.isReady() then
      log('D', logTag, 'extension is ready')
      readyHit = true
    end
  end

  self.pinOut.flow.value = false
end

return _flowgraph_createNode(C)
