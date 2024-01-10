local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes AudioPlayer'
C.description = 'Plays queued audio.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}

C.pinSchema = {
  { dir = 'in', type = 'flow',  name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow',  name = 'reset', description = 'Reset Inflow for this node.', impulse = true },
  { dir = 'in', type = 'table', name = 'rallyManager', tableType = 'rallyManager', description = 'The RallyManager' },

  -- { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
}

function C:init(mgr, ...)
  self.resetAudioQueue = false
  self.rallyManager = nil
end

function C:work(args)
  if self.pinIn.reset.value then
    self.resetAudioQueue = true
  end

  if self.rallyManager == nil then
    self.rallyManager = self.pinIn.rallyManager.value
  end

  if self.rallyManager then
    if self.resetAudioQueue then
      self.resetAudioQueue = false
      self.rallyManager.audioManager:resetAudioQueue()
    end
    self.rallyManager.audioManager:playNextInQueue()
  end
end

return _flowgraph_createNode(C)
