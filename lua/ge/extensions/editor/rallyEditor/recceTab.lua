local im  = ui_imgui
local logTag = 'aipacenotes'

-- local normalizer = require('/lua/ge/extensions/editor/rallyEditor/normalizer')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local Recce = require('/lua/ge/extensions/gameplay/aipacenotes/recce')

local C = {}
C.windowDescription = 'Recce'

function C:init(rallyEditor)
  self.path = nil
  self.rallyEditor = rallyEditor
  self.recce = nil
end

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
  -- if im.Button("Refresh") then
  --   self:refresh()
  -- end

  if not (self.recce and self.recce.loaded) then
    im.Text('To Import Pacenotes, make sure there is a recce recording.')
    return
  end

  if self.recce.driveline then
    im.Text('driveline: '..tostring(#self.recce.driveline.points)..' points (the red line)')
    im.Text('cuts: '..tostring(#self.recce.cuts)..' (the little green cars)')
  else
    im.Text('Recorded driveline was not found.')
    im.Text(
      'A driveline is required to make pacenotes. '..
      'Using a driveline makes creating pacenotes much easier. '..
      'To record a driveline, use the Recce UI app in freeroam.'
    )
  end

  if self.recce.cuts then
    if im.Button("Import") then
      self:import()
    end
    im.Text('Import will create a new pacenote for each of the cuts.')
  end
end

function C:refresh()
  self.recce = Recce(self.rallyEditor.getMissionDir())
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

