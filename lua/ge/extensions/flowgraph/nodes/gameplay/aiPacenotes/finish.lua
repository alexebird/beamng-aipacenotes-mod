local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Stage Finish'
C.description = 'Plays audio after crossing the finish line.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_instant'

C.pinSchema = {
}

function C:workOnce()
  extensions.gameplay_aipacenotes.getRallyManager().audioManager:enqueuePauseSecs(0.75)
  extensions.gameplay_aipacenotes.getRallyManager().audioManager:enqueueStaticPacenoteByName('finish_1/c')
  -- self.pinOut.flow.value = true
end

return _flowgraph_createNode(C)
