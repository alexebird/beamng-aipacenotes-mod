local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

C.name = 'AI Pacenotes Wait for Empty Audio Queue'
C.icon = "timer"
C.description = 'Waits for audio queue to be empty'
C.color = re_util.aip_fg_color

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Reset the countdown.', impulse = true },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
}
C.tags = {'aipacenotes'}

function C:init(mgr, ...)
end

function C:reset()
  self.pinOut.flow.value = false
  self.found_non_empty = false
  self.found_empty = false
  -- self.met_inflow = false
  -- self.t_start = nil
end

function C:work(args)
  if self.pinIn.reset.value then
    self:reset()
  end

  -- if self.pinIn.flow.value and not self.met_inflow then
    -- self.met_inflow = true
    -- self.t_start = re_util.getTime()
  -- end

  -- if self.t_start then
  --   local t_now = re_util.getTime()
  --   if t_now - self.t_start > 3 then
  --     self.pinOut.flow.value = true
  --   else
  --     self.pinOut.flow.value = false
  --   end
  -- end

  if not self.found_non_empty then
    local qs = extensions.gameplay_aipacenotes.getRallyManager().audioManager:getQueueInfo()
    if qs.queueSize > 0 or not qs.paused then
      self.found_non_empty = true
    end
    self.pinOut.flow.value = false
  else
    if not self.found_empty then
      local qs = extensions.gameplay_aipacenotes.getRallyManager().audioManager:getQueueInfo()
      if qs.queueSize == 0 and qs.paused then
        self.found_empty = true
        self.pinOut.flow.value = true
      else
        self.pinOut.flow.value = false
      end
    else
      self.pinOut.flow.value = true
    end
  end
end

return _flowgraph_createNode(C)
