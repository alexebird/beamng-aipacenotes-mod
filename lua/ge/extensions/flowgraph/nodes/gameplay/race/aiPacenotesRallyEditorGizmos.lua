-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Pacenotes RallyEditor Gizmos '
C.description = 'Show or hide Gizmos managed by RallyEditor.'
-- C.category = 'aipacenotes'

C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'bool', name = 'show', description = 'Whether to show or hide. True means show.'},
}

C.tags = {'scenario', 'aipacenotes'}

local logTag = 'aipacenotes'

function C:init(mgr, ...)
  -- self.data.detailed = false
end

function C:work(args)
  local shouldShow = self.pinIn.show.value
  log('D', 'WTF', 'shouldShow: ' .. tostring(shouldShow))

  if shouldShow then
    -- hide non-pacenotes gizmos
    -- editor_rallyEditor.getPathnodesWindow():unselectAndSetDrawModeToNone()
    -- editor_rallyEditor.getSegmentsWindow():unselectAndSetDrawModeToNone()

    -- show pacenotes gizmos
    -- editor_rallyEditor.getPacenotesWindow():selected()
  else
    -- hide all gizmos
    -- editor_rallyEditor.getPathnodesWindow():unselectAndSetDrawModeToNone()
    -- editor_rallyEditor.getSegmentsWindow():unselectAndSetDrawModeToNone()
    -- editor_rallyEditor.getPacenotesWindow():unselect()
  end
end

return _flowgraph_createNode(C)