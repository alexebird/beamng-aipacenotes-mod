local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

C.name = 'AI Pacenotes Wait for Empty Audio Queue'
-- C.icon = "timer"
C.description = 'Waits for audio queue to be empty'
C.color = re_util.aip_fg_color

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  -- { dir = 'in', type = 'flow', name = 'reset', description = 'Reset the countdown.', impulse = true },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
}
C.tags = {'aipacenotes'}

function C:init(mgr, ...)
end

-- function C:reset()
  -- self.pinIn.reset.value = false
  -- self.pinOut.flow.value = false
  -- self.found_empty = false
  -- self.found_non_empty = false
-- end

-- function C:_executionStopped()
--   self:reset()
-- end

function C:work(args)
  -- if self.pinIn.reset.value then
  --   print('reset')
  --   self:reset()
  -- end

  -- if not self.found_non_empty then
  --   local qs = extensions.gameplay_aipacenotes.getRallyManager().audioManager:getQueueInfo()
  --   if qs.queueSize > 0 or (qs.queueSize == 0 and not qs.paused) then
  --     print('found_non_empty')
  --     self.found_non_empty = true
  --   end
  --   self.pinOut.flow.value = false
  -- else
  --   if self.found_empty then
  --     self.pinOut.flow.value = true
  --   else
  --     local qs = extensions.gameplay_aipacenotes.getRallyManager().audioManager:getQueueInfo()
  --     if qs.queueSize == 0 and qs.paused then
  --     print('found_empty')
  --       self.found_empty = true
  --       self.pinOut.flow.value = true
  --     else
  --       self.pinOut.flow.value = false
  --     end
  --   end
  -- end

  local qs = extensions.gameplay_aipacenotes.getRallyManager().audioManager:getQueueInfo()
  -- if qs.queueSize > 0 or (qs.queueSize == 0 and not qs.paused) then
  -- end
  if qs.queueSize == 0 and qs.paused then
    self.pinOut.flow.value = true
  else
    self.pinOut.flow.value = false
  end
end

return _flowgraph_createNode(C)
