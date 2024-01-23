local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Stage Finish'
C.description = 'Plays audio after crossing the finish line.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}

C.pinSchema = {
  -- { dir = 'in', type = 'flow',   name = 'flow', description = 'Inflow for this node.' },
  -- { dir = 'in', type = 'flow',   name = 'reset', description = 'Reset for this node.', impulse = true },
  { dir = 'in', type = 'flow',   name = 'onFinish', description = 'When finish happens', impulse = true },
}

-- function C:init()
-- end

function C:work()
  if self.pinIn.onFinish.value then
    extensions.gameplay_aipacenotes.getRallyManager().audioManager:enqueuePauseSecs(0.75)
    extensions.gameplay_aipacenotes.getRallyManager().audioManager:enqueueStaticPacenoteByName('finish_1/c')
  end
end

return _flowgraph_createNode(C)
