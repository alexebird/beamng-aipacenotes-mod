-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Pacenotes Rally Editor'
C.description = 'Control the Rally Editor'

C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'bool', name = 'showWaypoints', description = 'Show/hide waypoints.'},
}

C.tags = {'aipacenotes'}

local logTag = 'aipacenotes'

function C:init(mgr, ...)
end

function C:work(args)
  local showWaypoints = self.pinIn.showWaypoints.value
  -- log('D', 'WTF', 'shouldShow: ' .. tostring(shouldShow))

  if editor_rallyEditor then
    editor_rallyEditor.showWaypoints(showWaypoints)
  end
end

return _flowgraph_createNode(C)
