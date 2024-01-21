local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Stage Finish'
C.description = 'Plays audio after crossing the finish line.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}

C.pinSchema = {
  { dir = 'in', type = 'flow',   name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow',   name = 'reset', description = 'Reset for this node.', impulse = true },
  { dir = 'in', type = 'table',  name = 'rallyManager', tableType = 'rallyManager', description = 'The RallyManager' },
}

function C:init()
  self.rallyManager = nil
  self.finished = false
end

function C:work()
  if self.rallyManager == nil then
    self.rallyManager = self.pinIn.rallyManager.value
  end

  if self.pinIn.reset.value then
    self.finished = false
  end

  if self.rallyManager and not self.finished then
    self.rallyManager.audioManager:enqueuePauseSecs(0.75)
    self.rallyManager.audioManager:enqueueStaticPacenoteByName('finish_1/c')
    self.finished = true
  end
end

return _flowgraph_createNode(C)
