local im  = ui_imgui
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Loader'
C.description = 'Do necessary loading for AI Pacenotes.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_p_duration'

C.pinSchema = {
  -- { dir = 'in', type = 'flow',   name = 'flow',  description = 'Inflow for this node.' },
  -- { dir = 'in', type = 'flow',   name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'number', name = 'damageThresh', description = 'Damage threshold to play damage audio.', default = 500},
  { dir = 'in', type = 'number', name = 'searchN', description = 'Number of closest pacenotes to search when vehicle position is reset.', default = 5},

  -- { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
  { dir = 'out', type = 'table', name = 'rallyManager', tableType = 'rallyManager', description = 'The RallyManager' },
}

function C:init()
end

-- function C:drawCustomProperties()
--   local txt = '<not loaded>'
--   if self.rallyManager then
--     txt = self.rallyManager:toString()
--   end
--   im.Text(txt)
-- end

function C:reset()
  log('D', 'wtf', 'running AIP loader')
  self.rallyManager = require('/lua/ge/extensions/gameplay/rally/rallyManager')()
  self.rallyManager:setup(
    self.pinIn.vehId.value,
    self.pinIn.damageThresh.value,
    self.pinIn.searchN.value
  )
end

function C:onNodeReset()
  self.rallyManager = nil
end

function C:_executionStopped()
  self.rallyManager = nil
end

function C:work()
  -- if self.pinIn.reset.value then
  --   self.rallyManager = nil
  -- end

  if not self.rallyManager then
    self:reset()
    self.pinOut.rallyManager.value = self.rallyManager
  end
end

return _flowgraph_createNode(C)
