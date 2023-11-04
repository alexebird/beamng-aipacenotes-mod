-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'

local C = {}
C.windowDescription = 'Options'

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor
  -- self.mouseInfo = {}
  self.options_data = {
    default_radius = 10,
    show_distance_markers = true,
  }
end

function C:setPath(path)
  self.path = path
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:onEditModeActivate()
end

function C:draw()
  if not self.path then return end

  im.HeaderText("Options")
 
  if im.Checkbox("Show distance markers (orange waypoints)", im.BoolPtr(self.options_data.show_distance_markers)) then
    self.options_data.show_distance_markers = not self.options_data.show_distance_markers
  end
  im.tooltip("Show/Hide orange waypoints, which are called Distance Markers.")

  local editEnded = im.BoolPtr(false)
  local editTxt = im.ArrayChar(1024, tostring(self.options_data.default_radius))
  editor.uiInputText("Default Radius", editTxt, nil, nil, nil, nil, editEnded)
  if editEnded[0] then
    local newVal = tonumber(ffi.string(editTxt))
    self.options_data.default_radius = newVal
    self:onDefaultRadiusUpdated()
  end
  im.tooltip("Set the radius of all waypoints.")
end

function C:onDefaultRadiusUpdated()
  self.path:setAllRadii(self.options_data.default_radius)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
