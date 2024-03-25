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
  local rallyManager = extensions.gameplay_aipacenotes.getRallyManager()
  rallyManager.audioManager:enqueuePauseSecs(0.5)
  rallyManager.audioManager:enqueueStaticPacenoteByName('firstnoteintro_1/c')
  local pacenote = extensions.gameplay_aipacenotes.getRallyManager().notebook.pacenotes.sorted[1]
  rallyManager.audioManager:enqueuePacenote(pacenote)
  rallyManager.audioManager:enqueueStaticPacenoteByName('firstnoteoutro_1/c')
  -- self.pinOut.flow.value = true
  -- self.pinOut.done.value = true
end

-- function C:work()
--   if self.pinIn.reset.value then
--     self:reset()
--   end
--
--   if not self.workDone then
--     local loaded = extensions.isExtensionLoaded("gameplay_aipacenotes")
--     if loaded and extensions.gameplay_aipacenotes.isReady() then
--       local rallyManager = extensions.gameplay_aipacenotes.getRallyManager()
--
--       rallyManager.audioManager:enqueuePauseSecs(0.5)
--       rallyManager.audioManager:enqueueStaticPacenoteByName('firstnoteintro_1/c')
--       local pacenote = extensions.gameplay_aipacenotes.getRallyManager().notebook.pacenotes.sorted[1]
--       rallyManager.audioManager:enqueuePacenote(pacenote)
--       rallyManager.audioManager:enqueueStaticPacenoteByName('firstnoteoutro_1/c')
--       self.workDone = true
--       self.pinOut.flow.value = true
--     else
--       self.pinOut.flow.value = false
--     end
--     -- else
--       -- self.pinOut.flow.value = false
--     -- end
--   else
--     self.pinOut.flow.value = true
--   end
-- end

return _flowgraph_createNode(C)
