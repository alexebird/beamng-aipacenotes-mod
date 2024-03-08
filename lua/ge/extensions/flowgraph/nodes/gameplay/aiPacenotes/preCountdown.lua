local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Pre-Countdown'
C.description = 'Plays pre-countdown audio.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_p_duration'

C.pinSchema = {
}

function C:workOnce()
  -- extensions.gameplay_aipacenotes.getRallyManager().audioManager:enqueuePauseSecs(0.75)
  extensions.gameplay_aipacenotes.getRallyManager().audioManager:enqueueStaticPacenoteByName('firstnoteintro_1/c')
  local pacenote = extensions.gameplay_aipacenotes.getRallyManager().notebook.pacenotes.sorted[1]
  extensions.gameplay_aipacenotes.getRallyManager().audioManager:enqueuePacenote(pacenote)
  extensions.gameplay_aipacenotes.getRallyManager().audioManager:enqueueStaticPacenoteByName('firstnoteoutro_1/c')
  -- self.pinOut.flow.value = true
end

-- function C:work()
  -- self.pinOut.flow.value = true
-- end

return _flowgraph_createNode(C)
