local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Pre-Countdown'
C.description = 'Plays pre-countdown audio.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_instant'

C.pinSchema = {
}

function C:workOnce()
  local rallyManager = gameplay_aipacenotes.getRallyManager()
  rallyManager.audioManager:enqueuePauseSecs(0.5)

  local pnName = rallyManager:getRandomStaticPacenote('firstnoteintro')
  rallyManager.audioManager:enqueueStaticPacenoteByName(pnName)

  local pacenote = gameplay_aipacenotes.getRallyManager().notebook.pacenotes.sorted[1]
  rallyManager.audioManager:enqueuePacenote(pacenote)

  pnName = rallyManager:getRandomStaticPacenote('firstnoteoutro')
  rallyManager.audioManager:enqueueStaticPacenoteByName(pnName)

end

return _flowgraph_createNode(C)
