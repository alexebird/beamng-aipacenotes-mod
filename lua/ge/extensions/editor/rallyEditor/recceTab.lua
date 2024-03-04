local im  = ui_imgui
local logTag = 'aipacenotes'

-- local normalizer = require('/lua/ge/extensions/editor/rallyEditor/normalizer')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
C.windowDescription = 'Recce'

function C:init(rallyEditor)
  self.path = nil
  self.rallyEditor = rallyEditor
  self.recce = nil
  self.corner_angles_data = nil
end

-- function C:getCornerAngles(reload)
--   if reload then
--     self.corner_angles_data = nil
--   end
--
--   if self.corner_angles_data then return self.corner_angles_data end
--
--   local json, err = re_util.loadCornerAnglesFile()
--   if json then
--     self.corner_angles_data = json
--     return self.corner_angles_data
--   else
--     return nil
--   end
-- end

function C:setPath(path)
  self.path = path
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end
  self:refresh()
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:drawSectionV3()
  im.HeaderText("Recce Recording")
  if im.Button("Refresh") then
    self:refresh()
  end

  if self.recce and self.recce.loaded then
    im.Text('driveline: '..tostring(#self.recce.driveline.points)..' points')
    im.Text('cuts: '..tostring(#self.recce.cuts)..' points')
  else
    im.Text('recce recording not loaded')
  end

  if self.recce and self.recce.loaded then
    if im.Button("Import") then
      self:import()
    end
  else
    im.Text('To Import Pacenotes, make sure there is a recce recording.')
  end
end

function C:refresh()
  self.recce = require('/lua/ge/extensions/gameplay/aipacenotes/recce')(self.rallyEditor.getMissionDir())
  self.recce:load()
end

function C:import()
  local pacenotes = self.recce:createPacenotesData(self.path)
  if pacenotes then
    self.path:appendPacenotes(pacenotes)
  end
end

function C:draw()
  if not self.path then return end
  self:drawSectionV3()
end

function C:drawDebugEntrypoint()
  if not self.recce then return end
  self.recce:drawDebugRecce()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end

