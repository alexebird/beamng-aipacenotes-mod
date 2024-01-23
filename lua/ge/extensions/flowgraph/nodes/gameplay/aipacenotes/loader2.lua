local im  = ui_imgui
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aip-fg-loaderv2'

C.name = 'AI Pacenotes Loader v2'
C.description = 'Do necessary loading for AI Pacenotes.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_p_duration'
-- C.category = 'once'

C.pinSchema = {
  -- { dir = 'in', type = 'flow',   name = 'flow',  description = 'Inflow for this node.' },
  -- { dir = 'in', type = 'flow',   name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'number', name = 'damageThresh', description = 'Damage threshold to play damage audio.', default = 500},
  { dir = 'in', type = 'number', name = 'searchN', description = 'Number of closest pacenotes to search when vehicle position is reset.', default = 5},

  -- { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
  -- { dir = 'out', type = 'table', name = 'rallyManager', tableType = 'rallyManager', description = 'The RallyManager' },
}

-- this is called when the flowgraph code node is created, not when the flowgraph runs.
function C:init()
  -- self:reset()
end

-- function C:drawCustomProperties()
--   local txt = '<not loaded>'
--   if self.rallyManager then
--     txt = self.rallyManager:toString()
--   end
--   im.Text(txt)
-- end

local readyHit = false
function C:reset()
  log('D', logTag, 'running AIP Loader v2')
  readyHit = false

  extensions.unload('gameplay_aipacenotes')
  extensions.load('gameplay_aipacenotes')

  extensions.gameplay_aipacenotes.helloWorld()

  extensions.gameplay_aipacenotes.initRallyManager()


  -- self.rallyManager = require('/lua/ge/extensions/gameplay/rally/rallyManager')(
  --
  -- )
  -- self.rallyManager:setup(
  --   self.pinIn.vehId.value,
  --   self.pinIn.damageThresh.value,
  --   self.pinIn.searchN.value
  -- )
end

-- function C:onNodeReset()
  -- log('D', logTag, 'onNodeReset')
  -- self.rallyManager = nil
-- end

-- function C:_executionStopped()
  -- log('D', logTag, '_executionStopped')
  -- self.rallyManager = nil
-- end

function C:workOnce()
  log('D', logTag, 'workOnce')
  self:reset()
end

function C:work()
  -- log('D', logTag, 'work')
  -- if self.pinIn.reset.value then
    -- self.rallyManager = nil
    -- self:reset()
  -- end

  -- if not self.rallyManager then
    -- self:reset()
    -- self.pinOut.rallyManager.value = self.rallyManager
  -- end

  if not readyHit then
    local loaded = extensions.isExtensionLoaded("gameplay_aipacenotes")
    if loaded and extensions.gameplay_aipacenotes.isReady() then
      log('D', logTag, 'extension is ready')
      readyHit = true
    end
  end

  self.pinOut.flow.value = false
end

return _flowgraph_createNode(C)
