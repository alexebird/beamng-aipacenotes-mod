-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

C.name = 'AI Pacenotes Get useStructured'
C.description = 'Gets the useStructured flag of the currently loaded notebook.'
C.category = 'once_p_duration'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}

C.pinSchema = {
  -- {dir = 'in', type = 'string', name = 'file', default='race.race.json', description = 'File of the race'},

  {dir = 'out', type = 'flow', name = 'ready', description = 'True if the extension is ready.'},
  {dir = 'out', type = 'bool', name = 'useStructured', description = 'The useStructured flag.'},
}

function C:init(mgr, ...)
end

function C:getUseStructured()
  local loaded = extensions.isExtensionLoaded("gameplay_aipacenotes")
  if not loaded then
    return false, false
  end

  if not gameplay_aipacenotes.isReady() then
    return false, false
  end

  local rm = gameplay_aipacenotes.getRallyManager()
  if rm then
    return true, rm:useStructuredNotes()
  else
    return false, false
  end
end

function C:work(args)
  local useStructured, ready = self:getUseStructured()
  self.pinOut.useStructured.value = useStructured
  self.pinOut.ready.value = ready
end

return _flowgraph_createNode(C)
