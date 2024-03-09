local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Pre-Countdown'
C.description = 'Plays pre-countdown audio.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_instant'

C.pinSchema = {
  -- { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  -- { dir = 'in', type = 'flow', name = 'reset', description = 'Reset the countdown.', impulse = true },
  -- { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },

  -- { dir = 'out', type = 'flow', name = 'done', description = 'Outflow for this node.', impulse = true },
}

-- function C:reset()
--   self.workDone = false
--   self.pinOut.flow.value = false
--   self.pinIn.reset.value = false
-- end

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
